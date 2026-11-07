import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorView({
    super.key,
    this.message = 'Gagal memuat',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sideMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                boxShadow: AppSpacing.softShadow,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.sectionLabel.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Coba lagi',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
