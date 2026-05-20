// Net Zero Carbon Solutions — VM0044 Carbon Audit Application
// Role-Based Access Control (RBAC) Hierarchy
//
// THREE-TIER ROLE MODEL:
//   1. OWNER (manuel@titantradersltd.com) — sole developer/main owner.
//      Exclusive authority: print final reports, authorize print delegation,
//      manage Administrators, system configuration. Domain-exempt.
//   2. ADMINISTRATOR (@netzerocarbon.solutions) — cross-department data entry
//      and data review for all 7 modules + dashboard. Print only when granted
//      a print-authorization token by the Owner.
//   3. DEPARTMENT USER (@netzerocarbon.solutions) — single-department data
//      entry and read access. No print capability.
//
// DOMAIN RESTRICTION: All accounts EXCEPT the Owner must use an
// @netzerocarbon.solutions email address.

enum UserRole {
  owner,
  administrator,
  receivingOperator,
  pyrolysisOperator,
  labTechnician,
  inventoryManager,
  fieldOperator,
  complianceReviewer,
}

/// Permission atoms — each capability the app enforces.
enum Permission {
  // Data operations
  enterDataAllDepartments,
  enterDataOwnDepartment,
  reviewDataAllDepartments,
  deleteRecords,

  // Dashboard & reporting
  viewDashboard,
  exportCsv,
  generatePdfReport,        // OWNER only (or delegated via print token)
  authorizePrintDelegation, // OWNER only — grants temporary print rights

