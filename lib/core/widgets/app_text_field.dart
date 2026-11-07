import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? helperText;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.sectionLabel.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceFieldFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodySecondary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText!,
              style: AppTypography.caption,
            ),
          ),
        ],
      ],
    );
  }
}
