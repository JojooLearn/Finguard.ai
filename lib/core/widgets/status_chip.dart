import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum StatusType { aman, perhatian, hampirHabis, melebihi, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? customIcon;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusType.neutral,
    this.customIcon,
  });

  factory StatusChip.aman([String label = 'Aman']) =>
      StatusChip(label: label, type: StatusType.aman);

  factory StatusChip.perhatian([String label = 'Perhatian']) =>
      StatusChip(label: label, type: StatusType.perhatian);

  factory StatusChip.hampirHabis([String label = 'Hampir habis']) =>
      StatusChip(label: label, type: StatusType.hampirHabis);

  factory StatusChip.melebihi([String label = 'Melebihi']) =>
      StatusChip(label: label, type: StatusType.melebihi);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (type) {
      case StatusType.aman:
        bg = AppColors.successTint;
        fg = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case StatusType.perhatian:
        bg = AppColors.warningTint;
        fg = AppColors.warning;
        icon = Icons.info_outline_rounded;
        break;
      case StatusType.hampirHabis:
        bg = AppColors.warningTint;
        fg = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case StatusType.melebihi:
        bg = AppColors.dangerTint;
        fg = AppColors.danger;
        icon = Icons.cancel_outlined;
        break;
      case StatusType.neutral:
        bg = Colors.black.withValues(alpha: 0.08);
        fg = AppColors.textPrimary;
        icon = customIcon ?? Icons.circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(customIcon ?? icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
