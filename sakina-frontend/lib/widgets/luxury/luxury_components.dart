import 'package:flutter/material.dart';

import '../../design/sakina_colors.dart';

/// Islamic geometric accent strip for headers and cards.
class SakinaGeometricAccent extends StatelessWidget {
  const SakinaGeometricAccent({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SakinaColors.emerald, SakinaColors.gold, SakinaColors.emerald],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }
}

class IslamicSectionHeader extends StatelessWidget {
  const IslamicSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: SakinaColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: SakinaColors.navy,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SakinaColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SakinaColors.emerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

enum SakinaRole { guest, user, scholar, admin }

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final SakinaRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      SakinaRole.guest => ('Guest', SakinaColors.textSecondary),
      SakinaRole.user => ('User', SakinaColors.emerald),
      SakinaRole.scholar => ('Scholar', SakinaColors.gold),
      SakinaRole.admin => ('Admin', SakinaColors.navy),
    };
    return StatusBadge(label: label, color: color);
  }
}

class LuxuryDashboardCard extends StatelessWidget {
  const LuxuryDashboardCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badges = const [],
    this.onTap,
    this.gradient = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> badges;
  final VoidCallback? onTap;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: gradient ? Colors.white : SakinaColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: gradient ? Colors.white70 : SakinaColors.textSecondary,
                    ),
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: badges),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return Material(
      color: gradient ? null : SakinaColors.creamSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: gradient ? null : Border.all(color: SakinaColors.divider),
            gradient: gradient
                ? LinearGradient(
                    colors: [SakinaColors.navy, SakinaColors.emerald],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gradient) const SakinaGeometricAccent(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LuxuryDashboardCard(
      title: title,
      subtitle: subtitle,
      badges: badge != null ? [badge!] : const [],
      leading: CircleAvatar(
        backgroundColor: SakinaColors.emerald.withValues(alpha: 0.12),
        child: Icon(icon, color: SakinaColors.emerald),
      ),
      trailing: const Icon(Icons.chevron_right, color: SakinaColors.textSecondary),
      onTap: onTap,
    );
  }
}

class SafeDisclaimerBanner extends StatelessWidget {
  const SafeDisclaimerBanner({
    super.key,
    this.compact = false,
    this.message,
  });

  final bool compact;
  final String? message;

  static const String defaultMessage =
      'Sakina provides Islamic learning and guidance support. AI answers may be limited. '
      'For personal fatwa matters, consult a qualified scholar. '
      'This app is not for emergency, legal, medical, or life-threatening decisions.';

  @override
  Widget build(BuildContext context) {
    final text = message ?? defaultMessage;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: SakinaColors.goldSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SakinaColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: compact ? 18 : 22, color: SakinaColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: SakinaColors.navy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SakinaLoadingState extends StatelessWidget {
  const SakinaLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: SakinaColors.emerald),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: SakinaColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class SakinaErrorState extends StatelessWidget {
  const SakinaErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: SakinaColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

IconData iconForFeatureKey(String key) {
  return switch (key) {
    'ask_ai_shaikh' => Icons.chat_bubble_outline,
    'quran_reader' || 'quran_search' => Icons.menu_book,
    'tafsir' => Icons.auto_stories,
    'hadith' => Icons.library_books,
    'dua_library' => Icons.wb_twilight,
    'prayer_times' => Icons.access_time,
    'qibla' => Icons.explore,
    'zakat' || 'mirath' => Icons.calculate,
    'kids_learning' => Icons.child_care,
    'subscription' => Icons.workspace_premium,
    'scholar_review' => Icons.gavel,
    'bookmarks' => Icons.bookmark,
    'reminders' => Icons.notifications,
    _ => Icons.apps,
  };
}
