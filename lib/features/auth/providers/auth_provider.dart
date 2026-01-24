import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Auth state
class AuthState {
  final bool isLoading;
  final UserProfile? user;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    UserProfile? user,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((event) {
      if (event.session != null) {
        _loadUserProfile(event.session!.user.id);
      } else {
        state = AuthState(isAuthenticated: false);
      }
    });

    // Check initial auth state
    if (_authService.isAuthenticated) {
      _loadUserProfile(_authService.currentUser!.id);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profile = await _authService.getUserProfile(userId);
      state = AuthState(isAuthenticated: true, user: profile);
    } catch (e) {
      state = AuthState(isAuthenticated: false, error: e.toString());
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final profile = await _authService.signIn(
        email: email,
        password: password,
      );

      state = AuthState(isAuthenticated: true, user: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.signOut();
      state = AuthState(isAuthenticated: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<bool> hasPermission(String permissionCode) async {
    return await _authService.hasPermission(permissionCode);
  }

  Future<void> requirePermission(String permissionCode) async {
    await _authService.requirePermission(permissionCode);
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Current user provider
final currentUserProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).user;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
