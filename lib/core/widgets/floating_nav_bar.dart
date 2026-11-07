import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 68.0,
        margin: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.textPrimary, // #111827 dark capsule
          borderRadius: BorderRadius.circular(34.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 0. Home
            _buildNavItem(
              index: 0,
              iconRegular: PhosphorIcons.house(),
              iconFill: PhosphorIcons.house(PhosphorIconsStyle.fill),
              label: 'Home',
            ),

            // 1. Transactions
            _buildNavItem(
              index: 1,
              iconRegular: PhosphorIcons.receipt(),
              iconFill: PhosphorIcons.receipt(PhosphorIconsStyle.fill),
              label: 'Transaksi',
            ),

            // 2. Central AI Coach Button (finguard_desig.md 6.2)
            _buildCenterCoachButton(),

            // 3. Budget
            _buildNavItem(
              index: 3,
              iconRegular: PhosphorIcons.chartPie(),
              iconFill: PhosphorIcons.chartPie(PhosphorIconsStyle.fill),
              label: 'Budget',
            ),

            // 4. Profile
            _buildNavItem(
              index: 4,
              iconRegular: PhosphorIcons.user(),
              iconFill: PhosphorIcons.user(PhosphorIconsStyle.fill),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData iconRegular,
    required IconData iconFill,
    required String label,
  }) {
    final isActive = currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? iconFill : iconRegular,
                color: isActive ? AppColors.surface : AppColors.textDisabled,
                size: 22,
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.surface : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCoachButton() {
    final isActive = currentIndex == 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(2),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.aiAccentGradient,
          shape: BoxShape.circle,
          boxShadow: AppSpacing.glowShadow,
        ),
        child: Center(
          child: Icon(
            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
            color: Colors.white,
            size: isActive ? 26 : 24,
          ),
        ),
      ),
    );
  }
}
