import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Bottom navigation bar matching the Vitality Health design system.
/// White surface, soft top border, active item highlighted with a mint pill.
class AppBottomNav extends StatelessWidget {
  /// Index of the active destination (0=Home, 1=Vitals, 2=Activity, 3=Settings).
  final int activeIndex;

  const AppBottomNav({super.key, required this.activeIndex});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home', route: '/dashboard'),
    (icon: Icons.monitor_heart_rounded, label: 'Vitals', route: '/heart-rate'),
    (icon: Icons.water_drop_rounded, label: 'Activity', route: '/spo2'),
    (icon: Icons.bedtime_rounded, label: 'Settings', route: '/sleep'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            for (var i = 0; i < _items.length; i++)
              _NavItem(
                icon: _items[i].icon,
                label: _items[i].label,
                active: i == activeIndex,
                onTap: () => context.go(_items[i].route),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.secondary : AppTheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.secondaryContainer.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
