import '../../../core/constants/app_constants.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_model.dart';

/// Authentication service
class AuthService {
  final SessionService _session = SessionService.instance;

  /// Sign in with email and password
  Future<UserProfile> signIn({
    required String email,
    required String password,
    String? ipAddress,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session == null || authResponse.user == null) {
        throw Exception(ErrorMessages.invalidCredentials);
      }

      final data = await supabase.rpc('get_my_profile_with_permissions');
      if (data == null || data is! Map) {
        throw Exception('Profile not found.');
      }

      final profileJson = Map<String, dynamic>.from(data['profile'] as Map);
      final permissions = (data['permissions'] as List<dynamic>? ?? [])
          .map((item) => (item as Map)['code']?.toString())
          .whereType<String>()
          .toList();

      await _session.savePermissions(permissions);

      try {
        await supabase.from('audit_logs').insert({
          'user_id': authResponse.user!.id,
          'action': 'login',
          if (ipAddress != null) 'ip_address': ipAddress,
        });
      } catch (_) {
        // Ignore audit log failures.
      }

      return UserProfile.fromJson(profileJson);
    } catch (e) {
      final message = e.toString();
      if (message.contains('Authentication failed') ||
          message.contains('Invalid credentials')) {
        throw Exception(ErrorMessages.invalidCredentials);
      }
      throw Exception(ErrorMessages.networkError);
    }
  }

  /// Restore existing session
  Future<UserProfile?> restoreSession() async {
    try {
      final supabase = SupabaseService.client;
      await _session.load();

      final session = supabase.auth.currentSession;
      if (session == null) {
        await _session.clear();
        return null;
      }

      final data = await supabase.rpc('get_my_profile_with_permissions');
      if (data == null || data is! Map) {
        return null;
      }

      final profileJson = Map<String, dynamic>.from(data['profile'] as Map);
      final permissions = (data['permissions'] as List<dynamic>? ?? [])
          .map((item) => (item as Map)['code']?.toString())
          .whereType<String>()
          .toList();

      await _session.savePermissions(permissions);
      return UserProfile.fromJson(profileJson);
    } catch (e) {
      await _session.clear();
      return null;
    }
  }

  /// Sign out
  Future<void> signOut({String? ipAddress}) async {
    try {
      final supabase = SupabaseService.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await supabase.from('audit_logs').insert({
            'user_id': userId,
            'action': 'logout',
            if (ipAddress != null) 'ip_address': ipAddress,
          });
        } catch (_) {
          // Ignore audit log failures.
        }
      }

      await supabase.auth.signOut();
      await _session.clear();
    } catch (e) {
      throw Exception('Lỗi đăng xuất: ${e.toString()}');
    }
  }

  /// Get user profile
  Future<UserProfile> getUserProfile(String userId) async {
    final supabase = SupabaseService.client;
    final data = await supabase.rpc('get_my_profile_with_permissions');
    final profileJson = data is Map ? data['profile'] as Map? : null;
    if (profileJson == null) {
      throw Exception('Không tìm thấy thông tin người dùng');
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(profileJson));
  }

  /// Get user permissions (from cached session)
  Future<List<Permission>> getUserPermissions(String roleId) async {
    return _session.permissionCodes
        .map(
          (code) => Permission(
            id: code,
            code: code,
            name: code,
            module: '',
            description: null,
            createdAt: DateTime.now(),
          ),
        )
        .toList();
  }

  /// Check if user has permission
  Future<bool> hasPermission(String permissionCode) async {
    return _session.permissionCodes.contains(permissionCode);
  }

  /// Require permission (throws exception if not authorized)
  Future<void> requirePermission(String permissionCode) async {
    final hasAccess = await hasPermission(permissionCode);
    if (!hasAccess) {
      throw Exception(ErrorMessages.unauthorized);
    }
  }

  /// Check if authenticated
  bool get isAuthenticated =>
      SupabaseService.client.auth.currentSession != null;
}
