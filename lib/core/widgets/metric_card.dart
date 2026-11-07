import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'explanation_sheet.dart';

enum MetricCardTheme { lime, dark, purple, surface }

class MetricCard extends StatelessWidget {
  final MetricCardTheme cardTheme;
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Widget? statusChip;
  final double? progress;
  final Color? progressColor;
  final Widget? chartWidget;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? infoExplanation;
  final String? infoFormula;
  final String? infoTip;
  final bool showInfoIcon;

  const MetricCard({
    super.key,
    required this.cardTheme,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.statusChip,
    this.progress,
    this.progressColor,
    this.chartWidget,
    this.onTap,
    this.onLongPress,
    this.infoExplanation,
    this.infoFormula,
    this.infoTip,
    this.showInfoIcon = true,
  });

  void _showExplanation(BuildContext context) {
    if (infoExplanation != null) {
      ExplanationSheet.show(
        context,
        title: label,
        metricValue: value,
        explanation: infoExplanation!,
        formula: infoFormula,
        tip: infoTip,
        icon: icon,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLime = cardTheme == MetricCardTheme.lime;
    final isDark = cardTheme == MetricCardTheme.dark;

    final gradient = isLime
        ? AppColors.limeCardGradient
        : (isDark ? AppColors.darkCardGradient : null);

    final fgColor = isLime ? AppColors.primaryDark : AppColors.textLight;
    final fgMutedColor = isLime
        ? AppColors.primaryDark.withValues(alpha: 0.72)
        : AppColors.textLight.withValues(alpha: 0.72);

    final iconTileBg = isLime
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.16);

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top Row: 32px icon tile + optional info icon + status/context badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconTileBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: fgColor, size: 17),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (infoExplanation != null && showInfoIcon) ...[
                  GestureDetector(
                    onTap: () => _showExplanation(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: iconTileBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIcons.info(PhosphorIconsStyle.bold),
                          size: 11,
                          color: fgColor,
                        ),
                      ),
                    ),
                  ),
                  if (statusChip != null) const SizedBox(width: 4),
                ],
                if (statusChip != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: statusChip!,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Optional Center Chart if specifically provided
        if (chartWidget != null)
          Center(child: chartWidget!)
        else
          const SizedBox(height: 2),

        // Bottom Content: Label, Value, Progress Bar, Caption
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fgMutedColor,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.cardValue.copyWith(
                  color: fgColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: isLime
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.20),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? (isLime ? AppColors.primaryDark : AppColors.primaryLime),
                  ),
                ),
              ),
            ],
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!,
                style: AppTypography.smallCaption.copyWith(
                  color: fgMutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ],
    );

    final hasAction = onTap != null || onLongPress != null || infoExplanation != null;

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surfaceCard : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          children: [
            // Soft subtle decorative shapes
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLime
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -35,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLime
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Card Content
            if (hasAction)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap ?? (infoExplanation != null ? () => _showExplanation(context) : null),
                  onLongPress: onLongPress ?? (infoExplanation != null ? () => _showExplanation(context) : null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: cardContent,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: cardContent,
              ),
          ],
        ),
      ),
    );
  }
}
