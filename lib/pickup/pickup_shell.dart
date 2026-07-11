import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'screens/missions_screen.dart';
import 'screens/chat/roster_screen.dart';
import 'screens/her_screen.dart';
import 'screens/you_screen.dart';

/// The 4-tab home: Missions · Chat · Her · You. Missions is the front door.
class PickupShell extends StatefulWidget {
  const PickupShell({super.key});

  @override
  State<PickupShell> createState() => _PickupShellState();
}

class _PickupShellState extends State<PickupShell> {
  int _index = 0;

  static const _tabs = [
    ('MISSIONS', '🌍'),
    ('CHAT', '🎭'),
    ('HER', '💬'),
    ('YOU', '👤'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: IndexedStack(
        index: _index,
        children: const [
          MissionsScreen(),
          RosterScreen(),
          HerScreen(),
          YouScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(top: BorderSide(color: AppColors.surface3)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      glyph: _tabs[i].$2,
                      label: _tabs[i].$1,
                      active: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
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
  final String glyph;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 2,
            margin: const EdgeInsets.only(bottom: 8),
            color: active ? AppColors.red : Colors.transparent,
          ),
          Opacity(
            opacity: active ? 1 : 0.4,
            child: Text(glyph, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.label.copyWith(
                fontSize: 8,
                letterSpacing: 1.4,
                color: active ? AppColors.textPrimary : AppColors.textMuted,
              )),
        ],
      ),
    );
  }
}
