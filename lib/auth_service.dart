import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a "Forgot password?" reset email's link sends the browser —
/// Supabase's web SDK auto-detects the recovery token in that page's URL
/// and fires `AuthChangeEvent.passwordRecovery` (see
/// `SupabaseAuthService.passwordRecoveryEvents`), which `main.dart` uses
/// to show `ResetPasswordPage` instead of the normal signed-in app shell.
/// Must have no "www." — only the bare domain is configured in DNS/Hostinger.
const String kPasswordResetRedirectUrl =
    'https://calendar.bongabong.gov.ph/';

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
    this.isKioskAccount = false,
    this.calendarGroupFilterIds = const [],
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

  /// Superadmin-designated (via the LGU-admin portal's All Users table,
  /// admin_set_kiosk_account) — controls whether this account sees the
  /// "Enable Kiosk Mode" entry point. Not a permission: it doesn't grant
  /// or restrict anything server-side, so — like [role] — it's never sent
  /// back on a self-save.
  final bool isKioskAccount;

  /// Which of this account's groups currently show as "Shared" events on
  /// the Calendar tab's Group filter — synced per-account (like theme/
  /// language) rather than a device-local setting, so it follows the user
  /// across devices. Saved via its own dedicated
  /// `AppAuthService.saveCalendarGroupFilter` rather than the generic
  /// profile [toJson] save, since filter taps happen far more often than
  /// profile edits.
  final List<String> calendarGroupFilterIds;

  bool get isLguMember => role == 'lgu_member';
  bool get isSuperadmin => role == 'superadmin';
  bool get canCreatePublicEvents => role == 'superadmin';
  bool get canCreateGroupEvents => role == 'lgu_member' || role == 'superadmin';
  bool get canCreateGroups => role == 'lgu_member' || role == 'superadmin';

  String get initials {
    final source =
        (displayName?.trim().isNotEmpty == true ? displayName : email)?.trim();
    if (source == null || source.isEmpty) {
      return 'B';
    }

    final parts =
        source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return source.substring(0, 1).toUpperCase();
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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
      isKioskAccount: json['is_kiosk_account'] as bool? ?? false,
      calendarGroupFilterIds:
          (json['calendar_group_filter_ids'] as List<dynamic>?)
                  ?.map((id) => id as String)
                  .toList() ??
              const [],
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

  /// Emits whenever the underlying auth session enters Supabase's
  /// password-recovery state — i.e. a "Forgot password?" reset link was
  /// just opened (see [kPasswordResetRedirectUrl]) — so the caller can
  /// show a "set new password" screen instead of routing to the normal
  /// signed-in app the way [authStateChanges] otherwise would (a recovery
  /// session still counts as "signed in" there).
  Stream<void> get passwordRecoveryEvents;

  /// Sends a "reset your password" email to [email] via Supabase Auth —
  /// the link inside points at [kPasswordResetRedirectUrl]. Always
  /// resolves the same way regardless of whether [email] belongs to a
  /// real account, so this can never be used to probe which emails are
  /// registered.
  Future<void> sendPasswordResetEmail(String email);

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

  /// Raw `theme_mode`/`ui_style`/`language`/`display_mode`/
  /// `reminder_preference` values from the signed-in user's profile
  /// (mirrors `ThemeMode`/`UiStyle`/`Locale`/`DisplayMode`/
  /// `ReminderPreference` `.name`s/codes), or null if unavailable — lets a
  /// chosen appearance/language/display-size/reminder setting follow the
  /// user across devices.
  Future<
      ({
        String themeMode,
        String uiStyle,
        String language,
        String displayMode,
        String reminderPreference
      })?> fetchPreferences();
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
    required String displayMode,
    required String reminderPreference,
  });

  /// Persists the Calendar tab's Group filter selection (see
  /// [AppUserProfile.calendarGroupFilterIds]) — a dedicated call rather
  /// than folded into [savePreferences], since filter taps happen far
  /// more often than appearance changes.
  Future<void> saveCalendarGroupFilter(List<String> groupIds);

  /// Confirms [passcode] against the signed-in kiosk account's stored
  /// exit passcode (see `verify_kiosk_passcode` — the passcode itself is
  /// never sent back to the client). Returns `false` on an ordinary
  /// mismatch; throws only for the locked-out case (too many recent wrong
  /// attempts), which the caller should treat as a distinct error state
  /// rather than just "wrong code".
  Future<bool> verifyKioskPasscode(String passcode);

  /// Self-service passcode change — verifies [currentPasscode] server-side
  /// before applying [newPasscode] (throws on mismatch), since a 4-digit
  /// passcode has no session-based guarantee the way a real password
  /// change does.
  Future<void> setKioskPasscode({
    required String currentPasscode,
    required String newPasscode,
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
  Stream<void> get passwordRecoveryEvents => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth
        .resetPasswordForEmail(email, redirectTo: kPasswordResetRedirectUrl);
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

      final response =
          await _client.from('profiles').select().eq('id', user.id).single();

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
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
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
    final base =
        current ?? AppUserProfile(id: user.id, email: user.email ?? '');

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
  Future<
      ({
        String themeMode,
        String uiStyle,
        String language,
        String displayMode,
        String reminderPreference
      })?> fetchPreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select(
              'theme_mode, ui_style, language, display_mode, reminder_preference')
          .eq('id', user.id)
          .maybeSingle();
      final mode = row?['theme_mode'] as String?;
      final style = row?['ui_style'] as String?;
      final language = row?['language'] as String?;
      final displayMode = row?['display_mode'] as String?;
      final reminderPreference = row?['reminder_preference'] as String?;
      if (mode == null ||
          style == null ||
          language == null ||
          displayMode == null ||
          reminderPreference == null) {
        return null;
      }
      return (
        themeMode: mode,
        uiStyle: style,
        language: language,
        displayMode: displayMode,
        reminderPreference: reminderPreference,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
    required String displayMode,
    required String reminderPreference,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // A targeted update (not upsert) so this never clobbers other profile
    // fields when only appearance/language/display-size/reminders changed.
    await _client.from('profiles').update({
      'theme_mode': themeMode,
      'ui_style': uiStyle,
      'language': language,
      'display_mode': displayMode,
      'reminder_preference': reminderPreference,
    }).eq('id', user.id);
  }

  @override
  Future<void> saveCalendarGroupFilter(List<String> groupIds) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'calendar_group_filter_ids': groupIds}).eq('id', user.id);
  }

  @override
  Future<bool> verifyKioskPasscode(String passcode) async {
    final result = await _client.rpc(
      'verify_kiosk_passcode',
      params: {'p_passcode': passcode},
    );
    return result as bool;
  }

  @override
  Future<void> setKioskPasscode({
    required String currentPasscode,
    required String newPasscode,
  }) async {
    await _client.rpc('set_own_kiosk_passcode', params: {
      'p_current': currentPasscode,
      'p_new': newPasscode,
    });
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
  factory MemoryAuthService.signedIn(
      {String role = 'superadmin', bool isKioskAccount = false}) {
    return MemoryAuthService._(
      true,
      AppUserProfile(
        id: 'mock-user-id',
        email: 'user@example.com',
        displayName: 'Barangay Officer',
        department: "Mayor's Office",
        role: role,
        isKioskAccount: isKioskAccount,
      ),
    );
  }

  factory MemoryAuthService.signedOut() {
    return MemoryAuthService._(false, null);
  }

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final StreamController<void> _recoveryController =
      StreamController<void>.broadcast();
  bool _signedIn;
  AppUserProfile? _currentUser;
  String? _themeMode;
  String? _uiStyle;
  String? _language;
  String? _displayMode;
  String? _reminderPreference;
  String _kioskPasscode = '0000';

  @override
  Stream<bool> authStateChanges() async* {
    yield _signedIn;
    yield* _controller.stream;
  }

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryController.stream;

  /// Test-only hook to simulate a "Forgot password?" reset link's
  /// AuthChangeEvent.passwordRecovery firing (see main.dart's
  /// _BarangayCalendarAppState, which listens for this to show
  /// ResetPasswordPage) — nothing in [MemoryAuthService] triggers this on
  /// its own, unlike [SupabaseAuthService] reacting to a real URL.
  void simulatePasswordRecovery() => _recoveryController.add(null);

  /// Test double — records the call for assertions rather than sending a
  /// real email.
  String? lastPasswordResetEmail;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastPasswordResetEmail = email;
  }

  @override
  bool get isSignedIn => _signedIn;

  @override
  AppUserProfile? get currentUser => _currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _signedIn = true;
    _currentUser = AppUserProfile(
        id: 'mock-user-id', email: email, displayName: email.split('@').first);
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
      displayName: displayName?.isNotEmpty == true
          ? displayName
          : email.split('@').first,
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
      isKioskAccount: current.isKioskAccount,
      calendarGroupFilterIds: current.calendarGroupFilterIds,
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
      isKioskAccount: current.isKioskAccount,
      calendarGroupFilterIds: current.calendarGroupFilterIds,
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
      isKioskAccount: current.isKioskAccount,
      calendarGroupFilterIds: current.calendarGroupFilterIds,
    );
    _controller.add(true);
  }

  @override
  Future<
      ({
        String themeMode,
        String uiStyle,
        String language,
        String displayMode,
        String reminderPreference
      })?> fetchPreferences() async {
    final mode = _themeMode;
    final style = _uiStyle;
    final language = _language;
    final displayMode = _displayMode;
    final reminderPreference = _reminderPreference;
    if (mode == null ||
        style == null ||
        language == null ||
        displayMode == null ||
        reminderPreference == null) {
      return null;
    }
    return (
      themeMode: mode,
      uiStyle: style,
      language: language,
      displayMode: displayMode,
      reminderPreference: reminderPreference,
    );
  }

  @override
  Future<void> savePreferences({
    required String themeMode,
    required String uiStyle,
    required String language,
    required String displayMode,
    required String reminderPreference,
  }) async {
    _themeMode = themeMode;
    _uiStyle = uiStyle;
    _language = language;
    _displayMode = displayMode;
    _reminderPreference = reminderPreference;
  }

  @override
  Future<void> saveCalendarGroupFilter(List<String> groupIds) async {
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
      avatarUrl: current.avatarUrl,
      role: current.role,
      lguRequestStatus: current.lguRequestStatus,
      isKioskAccount: current.isKioskAccount,
      calendarGroupFilterIds: groupIds,
    );
  }

  @override
  Future<bool> verifyKioskPasscode(String passcode) async =>
      passcode == _kioskPasscode;

  @override
  Future<void> setKioskPasscode({
    required String currentPasscode,
    required String newPasscode,
  }) async {
    if (currentPasscode != _kioskPasscode) {
      throw Exception('Current passcode is incorrect');
    }
    _kioskPasscode = newPasscode;
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
    await _recoveryController.close();
  }
}
