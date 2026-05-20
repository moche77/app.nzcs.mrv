import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// User management console — accessible to Owner and Administrators.
///
/// Authorization is enforced both here (UI gating) and inside AuthService
/// (defence in depth: the service layer rejects unauthorized mutations
/// even if the UI is bypassed).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }
    if (!me.hasPermission(Permission.manageUsers)) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Management')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have permission to manage users.\n'
              'Contact your Administrator or the Owner.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final allUsers = auth.getAllUsers();
    final filtered = _filter.isEmpty
        ? allUsers
        : allUsers.where((u) {
            final f = _filter.toLowerCase();
            return u.username.contains(f) ||
                u.fullName.toLowerCase().contains(f) ||
                u.email.toLowerCase().contains(f) ||
                u.role.label.toLowerCase().contains(f);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Create User',
            onPressed: () => _showCreateUserDialog(context, me),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPolicyBanner(me),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by username, name, email, or role…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No users match filter'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) =>
                        _buildUserTile(context, me, filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBanner(AppUser me) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                me.role.isOwner
                    ? 'Owner Console — Full Administrative Authority'
                    : 'Administrator Console — Limited User Management',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            me.role.isOwner
                ? 'You may create, modify, disable, and delete any account except the Owner identity. Print authorization grants are exclusive to you.'
                : 'You may manage department users only. Administrator accounts and print authorization are reserved to the Owner.',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, AppUser me, AppUser user) {
    final isMe = user.username == me.username;
    final isOwner = user.role.isOwner;
    final printActive = user.hasActivePrintGrant;
    Color roleColor;
    if (isOwner) {
      roleColor = const Color(0xFF6A1B9A); // purple — owner
    } else if (user.role == UserRole.administrator) {
      roleColor = AppTheme.primaryGreen;
    } else if (user.role == UserRole.complianceReviewer) {
      roleColor = const Color(0xFF1565C0);
    } else {
      roleColor = AppTheme.textSecondary;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: roleColor.withValues(alpha: 0.15),
        child: Icon(
          isOwner
              ? Icons.star
              : user.role == UserRole.administrator
                  ? Icons.admin_panel_settings_outlined
                  : user.role == UserRole.complianceReviewer
                      ? Icons.verified_user_outlined
                      : Icons.person_outline,
          color: roleColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.fullName.isEmpty ? user.username : user.fullName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: user.isActive
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                decoration: user.isActive
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe)
            _chip('YOU', AppTheme.primaryGreen),
          if (!user.isActive) _chip('DISABLED', AppTheme.dangerRed),
          if (printActive) _chip('PRINT', const Color(0xFFEF6C00)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '@${user.username} · ${user.email}',
            style: const TextStyle(fontSize: 11.5),
          ),
          Text(
            '${user.role.label} — ${user.role.section}',
            style: TextStyle(
              fontSize: 11.5,
              color: roleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (printActive)
            Text(
              'Print authorized until ${_fmtDate(user.printAuthorizedUntil!)} by ${user.printAuthorizedBy}',
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFFEF6C00),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _handleAction(context, me, user, v),
        itemBuilder: (_) => _buildActionMenu(me, user),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenu(AppUser me, AppUser user) {
    final canEdit = _canEdit(me, user);
    final canPrintGrant = me.role.isOwner && !user.role.isOwner;
    return [
      if (canEdit)
        const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
      if (canEdit)
        const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
      if (canEdit && !user.role.isOwner && user.username != me.username)
        PopupMenuItem(
          value: user.isActive ? 'disable' : 'enable',
          child: Text(user.isActive ? 'Disable Account' : 'Enable Account'),
        ),
      if (canPrintGrant && !user.hasActivePrintGrant)
        const PopupMenuItem(
            value: 'grant_print', child: Text('Grant Print Authorization')),
      if (canPrintGrant && user.hasActivePrintGrant)
        const PopupMenuItem(
            value: 'revoke_print', child: Text('Revoke Print Authorization')),
      if (canEdit && !user.role.isOwner && user.username != me.username)
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppTheme.dangerRed)),
        ),
    ];
  }

  /// Authorization gate for the actions menu.
  bool _canEdit(AppUser me, AppUser target) {
    if (target.role.isOwner) {
      return me.username == target.username; // only Owner edits self
    }
    if (target.role == UserRole.administrator) {
      return me.role.isOwner;
    }
    return true; // department user — editable by any user-manager
  }

  Future<void> _handleAction(
      BuildContext context, AppUser me, AppUser user, String action) async {
    final auth = context.read<AuthService>();
    switch (action) {
      case 'edit':
        await _showEditUserDialog(context, me, user);
        break;
      case 'reset':
        final result = await auth.adminResetPassword(user.username);
        if (!context.mounted) return;
        if (result != null && result.startsWith('TEMP_PASSWORD:')) {
          _showTempPasswordDialog(context, user.username, result.split(':')[1]);
        } else {
          _toast(context, result ?? 'Reset failed', AppTheme.dangerRed);
        }
        break;
      case 'disable':
        final err =
            await auth.updateUser(username: user.username, isActive: false);
        if (!context.mounted) return;
        _toast(context, err ?? 'Account disabled',
            err == null ? AppTheme.primaryGreen : AppTheme.dangerRed);
        break;
      case 'enable':
        final err =
            await auth.updateUser(username: user.username, isActive: true);
        if (!context.mounted) return;
        _toast(context, err ?? 'Account enabled',
            err == null ? AppTheme.primaryGreen : AppTheme.dangerRed);
        break;
      case 'grant_print':
        await _showGrantPrintDialog(context, user);
        break;
      case 'revoke_print':
        final err = await auth.revokePrintAuthorization(user.username);
        if (!context.mounted) return;
        _toast(context, err ?? 'Print authorization revoked',
            err == null ? AppTheme.primaryGreen : AppTheme.dangerRed);
        break;
      case 'delete':
        await _confirmDelete(context, user);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Permanently delete @${user.username} (${user.fullName})? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final err = await context.read<AuthService>().deleteUser(user.username);
    if (!context.mounted) return;
    _toast(context, err ?? 'User deleted',
        err == null ? AppTheme.primaryGreen : AppTheme.dangerRed);
  }

  Future<void> _showCreateUserDialog(BuildContext context, AppUser me) async {
    final usernameCtl = TextEditingController();
    final fullNameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final passwordCtl = TextEditingController();
    UserRole selectedRole = UserRole.receivingOperator;
    final formKey = GlobalKey<FormState>();

    final availableRoles = me.role.isOwner
        ? [
            UserRole.administrator,
            UserRole.receivingOperator,
            UserRole.pyrolysisOperator,
            UserRole.labTechnician,
            UserRole.inventoryManager,
            UserRole.fieldOperator,
            UserRole.complianceReviewer,
          ]
        : [
            UserRole.receivingOperator,
            UserRole.pyrolysisOperator,
            UserRole.labTechnician,
            UserRole.inventoryManager,
            UserRole.fieldOperator,
            UserRole.complianceReviewer,
          ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: const Text('Create New User'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameCtl,
                      decoration: const InputDecoration(
                          labelText: 'Username (min 3 chars, lowercase)'),
                      validator: (v) {
                        if (v == null || v.trim().length < 3) {
                          return 'At least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: fullNameCtl,
                      decoration:
                          const InputDecoration(labelText: 'Full Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Must be @netzerocarbon.solutions',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!IdentityPolicy.isEmailAllowed(v) ||
                            IdentityPolicy.isOwnerEmail(v)) {
                          return 'Must end with @netzerocarbon.solutions';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordCtl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Initial Password (min 8 chars)'),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Min 8 chars' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: availableRoles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedRole = v);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Department: ${selectedRole.section}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final err = await context.read<AuthService>().createUser(
                      username: usernameCtl.text,
                      password: passwordCtl.text,
                      role: selectedRole,
                      fullName: fullNameCtl.text,
                      email: emailCtl.text,
                    );
                if (!ctx.mounted) return;
                if (err == null) {
                  Navigator.pop(ctx);
                  _toast(context, 'User created', AppTheme.primaryGreen);
                } else {
                  _toast(ctx, err, AppTheme.dangerRed);
                }
              },
              child: const Text('CREATE'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showEditUserDialog(
      BuildContext context, AppUser me, AppUser user) async {
    final fullNameCtl = TextEditingController(text: user.fullName);
    final emailCtl = TextEditingController(text: user.email);
    UserRole selectedRole = user.role;
    final formKey = GlobalKey<FormState>();

    final canEditRole =
        !user.role.isOwner && (me.role.isOwner || user.role != UserRole.administrator);
    final canEditEmail = !user.role.isOwner;

    final availableRoles = me.role.isOwner
        ? UserRole.values.where((r) => r != UserRole.owner).toList()
        : UserRole.values
            .where((r) =>
                r != UserRole.owner && r != UserRole.administrator)
            .toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text('Edit ${user.username}'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fullNameCtl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailCtl,
                    enabled: canEditEmail,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!IdentityPolicy.isEmailAllowed(v)) {
                        return 'Must be @netzerocarbon.solutions';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: (canEditRole ? availableRoles : [user.role])
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: canEditRole
                        ? (v) {
                            if (v != null) setLocal(() => selectedRole = v);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final err = await context.read<AuthService>().updateUser(
                      username: user.username,
                      fullName: fullNameCtl.text,
                      email: canEditEmail ? emailCtl.text : null,
                      role: canEditRole ? selectedRole : null,
                    );
                if (!ctx.mounted) return;
                if (err == null) {
                  Navigator.pop(ctx);
                  _toast(context, 'User updated', AppTheme.primaryGreen);
                } else {
                  _toast(ctx, err, AppTheme.dangerRed);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showGrantPrintDialog(BuildContext context, AppUser user) async {
    int hours = 24;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text('Grant Print Authorization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authorize @${user.username} (${user.fullName}) to generate and print final PDF reports for a limited time.',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Text('Duration: $hours hour${hours == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                min: 1,
                max: 168,
                divisions: 167,
                value: hours.toDouble(),
                label: '$hours h',
                onChanged: (v) => setLocal(() => hours = v.round()),
              ),
              const Text(
                'Common windows: 4 h (single audit session), 24 h (full day), 72 h (3-day audit period), 168 h (1 week).',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final err =
                    await context.read<AuthService>().grantPrintAuthorization(
                          username: user.username,
                          duration: Duration(hours: hours),
                        );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _toast(context, err ?? 'Print authorization granted for $hours h',
                    err == null ? AppTheme.primaryGreen : AppTheme.dangerRed);
              },
              child: const Text('GRANT'),
            ),
          ],
        );
      }),
    );
  }

  void _showTempPasswordDialog(
      BuildContext context, String username, String tempPwd) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Temporary Password Issued'),
        content: SelectableText(
          'User @$username must use this temporary password to log in. They will be required to set a new password immediately.\n\nTemporary password: $tempPwd',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );

  void _toast(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$min';
  }
}
