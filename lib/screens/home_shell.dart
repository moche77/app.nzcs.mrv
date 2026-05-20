import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'feedstock_screen.dart';
import 'production_screen.dart';
import 'quality_screen.dart';
import 'inventory_screen.dart';
import 'application_screen.dart';
import 'global_qa_screen.dart';
import 'audit_controls_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const List<_ModuleDef> _allModules = [
    _ModuleDef(0, 'Dashboard', Icons.dashboard_outlined),
    _ModuleDef(1, 'Feedstock', Icons.local_shipping_outlined),
    _ModuleDef(2, 'Production', Icons.factory_outlined),
    _ModuleDef(3, 'Quality', Icons.science_outlined),
    _ModuleDef(4, 'Inventory', Icons.inventory_2_outlined),
    _ModuleDef(5, 'Application', Icons.agriculture_outlined),
    _ModuleDef(6, 'Global QA', Icons.fact_check_outlined),
    _ModuleDef(7, 'Audit', Icons.security_outlined),
  ];

  List<_ModuleDef> _accessibleModules(UserRole role) {
    return _allModules
        .where((m) => role.accessibleModules.contains(m.id))
        .toList();
  }

  Widget _buildScreen(int moduleId, UserRole role) {
    final readOnly = role.isReadOnly;
    switch (moduleId) {
      case 0:
        return DashboardScreen(isAdmin: role.isAdmin);
      case 1:
        return FeedstockScreen(readOnly: readOnly);
      case 2:
        return ProductionScreen(readOnly: readOnly);
      case 3:
        return QualityScreen(readOnly: readOnly);
      case 4:
        return InventoryScreen(readOnly: readOnly);
      case 5:
        return ApplicationScreen(readOnly: readOnly);
      case 6:
        return GlobalQAScreen(readOnly: readOnly);
      case 7:
        return AuditControlsScreen(readOnly: readOnly);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    final modules = _accessibleModules(user.role);
    if (_currentIndex >= modules.length) _currentIndex = 0;
    final currentModule = modules[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentModule.label),
            Text(
              user.role.label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (user.role.isAdmin || user.role == UserRole.complianceReviewer)
            IconButton(
              tooltip: 'Reports & Export',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthService>().logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else if (v == 'pwd') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              } else if (v == 'help') {
                _showHelp(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text('@${user.username}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'pwd',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline),
                  title: Text('Change Password'),
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.help_outline),
                  title: Text('Help & Onboarding'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: AppTheme.dangerRed),
                  title: Text('Sign Out',
                      style: TextStyle(color: AppTheme.dangerRed)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (final m in modules) _buildScreen(m.id, user.role),
        ],
      ),
      bottomNavigationBar: modules.length <= 1
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: [
                for (final m in modules)
                  NavigationDestination(
                    icon: Icon(m.icon),
                    selectedIcon: Icon(m.icon, color: AppTheme.primaryGreen),
                    label: m.label,
                  ),
              ],
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              height: 68,
            ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('NerZero MRV — Quick Onboarding'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This application replicates the VM0044 Unified MRV workbook as an audit-grade mobile system.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Workflow Sequence:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text(
                '1. Receiving logs accepted feedstock (dry mass)\n'
                '2. Pyrolysis Operator records production runs\n'
                '3. Lab Technician samples and certifies batches\n'
                '4. Inventory Manager reconciles and allocates\n'
                '5. Field Operator records application events\n'
                '6. Compliance Reviewer signs off the period\n'
                '7. Administrator monitors integrity & emission factors',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                'All calculations follow VM0044 dry-basis mass accounting and stoichiometric C → CO₂ conversion (44/12).',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _ModuleDef {
  final int id;
  final String label;
  final IconData icon;
  const _ModuleDef(this.id, this.label, this.icon);
}
