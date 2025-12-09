import 'package:flutter/material.dart';
import '../theme/app-theme.dart';

class AppSidebar extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(String) onNavigate;
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onNavigate,
    this.currentRoute = 'home',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left: isOpen ? 0 : -280,
      top: 0,
      bottom: 0,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppTheme.black,
          border: Border(
            right: BorderSide(color: AppTheme.gray800, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S.A.G.E',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SITUATIONAL AWARENESS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.gray500,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Navigation
                Expanded(
                  child: Column(
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isActive: currentRoute == 'home',
                        onTap: () {
                          print('Home tapped'); // Debug
                          onNavigate('home');
                        },
                      ),
                      const SizedBox(height: 8),
                      _NavItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isActive: currentRoute == 'settings',
                        onTap: () {
                          print('Settings tapped'); // Debug
                          onNavigate('settings');
                        },
                      ),
                    ],
                  ),
                ),
                
                // Account Section
                _AccountButton(
                  onTap: () {
                    print('Account tapped'); // Debug
                    onNavigate('account');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.gray900 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppTheme.cyan, AppTheme.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person_rounded, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'Account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
