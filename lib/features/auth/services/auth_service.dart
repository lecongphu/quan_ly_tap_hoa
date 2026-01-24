import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Authentication service
class AuthService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  /// Sign in with email and password
  Future<UserProfile> signIn({
    required String email,
    required String password,
    String? ipAddress,
  }) async {
    try {
      // Sign in with Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception(ErrorMessages.invalidCredentials);
      }

      // Get user profile
      final profile = await getUserProfile(response.user!.id);

      // Log audit
      await _logAudit(
        userId: response.user!.id,
        action: AppConstants.actionLogin,
        ipAddress: ipAddress,
      );

      return profile;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(ErrorMessages.networkError);
    }
  }

  /// Sign out
  Future<void> signOut({String? ipAddress}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId != null) {
        // Log audit before signing out
        await _logAudit(
          userId: userId,
          action: AppConstants.actionLogout,
          ipAddress: ipAddress,
        );
      }

      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Lỗi đăng xuất: ${e.toString()}');
    }
  }

  /// Get user profile
  Future<UserProfile> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableProfiles)
          .select('''
            *,
            role:${AppConstants.tableRoles}(name)
          ''')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson({
        ...response,
        'role_name': response['role']?['name'],
      });
    } catch (e) {
      throw Exception('Không tìm thấy thông tin người dùng');
    }
  }

  /// Get user permissions
  Future<List<Permission>> getUserPermissions(String roleId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableRolePermissions)
          .select('''
            ${AppConstants.tablePermissions}(*)
          ''')
          .eq('role_id', roleId);

      return (response as List)
          .map(
            (item) => Permission.fromJson(item[AppConstants.tablePermissions]),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if user has permission
  Future<bool> hasPermission(String permissionCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await getUserProfile(user.id);
      if (profile.roleId == null) return false;

      final permissions = await getUserPermissions(profile.roleId!);
      return permissions.any((p) => p.code == permissionCode);
    } catch (e) {
      return false;
    }
  }

  /// Require permission (throws exception if not authorized)
  Future<void> requirePermission(String permissionCode) async {
    final hasAccess = await hasPermission(permissionCode);
    if (!hasAccess) {
      throw Exception(ErrorMessages.unauthorized);
    }
  }

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if authenticated
  bool get isAuthenticated => currentUser != null;

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Log audit action
  Future<void> _logAudit({
    required String userId,
    required String action,
    Map<String, dynamic>? details,
    String? ipAddress,
  }) async {
    try {
      await _supabase.from(AppConstants.tableAuditLogs).insert({
        'user_id': userId,
        'action': action,
        'details': details,
        'ip_address': ipAddress,
      });
    } catch (e) {
      // Silently fail audit logging to not block main operations
      debugPrint('Audit log error: $e');
    }
  }

  /// Log custom audit action
  Future<void> logAudit({
    required String action,
    Map<String, dynamic>? details,
    String? ipAddress,
  }) async {
    final userId = currentUser?.id;
    if (userId != null) {
      await _logAudit(
        userId: userId,
        action: action,
        details: details,
        ipAddress: ipAddress,
      );
    }
  }
}