  // System administration
  manageUsers,              // OWNER (full) + ADMIN (limited to dept users)
  manageEmissionFactors,
  viewAuditLog,
  configureSystem,          // OWNER only
}

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Owner / Developer';
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
      case UserRole.owner:
        return 'Executive / Ownership';
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

  /// Module IDs accessible (0=Dashboard, 1=Feedstock, 2=Production,
  /// 3=Quality, 4=Inventory, 5=Application, 6=Global QA, 7=Audit Controls)
  Set<int> get accessibleModules {
    switch (this) {
      case UserRole.owner:
        return {0, 1, 2, 3, 4, 5, 6, 7};
      case UserRole.administrator:
        return {0, 1, 2, 3, 4, 5, 6, 7};
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
        return {0, 1, 2, 3, 4, 5, 6, 7};
    }
  }

  /// Inherent (non-delegated) permissions for this role.
  Set<Permission> get inherentPermissions {
    switch (this) {
      case UserRole.owner:
        return {
          Permission.enterDataAllDepartments,
          Permission.enterDataOwnDepartment,
          Permission.reviewDataAllDepartments,
          Permission.deleteRecords,
          Permission.viewDashboard,
          Permission.exportCsv,
          Permission.generatePdfReport,
          Permission.authorizePrintDelegation,
          Permission.manageUsers,
          Permission.manageEmissionFactors,
          Permission.viewAuditLog,
          Permission.configureSystem,
        };
      case UserRole.administrator:
        return {
          Permission.enterDataAllDepartments,
          Permission.enterDataOwnDepartment,
          Permission.reviewDataAllDepartments,
          Permission.viewDashboard,
          Permission.exportCsv,
          Permission.manageUsers,         // limited scope enforced at service layer
          Permission.manageEmissionFactors,
          Permission.viewAuditLog,
        };
      case UserRole.complianceReviewer:
        return {
          Permission.reviewDataAllDepartments,
          Permission.viewDashboard,
          Permission.exportCsv,
          Permission.viewAuditLog,
        };
      case UserRole.receivingOperator:
      case UserRole.pyrolysisOperator:
      case UserRole.labTechnician:
      case UserRole.inventoryManager:
      case UserRole.fieldOperator:
        return {
          Permission.enterDataOwnDepartment,
          Permission.viewDashboard,
          Permission.exportCsv,
        };
    }
  }

  bool get isOwner => this == UserRole.owner;
  bool get isAdmin => this == UserRole.administrator || this == UserRole.owner;
  bool get isReadOnly => this == UserRole.complianceReviewer;
  bool get isDepartmentUser =>
      this != UserRole.owner &&
      this != UserRole.administrator &&
      this != UserRole.complianceReviewer;
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

  /// Print-authorization token granted by the Owner. When non-null and
  /// not expired, this user may generate PDF reports for the duration.
  final DateTime? printAuthorizedUntil;
  final String? printAuthorizedBy;

  /// Soft-disable flag — set by Owner/Admin to revoke access without
  /// deleting the record (preserves audit trail).
  final bool isActive;

  AppUser({
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.fullName,
    required this.email,
    this.mustChangePassword = false,
    required this.createdAt,
    this.lastLogin,
    this.printAuthorizedUntil,
    this.printAuthorizedBy,
    this.isActive = true,
  });

  /// Effective permissions = inherent ∪ delegated (print authorization).
  Set<Permission> get effectivePermissions {
    final perms = Set<Permission>.from(role.inherentPermissions);
    if (printAuthorizedUntil != null &&
        printAuthorizedUntil!.isAfter(DateTime.now())) {
      perms.add(Permission.generatePdfReport);
    }
    return perms;
  }

  bool hasPermission(Permission p) => effectivePermissions.contains(p);

  bool get hasActivePrintGrant =>
      printAuthorizedUntil != null &&
      printAuthorizedUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        'username': username,
        'passwordHash': passwordHash,
        'role': role.name,
        'fullName': fullName,
        'email': email,
        'mustChangePassword': mustChangePassword,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
        'printAuthorizedUntil': printAuthorizedUntil?.toIso8601String(),
        'printAuthorizedBy': printAuthorizedBy,
        'isActive': isActive,
      };

  factory AppUser.fromMap(Map<dynamic, dynamic> m) => AppUser(
        username: m['username'] as String,
        passwordHash: m['passwordHash'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == m['role'],
          orElse: () => UserRole.receivingOperator,
        ),
        fullName: m['fullName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        mustChangePassword: m['mustChangePassword'] as bool? ?? false,
        createdAt: DateTime.parse(m['createdAt'] as String),
        lastLogin: m['lastLogin'] != null
            ? DateTime.parse(m['lastLogin'] as String)
            : null,
        printAuthorizedUntil: m['printAuthorizedUntil'] != null
            ? DateTime.parse(m['printAuthorizedUntil'] as String)
            : null,
        printAuthorizedBy: m['printAuthorizedBy'] as String?,
        isActive: m['isActive'] as bool? ?? true,
      );

  AppUser copyWith({
    String? passwordHash,
    String? fullName,
    String? email,
    UserRole? role,
    bool? mustChangePassword,
    DateTime? lastLogin,
    DateTime? printAuthorizedUntil,
    String? printAuthorizedBy,
    bool? isActive,
    bool clearPrintAuth = false,
  }) =>
      AppUser(
        username: username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        createdAt: createdAt,
        lastLogin: lastLogin ?? this.lastLogin,
        printAuthorizedUntil: clearPrintAuth
            ? null
            : (printAuthorizedUntil ?? this.printAuthorizedUntil),
        printAuthorizedBy:
            clearPrintAuth ? null : (printAuthorizedBy ?? this.printAuthorizedBy),
        isActive: isActive ?? this.isActive,
      );
}

/// Centralised domain & owner identity rules.
class IdentityPolicy {
  static const String ownerEmail = 'manuel@titantradersltd.com';
  static const String allowedDomain = '@netzerocarbon.solutions';

  /// Email validation: Owner is whitelisted explicitly; all others must
  /// be on the @netzerocarbon.solutions domain. Case-insensitive.
  static bool isEmailAllowed(String email) {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return false;
    if (e == ownerEmail.toLowerCase()) return true;
    return e.endsWith(allowedDomain.toLowerCase());
  }

  static bool isOwnerEmail(String email) =>
      email.trim().toLowerCase() == ownerEmail.toLowerCase();

  static String domainErrorMessage() =>
      'Email must be on the $allowedDomain domain. '
      'Contact manuel@titantradersltd.com to request access.';
}
