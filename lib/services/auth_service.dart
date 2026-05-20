import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/user_role.dart';

/// Authentication & authorization service for NerZero MRV.
///
/// SECURITY MODEL:
///   - Owner identity (manuel@titantradersltd.com) is hard-coded and seeded
///     on first launch. Cannot be deleted, demoted, or have role changed.
///   - All other accounts MUST use @netzerocarbon.solutions domain.
///   - Administrators may create/edit/disable department users only.
///   - Only the Owner may create or modify Administrator accounts.
///   - Only the Owner may grant a print-authorization token (time-boxed).
class AuthService extends ChangeNotifier {
  static const String _boxName = 'users_box';
  static const String _sessionBoxName = 'session_box';

  /// Bump this when the user schema is intentionally broken to force re-seed.
  static const int _currentSchemaVersion = 2;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.isActive;

  late Box _userBox;
  late Box _sessionBox;

  String _hashPassword(String password) {
    final bytes = utf8.encode('NerZeroMRV_$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> initialize() async {
    _userBox = await Hive.openBox(_boxName);
    _sessionBox = await Hive.openBox(_sessionBoxName);

    // Schema migration: forces re-seed when role hierarchy changes.
    final storedVersion = _sessionBox.get('schema_version') as int? ?? 1;
    if (storedVersion < _currentSchemaVersion) {
      await _migrateSchema(storedVersion);
      await _sessionBox.put('schema_version', _currentSchemaVersion);
    }

    await _seedDefaultUsersIfEmpty();
    await _ensureOwnerExists();
    await _restoreSession();
  }

  /// One-shot migration: when upgrading from the legacy 7-role model to the
  /// new 8-role Owner-led hierarchy, we keep existing accounts but ensure
  /// the Owner account is present and any role names still resolve.
  Future<void> _migrateSchema(int fromVersion) async {
    if (fromVersion < 2) {
      // No destructive changes; _ensureOwnerExists() will inject the Owner.
      // Existing usernames remain valid.
    }
  }

  Future<void> _seedDefaultUsersIfEmpty() async {
    if (_userBox.isNotEmpty) return;
    final now = DateTime.now();
    final seedUsers = [
      AppUser(
        username: 'manuel',
        passwordHash: _hashPassword('ChangeMe!2025'),
        role: UserRole.owner,
        fullName: 'Manuel — Owner / Developer',
        email: IdentityPolicy.ownerEmail,
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'admin',
        passwordHash: _hashPassword('admin123'),
        role: UserRole.administrator,
        fullName: 'Plant Administrator',
        email: 'admin@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'receiving',
        passwordHash: _hashPassword('password123'),
        role: UserRole.receivingOperator,
        fullName: 'Receiving Operator',
        email: 'receiving@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'pyrolysis',
        passwordHash: _hashPassword('password123'),
        role: UserRole.pyrolysisOperator,
        fullName: 'Pyrolysis Operator',
        email: 'pyrolysis@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'lab',
        passwordHash: _hashPassword('password123'),
        role: UserRole.labTechnician,
        fullName: 'Lab Technician',
        email: 'lab@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'inventory',
        passwordHash: _hashPassword('password123'),
        role: UserRole.inventoryManager,
        fullName: 'Inventory Manager',
        email: 'inventory@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'field',
        passwordHash: _hashPassword('password123'),
        role: UserRole.fieldOperator,
        fullName: 'Field Operator',
        email: 'field@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
      AppUser(
        username: 'compliance',
        passwordHash: _hashPassword('password123'),
        role: UserRole.complianceReviewer,
        fullName: 'Compliance Reviewer',
        email: 'compliance@netzerocarbon.solutions',
        mustChangePassword: true,
        createdAt: now,
      ),
    ];
    for (final u in seedUsers) {
      await _userBox.put(u.username, u.toMap());
    }
  }

  /// Defensive: even if the user box has been tampered with, the Owner
  /// account is always present (cannot be locked out of the system).
  Future<void> _ensureOwnerExists() async {
    final owner = _userBox.values
        .map((m) => AppUser.fromMap(Map<String, dynamic>.from(m as Map)))
        .where((u) => u.role == UserRole.owner)
        .firstOrNull;
    if (owner == null) {
      final ownerUser = AppUser(
        username: 'manuel',
        passwordHash: _hashPassword('ChangeMe!2025'),
        role: UserRole.owner,
        fullName: 'Manuel — Owner / Developer',
        email: IdentityPolicy.ownerEmail,
        mustChangePassword: true,
        createdAt: DateTime.now(),
      );
      await _userBox.put(ownerUser.username, ownerUser.toMap());
    }
  }

  Future<void> _restoreSession() async {
    final username = _sessionBox.get('current_user');
    if (username != null && _userBox.containsKey(username)) {
      final m = _userBox.get(username);
      final user = AppUser.fromMap(Map<String, dynamic>.from(m as Map));
      if (user.isActive) {
        _currentUser = user;
        notifyListeners();
      } else {
        await _sessionBox.delete('current_user');
      }
    }
  }

  Future<String?> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) {
      return 'Invalid username or password';
    }
    final m = _userBox.get(key);
    final user = AppUser.fromMap(Map<String, dynamic>.from(m as Map));

    if (!user.isActive) {
      return 'Account is disabled. Contact your administrator.';
    }
    if (user.passwordHash != _hashPassword(password)) {
      return 'Invalid username or password';
    }
    // Re-validate email domain on every login (catches policy drift).
    if (!IdentityPolicy.isEmailAllowed(user.email)) {
      return 'Account email no longer meets domain policy. Contact ${IdentityPolicy.ownerEmail}.';
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
    if (newPassword.length < 8) {
      return 'New password must be at least 8 characters';
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

  // ---------------------------------------------------------------------------
  // USER MANAGEMENT (Owner / Administrator)
  // ---------------------------------------------------------------------------

  List<AppUser> getAllUsers() {
    return _userBox.values
        .map((m) => AppUser.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) {
        // Owner first, then Admins, then by username.
        if (a.role == UserRole.owner) return -1;
        if (b.role == UserRole.owner) return 1;
        if (a.role == UserRole.administrator && b.role != UserRole.administrator) {
          return -1;
        }
        if (b.role == UserRole.administrator && a.role != UserRole.administrator) {
          return 1;
        }
        return a.username.compareTo(b.username);
      });
  }

  /// Create a new user. Authorization rules:
  ///   - Only the Owner may create an Administrator.
  ///   - Administrators may create department users only.
  ///   - All non-owner users must have @netzerocarbon.solutions email.
  Future<String?> createUser({
    required String username,
    required String password,
    required UserRole role,
    required String fullName,
    required String email,
  }) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.manageUsers)) {
      return 'You do not have permission to manage users';
    }

