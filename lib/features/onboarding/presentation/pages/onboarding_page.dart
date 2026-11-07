import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../domain/entities/initial_setup_entity.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;

  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();

  int _strictnessLevel = 3;

  @override
  void initState() {
    super.initState();
    _loadExistingUserName();
  }

  void _loadExistingUserName() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final rawName =
          user?.userMetadata?['full_name'] ??
          user?.userMetadata?['name'] ??
          user?.email?.split('@').first;
      if (rawName != null && rawName.toString().trim().isNotEmpty) {
        _nameController.text = rawName.toString().trim();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

  void _formatIncomeInput(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      _incomeController.value = const TextEditingValue(text: '');
      return;
    }
    final numVal = double.tryParse(clean) ?? 0.0;
    final formatted = CurrencyFormatter.format(
      numVal,
    ).replaceAll('Rp', '').trim();
    _incomeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  InitialSetupEntity _buildEntity() {
    final income = _parse(_incomeController);
    final food = (income * 0.30).roundToDouble();
    final trans = (income * 0.10).roundToDouble();
    final bills = (income * 0.10).roundToDouble();
    final ent = (income * 0.30).roundToDouble();
    final savings = (income * 0.20).roundToDouble();
    final essential = food + trans + bills;
    final emergencyTarget = essential * 3;

    return InitialSetupEntity(
      fullName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Teman FinGuard',
      occupation: 'Profesional',
      monthlyIncome: income,
      dependentsCount: 0,
      monthlyDebtPayments: 0,
      strictnessLevel: _strictnessLevel,
      accountName: 'Dompet Utama',
      initialBalance: income,
      budgetFood: food,
      budgetTransport: trans,
      budgetBills: bills,
      budgetEntertainment: ent,
      emergencyFundTarget: emergencyTarget,
      emergencyFundCurrent: 0,
      monthlySavingsTarget: savings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingSuccess) {
          try {
            context.read<ProfileCubit>().loadProfile();
            context.read<BudgetCubit>().loadBudgets();
            context.read<TransactionCubit>().loadTransactions();
            context.read<GoalCubit>().loadGoals();
          } catch (_) {}
          context.go('/');
        } else if (state is OnboardingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.expenseRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is OnboardingSubmitting;
        final income = _parse(_incomeController);

        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return Scaffold(
          backgroundColor: AppColors.bgCanvasMain,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.25, 1.0],
                colors: [
                  AppColors.bgCanvasTop,
                  AppColors.bgCanvasMain,
                  AppColors.bgCanvasMain,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (_currentStep > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          PhosphorIconsRegular.arrowLeft,
                          size: 22,
                        ),
                        color: AppColors.textPrimary,
                        onPressed: () => setState(() => _currentStep = 0),
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontalMargin,
                        vertical: 12,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _currentStep == 0
                            ? _buildStep1Input()
                            : _buildStep2Blueprint(income),
                      ),
                    ),
                  ),
                  if (!isKeyboardOpen)
                    _buildBottomActionBar(context, isSubmitting),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- STEP 1: Kenalan Cepat & Pemasukan ---
  Widget _buildStep1Input() {
    return Column(
      key: const ValueKey('step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kenalan Cepat', style: AppTypography.pageHeader),
        const SizedBox(height: 6),
        Text(
          'Atur fondasi keuangan sehatmu dalam 30 detik tanpa istilah rumit.',
          style: AppTypography.bodyText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Field: Nama Panggilan
        _buildInputField(
          label: 'Nama Panggilan',
          hint: 'Misal: Johan',
          controller: _nameController,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 18),

        // Field: Pemasukan Bulanan
        _buildInputField(
          label: 'Pemasukan Bulanan',
          hint: '5.000.000',
          controller: _incomeController,
          keyboardType: TextInputType.number,
          prefixText: 'Rp ',
          onChanged: _formatIncomeInput,
        ),
        const SizedBox(height: 12),

        // Quick chips
        _buildQuickChips([
          'Rp 3.000.000',
          'Rp 5.000.000',
          'Rp 8.000.000',
          'Rp 12.000.000',
        ]),

        const SizedBox(height: 28),

        // Character Coach Selection
        Text('Pilih Karakter Coach AI', style: AppTypography.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'Tentukan gaya asisten saat berdiskusi dan memberi masukan keuangan:',
          style: AppTypography.captionText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        _buildPersonaOption(
          level: 2,
          imageAsset: 'assets/icons/coach_mode_supportive.png',
          title: 'Suportif',
          subtitle: 'Bahasa santai, apresiatif, dan membimbing pelan-pelan.',
        ),
        const SizedBox(height: 10),

        _buildPersonaOption(
          level: 3,
          imageAsset: 'assets/icons/coach_mode_pro.png',
          title: 'Profesional',
          subtitle: 'Lugas, objektif, dan jujur memberi rambu-rambu keuangan.',
        ),
        const SizedBox(height: 10),

        _buildPersonaOption(
          level: 5,
          imageAsset: 'assets/icons/coach_mode_roast.png',
          title: 'Mode Kritis',
          subtitle:
              'Ceplas-ceplos ala kawan dekat agar tidak kebablasan belanja.',
          isRoast: true,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.inputLabel.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
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
                  style: AppTypography.itemTitle.copyWith(
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
        ),
      ],
    );
  }

  Widget _buildQuickChips(List<String> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((val) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                final numVal = double.tryParse(clean) ?? 0.0;
                final formatted = CurrencyFormatter.format(
                  numVal,
                ).replaceAll('Rp', '').trim();
                setState(() {
                  _incomeController.text = formatted;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  val,
                  style: AppTypography.captionText.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPersonaOption({
    required int level,
    required String imageAsset,
    required String title,
    required String subtitle,
    bool isRoast = false,
  }) {
    final isSelected = _strictnessLevel == level;

    return GestureDetector(
      onTap: () {
        setState(() => _strictnessLevel = level);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
          borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(3),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: AppTypography.itemTitle.copyWith(
                          color: isSelected
                              ? (isRoast
                                    ? AppColors.roastRed
                                    : AppColors.primaryDark)
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                          color: isRoast
                              ? AppColors.roastRed
                              : AppColors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: Magic Financial Blueprint ---
  Widget _buildStep2Blueprint(double income) {
    final food = (income * 0.30).roundToDouble();
    final trans = (income * 0.10).roundToDouble();
    final bills = (income * 0.10).roundToDouble();
    final ent = (income * 0.30).roundToDouble();
    final savings = (income * 0.20).roundToDouble();
    final essential = food + trans + bills;
    final emergencyTarget = essential * 3;

    return Column(
      key: const ValueKey('step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 140,
            height: 90,
            child: Lottie.asset(
              'assets/animations/scr02_smart_blueprint_success.json',
              repeat: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Peta Alokasi Keuangan', style: AppTypography.pageHeader),
        const SizedBox(height: 6),
        Text(
          'Dihitung otomatis dari pemasukan ${CurrencyFormatter.format(income)} dengan formula 50/30/20:',
          style: AppTypography.bodyText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // 1. Kebutuhan Pokok Card (50%)
        _buildAllocationCard(
          icon: PhosphorIcons.shieldCheck(),
          title: 'Kebutuhan Pokok',
          subtitle: 'Porsi 50% dari pemasukan',
          amount: essential,
          tagColor: AppColors.incomeGreen,
          tagBg: AppColors.incomeGreenBg,
          items: [
            _AllocationItem(
              label: 'Makan & Minum',
              amount: food,
              icon: PhosphorIcons.forkKnife(),
              badge: '30%',
            ),
            _AllocationItem(
              label: 'Transportasi',
              amount: trans,
              icon: PhosphorIcons.car(),
              badge: '10%',
            ),
            _AllocationItem(
              label: 'Tagihan & Utilitas',
              amount: bills,
              icon: PhosphorIcons.receipt(),
              badge: '10%',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Gaya Hidup & Hiburan (30%)
        _buildAllocationCard(
          icon: PhosphorIcons.coffee(),
          title: 'Gaya Hidup',
          subtitle: 'Porsi 30% dari pemasukan',
          amount: ent,
          tagColor: AppColors.warningOrange,
          tagBg: AppColors.warningOrangeBg,
          items: [
            _AllocationItem(
              label: 'Jajan & Hiburan',
              amount: ent,
              icon: PhosphorIcons.coffee(),
              badge: '30%',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Tabungan & Dana Darurat (20%)
        _buildAllocationCard(
          icon: PhosphorIcons.piggyBank(),
          title: 'Tabungan & Darurat',
          subtitle: 'Porsi 20% dari pemasukan',
          amount: savings,
          tagColor: AppColors.primary,
          tagBg: AppColors.primaryLight,
          items: [
            _AllocationItem(
              label: 'Tabungan Rutin',
              amount: savings,
              icon: PhosphorIcons.piggyBank(),
              badge: '20%',
            ),
            _AllocationItem(
              label: 'Target Dana Darurat',
              amount: emergencyTarget,
              icon: PhosphorIcons.shieldCheck(),
              badge: '3 Bulan',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Subtle reassurance card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.info(), color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Santai cok, takaran 50/30/20 ini patokan awal biar dompet lu kaga jebol. Nanti bisa lu ubah sesuka jidat di menu Budget!',
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.primaryDark,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAllocationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double amount,
    required Color tagColor,
    required Color tagBg,
    required List<_AllocationItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: AppColors.primary, size: 18),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.captionText.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  CurrencyFormatter.format(amount),
                  style: AppTypography.captionText.copyWith(
                    color: tagColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.label,
                            style: AppTypography.captionText.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(item.amount),
                    style: AppTypography.captionText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, bool isSubmitting) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AppButton(
        label: _currentStep == 0
            ? 'Lihat Peta Keuangan'
            : (isSubmitting
                  ? 'Menerapkan Peta Keuangan...'
                  : 'Terapkan Peta Keuangan'),
        isLoading: isSubmitting,
        onPressed: isSubmitting
            ? null
            : () {
                if (_currentStep == 0) {
                  if (_parse(_incomeController) <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Isi dulu pemasukan lu, tolol! Masa 0 rupiah, hidup pake angin?!',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.expenseRed,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _currentStep = 1);
                } else {
                  context.read<OnboardingCubit>().submitInitialSetup(
                    _buildEntity(),
                  );
                }
              },
      ),
    );
  }
}

class _AllocationItem {
  final String label;
  final double amount;
  final IconData icon;
  final String? badge;

  const _AllocationItem({
    required this.label,
    required this.amount,
    required this.icon,
    this.badge,
  });
}
