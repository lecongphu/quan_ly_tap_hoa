import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const _permissionsKey = 'permission_codes';

  List<String> _permissionCodes = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionCodes = prefs.getStringList(_permissionsKey) ?? [];
  }

  Future<void> savePermissions(List<String> permissionCodes) async {
    final prefs = await SharedPreferences.getInstance();
    _permissionCodes = permissionCodes;
    await prefs.setStringList(_permissionsKey, permissionCodes);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionCodes = [];
    await prefs.remove(_permissionsKey);
  }

  List<String> get permissionCodes => List.unmodifiable(_permissionCodes);
}
