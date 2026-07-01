import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  final String? email;
  final String? displayName;
  final String? avatarUrl;

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
  });
  Future<void> updateDisplayName(String displayName);
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
      email: user.email,
      displayName: user.userMetadata?['display_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
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
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName == null || displayName.isEmpty
          ? null
          : {'display_name': displayName},
    );
  }

    @override
    Future<void> updateDisplayName(String displayName) async {
      await _client.auth.updateUser(
        UserAttributes(
          data: {'display_name': displayName},
        ),
      );
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

  factory MemoryAuthService.signedIn() {
    return MemoryAuthService._(
      true,
      const AppUserProfile(email: 'user@example.com', displayName: 'Barangay Officer'),
    );
  }

  factory MemoryAuthService.signedOut() {
    return MemoryAuthService._(false, null);
  }

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _signedIn;
  AppUserProfile? _currentUser;

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
    _currentUser = AppUserProfile(email: email, displayName: email.split('@').first);
    _controller.add(true);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _signedIn = true;
    _currentUser = AppUserProfile(
      email: email,
      displayName: displayName?.isNotEmpty == true ? displayName : email.split('@').first,
    );
    _controller.add(true);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    _currentUser = AppUserProfile(
      email: _currentUser?.email,
      displayName: displayName,
      avatarUrl: _currentUser?.avatarUrl,
    );
    _controller.add(true);
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
