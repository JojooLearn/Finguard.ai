import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == AppButtonVariant.primary;
    final bgColor = isPrimary ? AppColors.primaryDark : AppColors.surfaceCard;
    final fgColor = isPrimary ? AppColors.surfaceCard : AppColors.primaryDark;

    return SizedBox(
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: isPrimary ? 0 : 2,
          shadowColor: const Color(0x10000000),
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionLabel.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool showBadgeDot;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.showBadgeDot = false,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.iconButtonSize,
      height: AppSpacing.iconButtonSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceCard,
        shape: BoxShape.circle,
        boxShadow: AppSpacing.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.iconButtonSize / 2),
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: iconColor ?? AppColors.primaryDark,
                size: 20,
              ),
              if (showBadgeDot)
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
