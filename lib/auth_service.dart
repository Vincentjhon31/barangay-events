import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 'citizen' (default, self-registers in the app) | 'lgu_member'
/// (registers via the separate GitHub Pages admin portal, needs
/// superadmin approval) | 'superadmin' (one account; the only role that
/// can post Public events, and approves LGU applications).
class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.department,
    this.phoneNumber,
    this.streetAddress,
    this.barangay,
    this.city,
    this.bio,
    this.avatarUrl,
    this.role = 'citizen',
    this.lguRequestStatus,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? department;
  final String? phoneNumber;
  final String? streetAddress;
  final String? barangay;
  final String? city;
  final String? bio;
  final String? avatarUrl;

  /// Server-assigned; see the class doc. Never sent back to the server —
  /// [toJson] deliberately omits it, since the "save your own profile"
  /// path must never be able to grant a role. Changing it requires the
  /// request_lgu_status/respond_to_lgu_application RPCs (see
  /// AppAuthService.requestLguStatus) or direct superadmin action.
  final String role;

  /// null (never applied) | 'pending' | 'approved' | 'rejected'.
  final String? lguRequestStatus;

  bool get isLguMember => role == 'lgu_member';
  bool get isSuperadmin => role == 'superadmin';
  bool get canCreatePublicEvents => role == 'superadmin';
  bool get canCreateGroupEvents => role == 'lgu_member' || role == 'superadmin';
  bool get canCreateGroups => role == 'lgu_member' || role == 'superadmin';

  String get initials {
    final source = (displayName?.trim().isNotEmpty == true ? displayName : email)
        ?.trim();
    if (source == null || source.isEmpty) {
      return 'B';
    }

    final parts = source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return source.substring(0, 1).toUpperCase();
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    return AppUserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      department: json['department'] as String?,
      phoneNumber: json['phone_number'] as String?,
      streetAddress: json['street_address'] as String?,
      barangay: json['barangay'] as String?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'citizen',
      lguRequestStatus: json['lgu_request_status'] as String?,
    );
  }

  /// Deliberately omits [role]/[lguRequestStatus] — this is what the
  /// generic "save your own profile" upsert sends, and that path must
  /// never be able to write a role. The server-side trigger
  /// (guard_profile_role_columns) enforces this too, but not sending the
  /// columns at all is the first line of defense.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'department': department,
      'phone_number': phoneNumber,
      'street_address': streetAddress,
      'barangay': barangay,
      'city': city,
      'bio': bio,
      'avatar_url': avatarUrl,
    };
  }
}

abstract class AppAuthService {
  Stream<bool> authStateChanges();
  bool get isSignedIn;
  AppUserProfile? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? department,
  });
  Future<void> updateDisplayName(String displayName);

  /// Changes the signed-in user's sign-in email. Supabase emails a
  /// confirmation link to the *new* address — the change only takes effect
  /// once that's clicked, so [currentUser]'s email may briefly lag behind
  /// what was just submitted here.
  Future<void> updateEmail(String newEmail);

  /// Changes the signed-in user's password immediately — unlike
  /// [updateEmail], there's no confirmation step.
  Future<void> updatePassword(String newPassword);

  /// Sets the signed-in user's profile picture to one of the bundled
  /// options in `lib/avatar_catalog.dart` (an asset path, e.g.
  /// `assets/avatars/animal/animal_01.png`) — never an uploaded/captured
  /// image, this app only offers picking from the fixed catalog.
  Future<void> updateAvatar(String assetPath);

  /// Raw `theme_mode`/`ui_style`/`language` values from the signed-in
  /// user's profile (mirrors `ThemeMode`/`UiStyle`/`Locale` `.name`s/codes),
  /// or null if unavailable — lets a chosen appearance/language follow the
  /// user across devices.
  Future<({String themeMode, String uiStyle, String language})?> fetchPreferences();
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
  });

  Future<void> signOut();
  Future<void> dispose();
}

