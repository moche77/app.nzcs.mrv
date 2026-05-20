import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/user_role.dart';

class AuthService extends ChangeNotifier {
  static const String _boxName = 'users_box';
  static const String _sessionBoxName = 'session_box';

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  late Box _userBox;
  late Box _sessionBox;

  String _hashPassword(String password) {
    final bytes = utf8.encode('NerZeroMRV_$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> initialize() async {
    _userBox = await Hive.openBox(_boxName);
    _sessionBox = await Hive.openBox(_sessionBoxName);
    await _seedDefaultUsersIfEmpty();
    await _restoreSession();
  }

  Future<void> _seedDefaultUsersIfEmpty() async {
    if (_userBox.isNotEmpty) return;
    final now = DateTime.now();
    final seedUsers = [
      AppUser(
        username: 'admin',
        passwordHash: _hashPassword('admin123'),
        role: UserRole.administrator,
        fullName: 'Plant Administrator',
        email: 'admin@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'receiving',
        passwordHash: _hashPassword('password123'),
        role: UserRole.receivingOperator,
        fullName: 'Receiving Operator',
        email: 'receiving@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'pyrolysis',
        passwordHash: _hashPassword('password123'),
        role: UserRole.pyrolysisOperator,
        fullName: 'Pyrolysis Operator',
        email: 'pyrolysis@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'lab',
        passwordHash: _hashPassword('password123'),
        role: UserRole.labTechnician,
        fullName: 'Lab Technician',
        email: 'lab@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'inventory',
        passwordHash: _hashPassword('password123'),
        role: UserRole.inventoryManager,
        fullName: 'Inventory Manager',
        email: 'inventory@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'field',
        passwordHash: _hashPassword('password123'),
        role: UserRole.fieldOperator,
        fullName: 'Field Operator',
        email: 'field@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'compliance',
        passwordHash: _hashPassword('password123'),
        role: UserRole.complianceReviewer,
        fullName: 'Compliance Reviewer',
        email: 'compliance@netzerocarbon.com',
        mustChangePassword: true,
        createdAt: now,
      ),
    ];
    for (final u in seedUsers) {
      await _userBox.put(u.username, u.toMap());
    }
  }

  Future<void> _restoreSession() async {
    final username = _sessionBox.get('current_user');
    if (username != null && _userBox.containsKey(username)) {
      final m = _userBox.get(username);
      _currentUser = AppUser.fromMap(Map<String, dynamic>.from(m as Map));
      notifyListeners();
    }
  }

  Future<String?> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) {
      return 'Invalid username or password';
    }
    final m = _userBox.get(key);
    final user = AppUser.fromMap(Map<String, dynamic>.from(m as Map));
    if (user.passwordHash != _hashPassword(password)) {
      return 'Invalid username or password';
    }
    final updated = user.copyWith(lastLogin: DateTime.now());
    await _userBox.put(key, updated.toMap());
    _currentUser = updated;
    await _sessionBox.put('current_user', key);
    notifyListeners();
    return null;
  }

  Future<String?> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return 'Not authenticated';
    if (_currentUser!.passwordHash != _hashPassword(oldPassword)) {
      return 'Current password incorrect';
    }
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters';
    }
    final updated = _currentUser!.copyWith(
      passwordHash: _hashPassword(newPassword),
      mustChangePassword: false,
    );
    await _userBox.put(_currentUser!.username, updated.toMap());
    _currentUser = updated;
    notifyListeners();
    return null;
  }

  Future<String?> resetPassword(String username, String email) async {
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'Username not found';
    final m = _userBox.get(key);
    final user = AppUser.fromMap(Map<String, dynamic>.from(m as Map));
    if (user.email.toLowerCase() != email.trim().toLowerCase()) {
      return 'Email does not match our records';
    }
    // In a production deployment this would dispatch a recovery email via SMTP/Firebase.
    // For this Phase 1 build we reset to a temporary credential and force a change on next login.
    final tempPassword = 'Temp${DateTime.now().millisecondsSinceEpoch % 100000}';
    final updated = user.copyWith(
      passwordHash: _hashPassword(tempPassword),
      mustChangePassword: true,
    );
    await _userBox.put(key, updated.toMap());
    return 'TEMP_PASSWORD:$tempPassword';
  }

  Future<void> logout() async {
    _currentUser = null;
    await _sessionBox.delete('current_user');
    notifyListeners();
  }

  List<AppUser> getAllUsers() {
    return _userBox.values
        .map((m) => AppUser.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => a.username.compareTo(b.username));
  }
}
