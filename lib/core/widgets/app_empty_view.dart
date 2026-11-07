import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';

class AppEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onButtonPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onButtonPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sideMargin),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgGradientTop.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.sectionLabel.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: buttonLabel,
                    onPressed: onButtonPressed,
                  ),
                ),
                if (secondaryButtonLabel != null && onSecondaryPressed != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: secondaryButtonLabel!,
                      variant: AppButtonVariant.secondary,
                      onPressed: onSecondaryPressed,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
