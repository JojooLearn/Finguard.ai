import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../budgets/presentation/cubit/budget_state.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class BlueprintPage extends StatefulWidget {
  const BlueprintPage({super.key});

  @override
  State<BlueprintPage> createState() => _BlueprintPageState();
}

class _BlueprintPageState extends State<BlueprintPage> {
  final _incomeController = TextEditingController();
  bool _initialized = false;
  double _currentIncome = 5000000.0;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  void _initIncome(ProfileState state) {
    if (_initialized) return;
    if (state is ProfileLoaded) {
      _currentIncome = state.profile.monthlyIncome > 0
          ? state.profile.monthlyIncome
          : 5000000.0;
      final formatted = CurrencyFormatter.format(
        _currentIncome,
      ).replaceAll('Rp', '').trim();
      _incomeController.text = formatted;
      _initialized = true;
    }
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

  void _formatIncomeInput(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      _incomeController.value = const TextEditingValue(text: '');
      setState(() => _currentIncome = 0);
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
    setState(() => _currentIncome = numVal);
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
        _initIncome(state);
        final isUpdating = state is ProfileUpdating || state is ProfileLoading;
        final income = _currentIncome > 0
            ? _currentIncome
            : _parse(_incomeController);

        final food = (income * 0.30).roundToDouble();
        final trans = (income * 0.10).roundToDouble();
        final bills = (income * 0.10).roundToDouble();
        final ent = (income * 0.30).roundToDouble();
        final savings = (income * 0.20).roundToDouble();
        final essential = food + trans + bills;
        final emergencyTarget = essential * 3;

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
            title: Text(
              'Atur Peta Keuangan',
              style: AppTypography.pageHeader,
            ),
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
                Text(
                  'Perbarui alokasi anggaran dan target tabungan secara proporsional sesuai pemasukan bulanan terbarumu.',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 130,
                    height: 80,
                    child: Lottie.asset(
                      'assets/animations/scr02_smart_blueprint_success.json',
                      repeat: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Income Input Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusBentoAndItem,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemasukan Bulanan Sebagai Acuan',
                        style: AppTypography.inputLabel.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusInnerElement,
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              'Rp ',
                              style: AppTypography.itemTitle.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _incomeController,
                                keyboardType: TextInputType.number,
                                onChanged: _formatIncomeInput,
                                style: AppTypography.itemTitle.copyWith(
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '5.000.000',
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
                  ),
                ),

                const SizedBox(height: 20),

                // Two-Way Sync Status with Custom Category Budgets
                BlocBuilder<BudgetCubit, BudgetState>(
                  builder: (context, budgetState) {
                    if (budgetState is! BudgetLoaded ||
                        budgetState.budgets.isEmpty ||
                        income <= 0) {
                      return const SizedBox.shrink();
                    }
                    final activeTotalLimit = budgetState.budgets.fold<double>(
                      0,
                      (sum, b) => sum + b.limitAmount,
                    );
                    final idealSpendingLimit = food + trans + bills + ent;
                    final diff = (activeTotalLimit - idealSpendingLimit).abs();
                    final isSynced = diff < 1000;
                    final isOverIncome = activeTotalLimit > income;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSynced
                            ? AppColors.incomeGreenBg
                            : (isOverIncome
                                ? AppColors.expenseRedBg
                                : AppColors.warningOrangeBg),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusBentoAndItem,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isSynced
                                ? PhosphorIcons.checkCircle(
                                    PhosphorIconsStyle.fill,
                                  )
                                : PhosphorIcons.slidersHorizontal(),
                            size: 19,
                            color: isSynced
                                ? AppColors.incomeGreen
                                : (isOverIncome
                                    ? AppColors.expenseRed
                                    : AppColors.warningOrange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSynced
                                      ? 'Selaras dengan Atur Jatah Belanja (80% Gaji)'
                                      : 'Jatah Belanja Kustom Aktif: ${CurrencyFormatter.format(activeTotalLimit)}',
                                  style: AppTypography.itemTitle.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSynced
                                        ? AppColors.incomeGreen
                                        : (isOverIncome
                                            ? AppColors.expenseRed
                                            : const Color(0xFFB45309)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSynced
                                      ? 'Total pos jatah belanjamu saat ini (${CurrencyFormatter.format(activeTotalLimit)}) sudah pas mengikuti rumus ideal 50/30/20.'
                                      : 'Kamu telah memodifikasi pos kategori menjadi ${CurrencyFormatter.format(activeTotalLimit)} (standar 80% gaji: ${CurrencyFormatter.format(idealSpendingLimit)}). Tekan tombol di bawah jika ingin me-reset pos belanja kembali ke standar 50/30/20.',
                                  style: AppTypography.captionText.copyWith(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 50/30/20 Breakdown Cards
                Text(
                  'Pratinjau Hasil Perhitungan',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 12),

                // 1. Kebutuhan Pokok (50%)
                _buildAllocationCard(
                  icon: PhosphorIcons.shieldCheck(),
                  title: 'Kebutuhan Pokok',
                  subtitle: 'Porsi 50% dari pemasukan',
                  total: essential,
                  color: AppColors.incomeGreen,
                  bgColor: AppColors.incomeGreenBg,
                  onInfoTap: () {
                    ExplanationSheet.show(
                      context,
                      title: 'Alokasi Kebutuhan Pokok (50%)',
                      metricValue: CurrencyFormatter.format(essential),
                      formula:
                          '50% x ${CurrencyFormatter.format(_currentIncome)} = ${CurrencyFormatter.format(essential)}',
                      explanation:
                          'Alokasi 50% dari penghasilan bulananmu (${CurrencyFormatter.format(_currentIncome)}) disiapkan untuk kebutuhan pokok hidup sehari-hari:\n• Makan & Minum: ${CurrencyFormatter.format(food)} (30%)\n• Transportasi: ${CurrencyFormatter.format(trans)} (10%)\n• Tagihan & Utilitas: ${CurrencyFormatter.format(bills)} (10%)',
                      tip:
                          'Kebutuhan pokok adalah pengeluaran wajib yang tidak bisa dihindari untuk bertahan hidup dan bekerja.',
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                    );
                  },
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

                // 2. Gaya Hidup (30%)
                _buildAllocationCard(
                  icon: PhosphorIcons.coffee(),
                  title: 'Gaya Hidup',
                  subtitle: 'Porsi 30% dari pemasukan',
                  total: ent,
                  color: AppColors.warningOrange,
                  bgColor: AppColors.warningOrangeBg,
                  onInfoTap: () {
                    ExplanationSheet.show(
                      context,
                      title: 'Alokasi Gaya Hidup (30%)',
                      metricValue: CurrencyFormatter.format(ent),
                      formula:
                          '30% x ${CurrencyFormatter.format(_currentIncome)} = ${CurrencyFormatter.format(ent)}',
                      explanation:
                          'Alokasi 30% dari penghasilan bulananmu (${CurrencyFormatter.format(_currentIncome)}) disiapkan untuk kenyamanan dan hiburan:\n• Jajan & Hiburan: ${CurrencyFormatter.format(ent)} (30%)\n\nPos ini boleh kamu belanjakan tanpa rasa bersalah selama tetap dalam batas jatah.',
                      tip:
                          'Jika di akhir bulan keuangan menipis, pos gaya hidup adalah yang pertama harus ditahan.',
                      icon: PhosphorIcons.coffee(PhosphorIconsStyle.fill),
                    );
                  },
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

                // 3. Tabungan (20%)
                _buildAllocationCard(
                  icon: PhosphorIcons.piggyBank(),
                  title: 'Tabungan & Darurat',
                  subtitle: 'Porsi 20% dari pemasukan',
                  total: savings,
                  color: AppColors.primary,
                  bgColor: AppColors.primaryLight,
                  onInfoTap: () {
                    ExplanationSheet.show(
                      context,
                      title: 'Alokasi Tabungan & Darurat (20%)',
                      metricValue: CurrencyFormatter.format(savings),
                      formula:
                          '20% x ${CurrencyFormatter.format(_currentIncome)} = ${CurrencyFormatter.format(savings)}',
                      explanation:
                          'Alokasi 20% dari penghasilan bulananmu (${CurrencyFormatter.format(_currentIncome)}) otomatis dialokasikan untuk masa depan:\n• Tabungan Rutin: ${CurrencyFormatter.format(savings)} per bulan\n• Target Dana Darurat (3x Kebutuhan Pokok): 3 x ${CurrencyFormatter.format(essential)} = ${CurrencyFormatter.format(emergencyTarget)}.',
                      tip:
                          'Prioritaskan mengamankan dana darurat sebelum mulai berinvestasi pada instrumen fluktuatif.',
                      icon: PhosphorIcons.piggyBank(PhosphorIconsStyle.fill),
                    );
                  },
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
                      highlight: false,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Apply CTA
                AppButton(
                  label: isUpdating
                      ? 'Menerapkan Alokasi...'
                      : 'Terapkan ke Budget & Target',
                  isLoading: isUpdating,
                  onPressed: isUpdating || income <= 0
                      ? null
                      : () async {
                          final success = await context
                              .read<ProfileCubit>()
                              .recalculateBlueprint(monthlyIncome: income);

                          if (success && context.mounted) {
                            // Reload budgets, transactions, and goals so Home and all pages reflect changes
                            context.read<BudgetCubit>().loadBudgets();
                            context.read<TransactionCubit>().loadTransactions();
                            context.read<GoalCubit>().loadGoals();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Mantap! Alokasi 50/30/20 dan pemasukan berhasil diperbarui.',
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

  Widget _buildAllocationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double total,
    required Color color,
    required Color bgColor,
    required List<_AllocationItem> items,
    VoidCallback? onInfoTap,
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
                child: GestureDetector(
                  onTap: onInfoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.itemTitle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onInfoTap != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              PhosphorIcons.info(PhosphorIconsStyle.bold),
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ],
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
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  CurrencyFormatter.format(total),
                  style: AppTypography.captionText.copyWith(
                    color: color,
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
                color: item.highlight
                    ? AppColors.primaryLight
                    : AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 15,
                    color: item.highlight
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
                              color: item.highlight
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                              fontWeight: item.highlight
                                  ? FontWeight.w700
                                  : FontWeight.w600,
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
                              color: item.highlight
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: item.highlight
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
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
                      color: item.highlight
                          ? AppColors.primary
                          : AppColors.textPrimary,
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
}

class _AllocationItem {
  final String label;
  final double amount;
  final IconData icon;
  final String? badge;
  final bool highlight;

  const _AllocationItem({
    required this.label,
    required this.amount,
    required this.icon,
    this.badge,
    this.highlight = false,
  });
}
