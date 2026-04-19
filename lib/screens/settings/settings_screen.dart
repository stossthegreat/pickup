import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: Sp.md),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    splashRadius: 22,
                  ),
                  const Spacer(),
                  Text('SETTINGS', style: AppTypography.label.copyWith(
                    color: AppColors.textTertiary, letterSpacing: 3, fontSize: 11)),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              const SizedBox(height: Sp.lg),

              // App identity
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface2,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          width: 1.5),
                      ),
                      child: Center(
                        child: Text('M',
                          style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700,
                            color: AppColors.accent, letterSpacing: -1)),
                      ),
                    ),
                    const SizedBox(height: Sp.sm),
                    Text('Mirrorly', style: AppTypography.h2),
                    const SizedBox(height: 4),
                    Text('Version 1.0.0', style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary, fontSize: 11)),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: Sp.xl),

              // Account
              _SectionHeader('ACCOUNT'),
              _SettingTile(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Manage your identity',
                onTap: () => _showSoon(context),
              ),
              _SettingTile(
                icon: Icons.star_border,
                title: 'Mirrorly Pro',
                subtitle: 'Unlimited scans + try-ons',
                trailing: _Badge(label: 'COMING SOON'),
                onTap: () => _showSoon(context),
              ),

              const SizedBox(height: Sp.lg),

              // Scan
              _SectionHeader('SCAN'),
              _SettingTile(
                icon: Icons.history,
                title: 'Rescan history',
                subtitle: 'Your structural progress over time',
                onTap: () => _showSoon(context),
              ),
              _SettingTile(
                icon: Icons.download_outlined,
                title: 'Export report',
                subtitle: 'Save your last scan as PDF',
                onTap: () => _showSoon(context),
              ),

              const SizedBox(height: Sp.lg),

              // Privacy
              _SectionHeader('PRIVACY'),
              _SettingTile(
                icon: Icons.shield_outlined,
                title: 'Data & privacy',
                subtitle: 'Photos are not stored by default',
                onTap: () => _showPrivacy(context),
              ),
              _SettingTile(
                icon: Icons.delete_outline,
                title: 'Delete all data',
                subtitle: 'Permanently remove your scans',
                destructive: true,
                onTap: () => _confirmDelete(context),
              ),

              const SizedBox(height: Sp.lg),

              // About
              _SectionHeader('ABOUT'),
              _SettingTile(
                icon: Icons.description_outlined,
                title: 'How Mirrorly works',
                subtitle: 'The science behind the scan',
                onTap: () => _showHow(context),
              ),
              _SettingTile(
                icon: Icons.gavel_outlined,
                title: 'Terms of service',
                onTap: () => _showSoon(context),
              ),
              _SettingTile(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                onTap: () => _showSoon(context),
              ),
              _SettingTile(
                icon: Icons.mail_outline,
                title: 'Contact',
                subtitle: 'hello@mirrorly.app',
                onTap: () => _showSoon(context),
              ),

              const SizedBox(height: Sp.xxl),

              Center(
                child: Text(
                  '© 2026 Mirrorly',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary, fontSize: 11),
                ),
              ),
              const SizedBox(height: Sp.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoon(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface2,
        content: Text('Coming soon',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacy(BuildContext ctx) => _showInfoSheet(ctx,
    'How we handle your data',
    'Mirrorly processes your face locally on your device first. '
    'The measurement data and captured photo are sent to our servers only to '
    'generate the analysis and maximized image.\n\n'
    'We do not store your photos permanently.\n'
    'We do not sell your data.\n'
    'We do not train AI models on your images.',
  );

  void _showHow(BuildContext ctx) => _showInfoSheet(ctx,
    'How Mirrorly works',
    'Three stages:\n\n'
    '1. MediaPipe maps 468 landmarks on your face at 30fps, on-device.\n\n'
    '2. From those landmarks we compute hard geometric measurements — '
    'canthal tilt, FWHR, facial thirds, symmetry, jaw angle.\n\n'
    '3. GPT-4o receives those measurements as ground truth alongside your '
    'photo. It can\'t guess geometry — only interpret what geometry can\'t '
    'see: skin, grooming, styling.\n\n'
    '4. Flux Kontext renders your maximized version, anchored to your '
    'measured bone structure so the result is still recognizably you.',
  );

  void _showInfoSheet(BuildContext ctx, String title, String body) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: Sp.lg),
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(title, style: AppTypography.h2),
            const SizedBox(height: Sp.md),
            Text(body, style: AppTypography.body),
            const SizedBox(height: Sp.lg),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('Delete all data?',
          style: AppTypography.h3.copyWith(color: AppColors.signalRed)),
        content: Text(
          'This removes all your scans and reports from this device. '
          'This cannot be undone.',
          style: AppTypography.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.surface2,
                content: Text('Data cleared',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary)),
              ));
            },
            child: Text('Delete',
              style: TextStyle(color: AppColors.signalRed)),
          ),
        ],
      ),
    );
  }
}

// ── Components ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(label, style: AppTypography.label.copyWith(
      color: AppColors.textTertiary, letterSpacing: 2)),
  );
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.signalRed : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.lg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(Rd.lg),
            border: Border.all(color: AppColors.surface3),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: destructive
                  ? AppColors.signalRed
                  : AppColors.textSecondary),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.body.copyWith(
                      color: color, fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!
              else if (!destructive)
                const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.12),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: AppTypography.label.copyWith(
      color: AppColors.accent, fontSize: 8, letterSpacing: 1.4)),
  );
}