class SupabaseAuthService implements AppAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  Stream<bool> authStateChanges() {
    return _client.auth.onAuthStateChange.map((state) => state.session != null);
  }

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  AppUserProfile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    return AppUserProfile(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      department: user.userMetadata?['department'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  Future<AppUserProfile?> fetchUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return null;
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return AppUserProfile.fromJson(response);
    } catch (e) {
      // Profile doesn't exist yet, return basic profile from auth
      return currentUser;
    }
  }

  Future<void> createOrUpdateProfile(AppUserProfile profile) async {
    try {
      await _client.from('profiles').upsert(
        profile.toJson(),
        onConflict: 'id',
      );

      // Keep auth metadata in sync so currentUser reflects the latest
      // name/department without an extra profile fetch.
      if (_client.auth.currentUser != null) {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'display_name': profile.displayName,
              'department': profile.department,
            },
          ),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? department,
  }) async {
    final metadata = <String, dynamic>{
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
      if (department != null && department.isNotEmpty) 'department': department,
    };

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata.isEmpty ? null : metadata,
    );

    // Create profile entry
    if (response.user != null) {
      await createOrUpdateProfile(
        AppUserProfile(
          id: response.user!.id,
          email: email,
          displayName: displayName,
          department: department,
        ),
      );
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Update auth metadata
    await _client.auth.updateUser(
      UserAttributes(
        data: {'display_name': displayName},
      ),
    );

    // Update profiles table
    await createOrUpdateProfile(
      AppUserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: displayName,
      ),
    );
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> updateAvatar(String assetPath) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Carry the rest of the current profile forward — createOrUpdateProfile
    // upserts the whole row, so building an AppUserProfile with only
    // avatarUrl set would null out name/department/bio/etc.
    final current = await fetchUserProfile();
    final base = current ??
        AppUserProfile(id: user.id, email: user.email ?? '');

    await createOrUpdateProfile(
      AppUserProfile(
        id: base.id,
        email: base.email,
        displayName: base.displayName,
        department: base.department,
        phoneNumber: base.phoneNumber,
        streetAddress: base.streetAddress,
        barangay: base.barangay,
        city: base.city,
        bio: base.bio,
        avatarUrl: assetPath,
      ),
    );
  }

  @override
  Future<({String themeMode, String uiStyle, String language})?> fetchPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('theme_mode, ui_style, language')
          .eq('id', user.id)
          .maybeSingle();
      final mode = row?['theme_mode'] as String?;
      final style = row?['ui_style'] as String?;
      final language = row?['language'] as String?;
      if (mode == null || style == null || language == null) return null;
      return (themeMode: mode, uiStyle: style, language: language);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // A targeted update (not upsert) so this never clobbers other profile
    // fields when only appearance/language changed.
    await _client.from('profiles').update({
      'theme_mode': themeMode,
      'ui_style': uiStyle,
      'language': language,
    }).eq('id', user.id);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> dispose() async {}
}

class MemoryAuthService implements AppAuthService {
  MemoryAuthService._(this._signedIn, this._currentUser) {
    _controller.add(_signedIn);
  }

  /// [role] defaults to 'superadmin' so the existing test suite (written
  /// before roles existed, and mostly not about permissions) keeps
  /// exercising the full feature set unmodified — pass 'citizen' or
  /// 'lgu_member' explicitly for tests that specifically cover role
  /// restrictions.
  factory MemoryAuthService.signedIn({String role = 'superadmin'}) {
    return MemoryAuthService._(
      true,
      AppUserProfile(
        id: 'mock-user-id',
        email: 'user@example.com',
        displayName: 'Barangay Officer',
        department: "Mayor's Office",
        role: role,
      ),
    );
  }

  factory MemoryAuthService.signedOut() {
    return MemoryAuthService._(false, null);
  }

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _signedIn;
  AppUserProfile? _currentUser;
  String? _themeMode;
  String? _uiStyle;
  String? _language;

  @override
  Stream<bool> authStateChanges() async* {
    yield _signedIn;
    yield* _controller.stream;
  }

  @override
  bool get isSignedIn => _signedIn;

  @override
  AppUserProfile? get currentUser => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _signedIn = true;
    _currentUser = AppUserProfile(id: 'mock-user-id', email: email, displayName: email.split('@').first);
    _controller.add(true);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? department,
  }) async {
    _signedIn = true;
    _currentUser = AppUserProfile(
      id: 'mock-user-id',
      email: email,
      displayName: displayName?.isNotEmpty == true ? displayName : email.split('@').first,
      department: department,
    );
    _controller.add(true);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final current = _currentUser;
    if (current == null) {
      return;
    }
    _currentUser = AppUserProfile(
      id: current.id,
      email: current.email,
      displayName: displayName,
      department: current.department,
      phoneNumber: current.phoneNumber,
      streetAddress: current.streetAddress,
      barangay: current.barangay,
      city: current.city,
      bio: current.bio,
      avatarUrl: current.avatarUrl,
      role: current.role,
      lguRequestStatus: current.lguRequestStatus,
    );
    _controller.add(true);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final current = _currentUser;
    if (current == null) return;
    _currentUser = AppUserProfile(
      id: current.id,
      email: newEmail,
      displayName: current.displayName,
      department: current.department,
      phoneNumber: current.phoneNumber,
      streetAddress: current.streetAddress,
      barangay: current.barangay,
      city: current.city,
      bio: current.bio,
      avatarUrl: current.avatarUrl,
      role: current.role,
      lguRequestStatus: current.lguRequestStatus,
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    // No real backend in this test double — accepted as a no-op.
  }

  @override
  Future<void> updateAvatar(String assetPath) async {
    final current = _currentUser;
    if (current == null) return;
    _currentUser = AppUserProfile(
      id: current.id,
      email: current.email,
      displayName: current.displayName,
      department: current.department,
      phoneNumber: current.phoneNumber,
      streetAddress: current.streetAddress,
      barangay: current.barangay,
      city: current.city,
      bio: current.bio,
      avatarUrl: assetPath,
      role: current.role,
      lguRequestStatus: current.lguRequestStatus,
    );
    _controller.add(true);
  }

  @override
  Future<({String themeMode, String uiStyle, String language})?> fetchPreferences() async {
    final mode = _themeMode;
    final style = _uiStyle;
    final language = _language;
    if (mode == null || style == null || language == null) return null;
    return (themeMode: mode, uiStyle: style, language: language);
  }

  @override
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
  }) async {
    _themeMode = themeMode;
    _uiStyle = uiStyle;
    _language = language;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _currentUser = null;
    _controller.add(false);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
