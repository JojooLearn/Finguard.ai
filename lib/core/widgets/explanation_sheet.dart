import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';

/// Clean, friendly educational bottom sheet explaining financial formulas
/// and data origins in plain Indonesian for everyday users ("orang awam").
class ExplanationSheet extends StatelessWidget {
  final String title;
  final String explanation;
  final String? metricValue;
  final String? formula;
  final String? tip;
  final IconData? icon;

  const ExplanationSheet({
    super.key,
    required this.title,
    required this.explanation,
    this.metricValue,
    this.formula,
    this.tip,
    this.icon,
  });

  /// Displays the explanation bottom sheet cleanly.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String explanation,
    String? metricValue,
    String? formula,
    String? tip,
    IconData? icon,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExplanationSheet(
        title: title,
        explanation: explanation,
        metricValue: metricValue,
        formula: formula,
        tip: tip,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header: Icon badge + Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    icon ?? PhosphorIcons.lightbulb(PhosphorIconsStyle.fill),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asal-Usul Angka',
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Optional Metric Display Card
          if (metricValue != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nilai Saat Ini',
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    metricValue!,
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Formula box (if provided)
          if (formula != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.calculator(PhosphorIconsStyle.bold),
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formula!,
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Explanation body
          Text(
            explanation,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),

          // Tip box (if provided)
          if (tip != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.incomeGreenBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.incomeGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip!,
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.incomeGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Action button
          AppButton(
            label: 'Paham, Terima Kasih',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

