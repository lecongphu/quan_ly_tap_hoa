import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Singleton service for Supabase client management
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  SupabaseService._();

  /// Get singleton instance
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      debug: true, // Set to false in production
    );
    _client = Supabase.instance.client;
  }

  /// Get Supabase client
  SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase has not been initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Get current user
  User? get currentUser => _client?.auth.currentUser;

  /// Get current session
  Session? get currentSession => _client?.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges => _client!.auth.onAuthStateChange;

  /// Sign out
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}

/// Convenient getter for Supabase client
SupabaseClient get supabase => SupabaseService.instance.client;