    // Only the Owner may create another Owner (which is forbidden) or an Administrator.
    if (role == UserRole.owner) {
      return 'Owner role cannot be created — it is a singleton system identity';
    }
    if (role == UserRole.administrator && !_currentUser!.role.isOwner) {
      return 'Only the Owner may create Administrator accounts';
    }

    if (!IdentityPolicy.isEmailAllowed(email)) {
      return IdentityPolicy.domainErrorMessage();
    }
    if (IdentityPolicy.isOwnerEmail(email)) {
      return 'This email is reserved for the Owner identity';
    }

    final key = username.trim().toLowerCase();
    if (key.isEmpty || key.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (_userBox.containsKey(key)) {
      return 'Username already exists';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    final user = AppUser(
      username: key,
      passwordHash: _hashPassword(password),
      role: role,
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      mustChangePassword: true,
      createdAt: DateTime.now(),
    );
    await _userBox.put(key, user.toMap());
    notifyListeners();
    return null;
  }

  /// Update an existing user's mutable fields.
  /// Authorization mirrors createUser.
  Future<String?> updateUser({
    required String username,
    String? fullName,
    String? email,
    UserRole? role,
    bool? isActive,
  }) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.manageUsers)) {
      return 'You do not have permission to manage users';
    }

    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'User not found';

    final existing = AppUser.fromMap(
        Map<String, dynamic>.from(_userBox.get(key) as Map));

    // The Owner cannot be modified by anyone other than themselves,
    // and even then their role and email are immutable.
    if (existing.role == UserRole.owner) {
      if (_currentUser!.username != existing.username) {
        return 'Only the Owner may modify the Owner account';
      }
      if (role != null && role != UserRole.owner) {
        return 'The Owner role cannot be changed';
      }
      if (email != null &&
          email.trim().toLowerCase() != IdentityPolicy.ownerEmail.toLowerCase()) {
        return 'The Owner email is immutable';
      }
    }

    // Promoting/demoting to Administrator requires Owner.
    if (role != null &&
        role != existing.role &&
        (role == UserRole.administrator ||
            existing.role == UserRole.administrator) &&
        !_currentUser!.role.isOwner) {
      return 'Only the Owner may grant or revoke the Administrator role';
    }

    if (email != null && !IdentityPolicy.isEmailAllowed(email)) {
      return IdentityPolicy.domainErrorMessage();
    }

    final updated = existing.copyWith(
      fullName: fullName,
      email: email?.trim().toLowerCase(),
      role: role,
      isActive: isActive,
    );
    await _userBox.put(key, updated.toMap());

    // If we just modified our own session user, refresh in-memory copy.
    if (_currentUser!.username == key) {
      _currentUser = updated;
    }
    notifyListeners();
    return null;
  }

  /// Reset a user's password (sets a temporary password forcing a change).
  Future<String?> adminResetPassword(String username) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.manageUsers)) {
      return 'You do not have permission to reset passwords';
    }

    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'User not found';

    final existing = AppUser.fromMap(
        Map<String, dynamic>.from(_userBox.get(key) as Map));

    if (existing.role == UserRole.owner && !_currentUser!.role.isOwner) {
      return 'Only the Owner may reset the Owner password';
    }
    if (existing.role == UserRole.administrator && !_currentUser!.role.isOwner) {
      return 'Only the Owner may reset an Administrator password';
    }

    final tempPassword = 'Temp${DateTime.now().millisecondsSinceEpoch % 100000}';
    final updated = existing.copyWith(
      passwordHash: _hashPassword(tempPassword),
      mustChangePassword: true,
    );
    await _userBox.put(key, updated.toMap());
    notifyListeners();
    return 'TEMP_PASSWORD:$tempPassword';
  }

  Future<String?> deleteUser(String username) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.manageUsers)) {
      return 'You do not have permission to delete users';
    }
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'User not found';

    final existing = AppUser.fromMap(
        Map<String, dynamic>.from(_userBox.get(key) as Map));

    if (existing.role == UserRole.owner) {
      return 'The Owner account cannot be deleted';
    }
    if (existing.role == UserRole.administrator && !_currentUser!.role.isOwner) {
      return 'Only the Owner may delete an Administrator';
    }
    if (existing.username == _currentUser!.username) {
      return 'You cannot delete your own account';
    }
    await _userBox.delete(key);
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // PRINT AUTHORIZATION (Owner only)
  // ---------------------------------------------------------------------------

  /// Grant a time-boxed print authorization to another user.
  /// Only the Owner may invoke this.
  Future<String?> grantPrintAuthorization({
    required String username,
    required Duration duration,
  }) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.authorizePrintDelegation)) {
      return 'Only the Owner may authorize print delegation';
    }
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'User not found';

    final existing = AppUser.fromMap(
        Map<String, dynamic>.from(_userBox.get(key) as Map));

    if (existing.role == UserRole.owner) {
      return 'The Owner already has inherent print authority';
    }

    final updated = existing.copyWith(
      printAuthorizedUntil: DateTime.now().add(duration),
      printAuthorizedBy: _currentUser!.username,
    );
    await _userBox.put(key, updated.toMap());
    notifyListeners();
    return null;
  }

  Future<String?> revokePrintAuthorization(String username) async {
    if (_currentUser == null) return 'Not authenticated';
    if (!_currentUser!.hasPermission(Permission.authorizePrintDelegation)) {
      return 'Only the Owner may revoke print delegation';
    }
    final key = username.trim().toLowerCase();
    if (!_userBox.containsKey(key)) return 'User not found';

    final existing = AppUser.fromMap(
        Map<String, dynamic>.from(_userBox.get(key) as Map));
    final updated = existing.copyWith(clearPrintAuth: true);
    await _userBox.put(key, updated.toMap());
    notifyListeners();
    return null;
  }

  /// Convenience helper for UI: does the *current* session user have
  /// effective print rights right now?
  bool get canPrintReports =>
      _currentUser != null &&
      _currentUser!.isActive &&
      _currentUser!.hasPermission(Permission.generatePdfReport);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
