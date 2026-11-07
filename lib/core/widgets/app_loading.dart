import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class AppSkeletonCard extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const AppSkeletonCard({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppSpacing.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceCardMuted,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.sideMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonCard(width: 140, height: 32, borderRadius: 100),
          SizedBox(height: 16),
          AppSkeletonCard(width: 220, height: 48, borderRadius: 16),
          SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: [
              Expanded(child: AppSkeletonCard(height: 180)),
              SizedBox(width: AppSpacing.cardGap),
              Expanded(child: AppSkeletonCard(height: 180)),
            ],
          ),
          SizedBox(height: AppSpacing.cardGap),
          Row(
            children: [
              Expanded(child: AppSkeletonCard(height: 180)),
              SizedBox(width: AppSpacing.cardGap),
              Expanded(child: AppSkeletonCard(height: 180)),
            ],
          ),
          SizedBox(height: AppSpacing.sectionGap),
          AppSkeletonCard(height: 72),
          SizedBox(height: 12),
          AppSkeletonCard(height: 72),
        ],
      ),
    );
  }
}
