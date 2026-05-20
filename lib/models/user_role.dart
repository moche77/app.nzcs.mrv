enum UserRole {
  administrator,
  receivingOperator,
  pyrolysisOperator,
  labTechnician,
  inventoryManager,
  fieldOperator,
  complianceReviewer,
}

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.receivingOperator:
        return 'Receiving Operator';
      case UserRole.pyrolysisOperator:
        return 'Pyrolysis Operator';
      case UserRole.labTechnician:
        return 'Lab Technician';
      case UserRole.inventoryManager:
        return 'Inventory Manager';
      case UserRole.fieldOperator:
        return 'Field Operator';
      case UserRole.complianceReviewer:
        return 'Compliance Reviewer';
    }
  }

  String get section {
    switch (this) {
      case UserRole.administrator:
        return 'Plant Administration';
      case UserRole.receivingOperator:
        return 'Receiving / Yard';
      case UserRole.pyrolysisOperator:
        return 'Pyrolysis Line';
      case UserRole.labTechnician:
        return 'Quality Lab';
      case UserRole.inventoryManager:
        return 'Warehouse / Inventory';
      case UserRole.fieldOperator:
        return 'Field Application';
      case UserRole.complianceReviewer:
        return 'Compliance & QA';
    }
  }

  /// Module IDs the role can access (1-7 corresponding to Excel sheet numbers)
  Set<int> get accessibleModules {
    switch (this) {
      case UserRole.administrator:
        return {0, 1, 2, 3, 4, 5, 6, 7}; // 0 = Dashboard
      case UserRole.receivingOperator:
        return {0, 1};
      case UserRole.pyrolysisOperator:
        return {0, 2};
      case UserRole.labTechnician:
        return {0, 3};
      case UserRole.inventoryManager:
        return {0, 4};
      case UserRole.fieldOperator:
        return {0, 5};
      case UserRole.complianceReviewer:
        return {0, 1, 2, 3, 4, 5, 6, 7}; // read-only enforced at UI level
    }
  }

  bool get isReadOnly => this == UserRole.complianceReviewer;
  bool get isAdmin => this == UserRole.administrator;
}

class AppUser {
  final String username;
  final String passwordHash;
  final UserRole role;
  final String fullName;
  final String email;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AppUser({
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.fullName,
    required this.email,
    this.mustChangePassword = false,
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() => {
        'username': username,
        'passwordHash': passwordHash,
        'role': role.name,
        'fullName': fullName,
        'email': email,
        'mustChangePassword': mustChangePassword,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
      };

  factory AppUser.fromMap(Map<dynamic, dynamic> m) => AppUser(
        username: m['username'] as String,
        passwordHash: m['passwordHash'] as String,
        role: UserRole.values.firstWhere((r) => r.name == m['role']),
        fullName: m['fullName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        mustChangePassword: m['mustChangePassword'] as bool? ?? false,
        createdAt: DateTime.parse(m['createdAt'] as String),
        lastLogin: m['lastLogin'] != null
            ? DateTime.parse(m['lastLogin'] as String)
            : null,
      );

  AppUser copyWith({
    String? passwordHash,
    bool? mustChangePassword,
    DateTime? lastLogin,
  }) =>
      AppUser(
        username: username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role,
        fullName: fullName,
        email: email,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        createdAt: createdAt,
        lastLogin: lastLogin ?? this.lastLogin,
      );
}
