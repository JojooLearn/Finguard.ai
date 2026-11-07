import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  final _debtController = TextEditingController();

  int _strictnessLevel = 3;
  bool _initialized = false;
  String _userEmail = '';

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  void _initFields(ProfileState state) {
    if (_initialized) return;
    if (state is ProfileLoaded) {
      final p = state.profile;
      _nameController.text = p.displayName;
      _userEmail = p.email;
      _strictnessLevel = p.strictnessLevel;

      final incomeFormatted = CurrencyFormatter.format(
        p.monthlyIncome,
      ).replaceAll('Rp', '').trim();
      _incomeController.text = p.monthlyIncome > 0 ? incomeFormatted : '';

      final debtFormatted = CurrencyFormatter.format(
        p.monthlyDebt,
      ).replaceAll('Rp', '').trim();
      _debtController.text = p.monthlyDebt > 0 ? debtFormatted : '';

      _initialized = true;
    }
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

  void _formatCurrencyInput(TextEditingController controller, String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      controller.value = const TextEditingValue(text: '');
      return;
    }
    final numVal = double.tryParse(clean) ?? 0.0;
    final formatted = CurrencyFormatter.format(
      numVal,
    ).replaceAll('Rp', '').trim();
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.expenseRed,
            ),
          );
        }
      },
      builder: (context, state) {
        _initFields(state);
        final isUpdating = state is ProfileUpdating || state is ProfileLoading;

        return Scaffold(
          backgroundColor: AppColors.bgCanvasMain,
          appBar: AppBar(
            backgroundColor: AppColors.bgCanvasMain,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                PhosphorIcons.arrowLeft(),
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Edit Profil', style: AppTypography.pageHeader),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppSpacing.screenHorizontalMargin,
              right: AppSpacing.screenHorizontalMargin,
              top: 12,
              bottom: 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identitas Akun
                _buildSectionHeader('Identitas Akun'),
                const SizedBox(height: 10),
                _buildCardContainer([
                  _buildFieldLabel('Nama Panggilan'),
                  const SizedBox(height: 8),
                  _buildBorderlessField(
                    controller: _nameController,
                    hint: 'Johan',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('Email Terdaftar'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFieldFill.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusInnerElement,
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.lockSimple(),
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _userEmail.isNotEmpty
                                ? _userEmail
                                : 'user@finguard.id',
                            style: AppTypography.bodyText.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // Kondisi Finansial
                _buildSectionHeader('Kondisi Finansial'),
                const SizedBox(height: 10),
                _buildCardContainer([
                  _buildFieldLabel('Pemasukan Bulanan Rutin'),
                  const SizedBox(height: 8),
                  _buildBorderlessField(
                    controller: _incomeController,
                    hint: '5.000.000',
                    prefixText: 'Rp ',
                    keyboardType: TextInputType.number,
                    onChanged: (val) =>
                        _formatCurrencyInput(_incomeController, val),
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('Total Cicilan / Utang Bulanan (Jika ada)'),
                  const SizedBox(height: 8),
                  _buildBorderlessField(
                    controller: _debtController,
                    hint: '0',
                    prefixText: 'Rp ',
                    keyboardType: TextInputType.number,
                    onChanged: (val) =>
                        _formatCurrencyInput(_debtController, val),
                  ),
                ]),

                const SizedBox(height: 24),

                // Karakter Coach AI
                _buildSectionHeader('Karakter Coach AI'),
                const SizedBox(height: 4),
                Text(
                  'Tentukan gaya ketegasan dan respons asisten saat diajak konsultasi:',
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPersonaSelection(),

                const SizedBox(height: 32),

                // Save CTA
                AppButton(
                  label: isUpdating ? 'Menyimpan...' : 'Simpan Perubahan',
                  isLoading: isUpdating,
                  onPressed: isUpdating
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          final income = _parse(_incomeController);
                          final debt = _parse(_debtController);

                          final success = await context
                              .read<ProfileCubit>()
                              .updateProfile(
                                displayName: name.isNotEmpty ? name : null,
                                monthlyIncome: income,
                                monthlyDebt: debt,
                                strictnessLevel: _strictnessLevel,
                              );

                          if (success && context.mounted) {
                            context.read<TransactionCubit>().loadTransactions();
                            context.read<BudgetCubit>().loadBudgets();
                            context.read<GoalCubit>().loadGoals();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Beres! Profil kamu berhasil diperbarui.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.incomeGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.sectionTitle.copyWith(fontSize: 16),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.inputLabel.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildBorderlessField({
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFieldFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (prefixText != null) ...[
            Text(
              prefixText,
              style: AppTypography.itemTitle.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: AppTypography.bodyText.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.bodyText.copyWith(
                  color: AppColors.textPlaceholder,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaSelection() {
    return Column(
      children: [
        _buildPersonaItem(
          level: 2,
          imageAsset: 'assets/icons/coach_mode_supportive.png',
          title: 'Suportif',
          subtitle: 'Gaya santai, penuh apresiasi, dan membimbing pelan-pelan.',
        ),
        const SizedBox(height: 8),
        _buildPersonaItem(
          level: 3,
          imageAsset: 'assets/icons/coach_mode_pro.png',
          title: 'Profesional',
          subtitle: 'Lugas, objektif, dan jujur memberi rambu-rambu keuangan.',
        ),
        const SizedBox(height: 8),
        _buildPersonaItem(
          level: 5,
          imageAsset: 'assets/icons/coach_mode_roast.png',
          title: 'Mode Kritis',
          subtitle:
              'Ceplas-ceplos ala teman tongkrongan agar tidak kebablasan belanja.',
          isRoast: true,
        ),
      ],
    );
  }

  Widget _buildPersonaItem({
    required int level,
    required String imageAsset,
    required String title,
    required String subtitle,
    bool isRoast = false,
  }) {
    final isSelected = _strictnessLevel == level;

    return GestureDetector(
      onTap: () => setState(() => _strictnessLevel = level),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isRoast ? AppColors.expenseRedBg : AppColors.primaryLight)
              : AppColors.surfaceCard,
          border: Border.all(
            color: isSelected
                ? (isRoast ? AppColors.roastRed : AppColors.primary)
                : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isRoast
                        ? AppColors.roastRed.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15))
                    : AppColors.surfaceFieldFill,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14,
                      color: isSelected
                          ? (isRoast
                                ? AppColors.roastRed
                                : AppColors.primaryDark)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: isRoast ? AppColors.roastRed : AppColors.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
