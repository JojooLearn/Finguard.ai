import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/repositories/category_and_account_repository.dart';
import '../../../../app/di/injection.dart';
import '../cubit/budget_cubit.dart';
import '../cubit/budget_state.dart';
import '../../domain/entities/budget_entity.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBudgetsForCurrentMonth();
  }

  void _loadBudgetsForCurrentMonth() {
    final start = DateTime(_currentDate.year, _currentDate.month, 1);
    final end = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    context.read<BudgetCubit>().loadBudgets(start: start, end: end);
  }

  StatusChip _buildStatusChip(double ratio) {
    if (ratio <= 0.0) {
      return StatusChip.aman('Aman');
    } else if (ratio >= 1.0) {
      return StatusChip.melebihi('Jebol / Melebihi');
    } else if (ratio >= 0.85) {
      return StatusChip.hampirHabis('Tinggal dikit');
    } else if (ratio >= 0.70) {
      return StatusChip.perhatian('Mulai menipis');
    } else {
      return StatusChip.aman('Aman');
    }
  }

  IconData _iconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('makan')) return PhosphorIcons.forkKnife();
    if (lower.contains('trans')) return PhosphorIcons.car();
    if (lower.contains('hibur')) return PhosphorIcons.gameController();
    if (lower.contains('belanja')) return PhosphorIcons.shoppingCart();
    if (lower.contains('tagihan') || lower.contains('listrik')) return PhosphorIcons.receipt();
    if (lower.contains('sehat')) return PhosphorIcons.firstAid();
    if (lower.contains('kopi') || lower.contains('cafe')) return PhosphorIcons.coffee();
    return PhosphorIcons.chartPie();
  }

  void _showEditBudgetDialog(
    BuildContext context, {
    required String categoryId,
    required String categoryName,
    required double currentLimit,
    required double spentAmount,
  }) {
    final limitCtrl = TextEditingController(
      text: CurrencyFormatter.format(currentLimit).replaceAll('Rp', '').trim(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _iconForCategory(categoryName),
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atur Batas Belanja: $categoryName',
                            style: AppTypography.itemTitle.copyWith(fontSize: 16),
                          ),
                          Text(
                            'Terpakai bulan ini: ${CurrencyFormatter.format(spentAmount)}',
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Batas Nominal Anggaran Bulanan',
                  style: AppTypography.inputLabel.copyWith(
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
                      Text(
                        'Rp ',
                        style: AppTypography.itemTitle.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: limitCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          style: AppTypography.itemTitle.copyWith(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Simpan Batas Belanja',
                  onPressed: () {
                    final raw = limitCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')
                        .trim();
                    final limit = double.tryParse(raw);
                    if (limit == null || limit <= 0) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Nominal batas belanja harus lebih dari Rp0.',
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

                    final start = DateTime(_currentDate.year, _currentDate.month, 1);
                    final end = DateTime(_currentDate.year, _currentDate.month + 1, 0);

                    this.context.read<BudgetCubit>().setBudget(
                          categoryId: categoryId,
                          categoryName: categoryName,
                          limitAmount: limit,
                          start: start,
                          end: end,
                        );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'Beres! Jatah $categoryName udah di-update.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppColors.incomeGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCategoryBudgetSheet(BuildContext context) async {
    final catRepo = sl<CategoryRepository>();
    final catRes = await catRepo.getCategories();
    final allCats = catRes.fold((c) => c, (_) => <CategoryEntity>[]);
    final expenseMap = <String, CategoryEntity>{};
    for (final c in allCats.where((c) => c.transactionType == TransactionType.expense)) {
      expenseMap.putIfAbsent(c.name.trim().toLowerCase(), () => c);
    }
    final expenseCats = expenseMap.values.toList();

    if (!mounted || !context.mounted) return;

    if (expenseCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memuat daftar kategori...')),
      );
      return;
    }

    String selectedCatId = expenseCats.first.id;
    String selectedCatName = expenseCats.first.name;
    final limitCtrl = TextEditingController();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                Text(
                  'Tambah Jatah Anggaran',
                  style: AppTypography.itemTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pilih Kategori',
                  style: AppTypography.inputLabel.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenseCats.map((cat) {
                    final isSel = selectedCatId == cat.id;
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        selectedCatId = cat.id;
                        selectedCatName = cat.name;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(
                          cat.name,
                          style: AppTypography.captionText.copyWith(
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'Batas Nominal Bulanan',
                  style: AppTypography.inputLabel.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
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
                          controller: limitCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          style: AppTypography.bodyText.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                AppButton(
                  label: 'Simpan Batas Belanja',
                  onPressed: () {
                    final raw = limitCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
                    final limit = double.tryParse(raw);
                    if (limit == null || limit <= 0) {
                      ScaffoldMessenger.of(this.context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Nominal batas belanja harus lebih dari Rp0.'),
                          ),
                        );
                      return;
                    }

                    final start = DateTime(_currentDate.year, _currentDate.month, 1);
                    final end = DateTime(_currentDate.year, _currentDate.month + 1, 0);

                    this.context.read<BudgetCubit>().setBudget(
                          categoryId: selectedCatId,
                          categoryName: selectedCatName,
                          limitAmount: limit,
                          start: start,
                          end: end,
                        );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'Mantap! Pos jatah $selectedCatName aktif.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppColors.incomeGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BudgetCubit, BudgetState>(
      builder: (context, budgetState) {
        final List<BudgetEntity> rawBudgets =
            budgetState is BudgetLoaded ? budgetState.budgets : [];

        // Safeguard UI deduplication by canonical category name
        final Map<String, BudgetEntity> uniqueBudgetsMap = {};
        for (final b in rawBudgets) {
          final lower = (b.categoryName ?? '').trim().toLowerCase();
          final normKey = (lower == 'gaya hidup & hiburan' || lower == 'hiburan')
              ? 'hiburan'
              : lower;
          if (!uniqueBudgetsMap.containsKey(normKey) ||
              b.spentAmount > uniqueBudgetsMap[normKey]!.spentAmount) {
            uniqueBudgetsMap[normKey] = b;
          }
        }
        final List<BudgetEntity> budgets = uniqueBudgetsMap.values.toList();

        final totalSpent = budgets.fold<double>(0, (sum, b) => sum + b.spentAmount);
        final totalLimit = budgets.fold<double>(0, (sum, b) => sum + b.limitAmount);
        final remainingBudget = totalLimit - totalSpent;
        final overallRatio = totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;
        final isOverbudget = remainingBudget < 0;
        final int remainingPercent = totalLimit > 0
            ? (isOverbudget
                ? 0
                : (((totalLimit - totalSpent) / totalLimit) * 100)
                    .round()
                    .clamp(0, 100))
            : 100;
        final double spentProgress = isOverbudget
            ? 1.0
            : (totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => _loadBudgetsForCurrentMonth(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(
              left: AppSpacing.screenHorizontalMargin,
              right: AppSpacing.screenHorizontalMargin,
              top: 14,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Atur Jatah Belanja', style: AppTypography.pageHeader),
                const SizedBox(height: 16),

                // Top Summary Hero Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Status Label & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final pState = context.read<ProfileCubit>().state;
                              final userIncome = pState is ProfileLoaded
                                  ? pState.profile.monthlyIncome
                                  : 0.0;
                              final needsWantsTarget = userIncome > 0
                                  ? userIncome * 0.8
                                  : totalLimit;
                              final savingsTarget = userIncome > 0
                                  ? userIncome * 0.2
                                  : 0.0;
                              final pctSpent = totalLimit > 0
                                  ? ((totalSpent / totalLimit) * 100).round()
                                  : 0;

                              ExplanationSheet.show(
                                context,
                                title: 'Status Anggaran Bulan Ini',
                                metricValue: CurrencyFormatter.format(totalLimit),
                                formula: totalLimit > 0
                                    ? '${CurrencyFormatter.format(totalLimit)} (Jatah) - ${CurrencyFormatter.format(totalSpent)} (Terpakai) = ${CurrencyFormatter.format(remainingBudget)} (Sisa)'
                                    : 'Formula 50/30/20',
                                explanation: userIncome > 0
                                    ? 'Berdasarkan pemasukan bulananmu (${CurrencyFormatter.format(userIncome)}), panduan 50/30/20 menyarankan batas belanja maksimal 80% yaitu ${CurrencyFormatter.format(needsWantsTarget)} (Kebutuhan & Keinginan), dan 20% sisanya (${CurrencyFormatter.format(savingsTarget)}) untuk pos tabungan & investasi.\n\nSaat ini kamu telah mengalokasikan total jatah kategori belanja sebesar ${CurrencyFormatter.format(totalLimit)}, dengan realisasi pengeluaran ${CurrencyFormatter.format(totalSpent)} ($pctSpent%).'
                                    : 'Total Jatah Anggaran adalah batas belanja maksimal dari seluruh kategori aktif yang kamu buat (${CurrencyFormatter.format(totalLimit)}). Saat ini realisasi pengeluaran tercatat ${CurrencyFormatter.format(totalSpent)} dengan sisa jatah aman ${CurrencyFormatter.format(remainingBudget)}.',
                                tip:
                                    'Perbedaan istilah:\n• Total Jatah: Batas maksimal belanja kamu sebulan (${CurrencyFormatter.format(totalLimit)}).\n• Sisa Jatah: Uang belanja yang masih boleh dipakai bulan ini (${CurrencyFormatter.format(remainingBudget)}).',
                                icon: PhosphorIcons.chartPie(PhosphorIconsStyle.fill),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Status Anggaran Bulan Ini',
                                  style: AppTypography.itemTitle.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  PhosphorIcons.info(PhosphorIconsStyle.bold),
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isOverbudget
                                  ? AppColors.expenseRedBg
                                  : (overallRatio >= 0.85
                                      ? AppColors.warningOrangeBg
                                      : AppColors.incomeGreenBg),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text(
                              isOverbudget
                                  ? 'Boncos'
                                  : (overallRatio >= 0.85 ? 'Tinggal Dikit' : 'Aman'),
                              style: AppTypography.captionText.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isOverbudget
                                    ? AppColors.expenseRed
                                    : (overallRatio >= 0.85
                                        ? AppColors.warningOrange
                                        : AppColors.incomeGreen),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Donut Chart + Spent Numbers
                      Row(
                        children: [
                          // Circular Progress Ring
                          SizedBox(
                            width: 86,
                            height: 86,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 86,
                                  height: 86,
                                  child: CircularProgressIndicator(
                                    value: 1.0,
                                    strokeWidth: 8,
                                    color: AppColors.surfaceFieldFill,
                                  ),
                                ),
                                SizedBox(
                                  width: 86,
                                  height: 86,
                                  child: CircularProgressIndicator(
                                    value: spentProgress,
                                    strokeWidth: 8,
                                    strokeCap: StrokeCap.round,
                                    color: isOverbudget
                                        ? AppColors.expenseRed
                                        : (overallRatio >= 0.85
                                            ? AppColors.warningOrange
                                            : AppColors.primary),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$remainingPercent%',
                                      style: AppTypography.itemTitle.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isOverbudget
                                            ? AppColors.expenseRed
                                            : AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'Sisa Jatah',
                                      style: AppTypography.captionText.copyWith(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),

                          // Text Info on Right
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Duit Kepake',
                                  style: AppTypography.captionText.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.format(totalSpent),
                                  style: AppTypography.displayBalance.copyWith(
                                    fontSize: 24,
                                    color: isOverbudget
                                        ? AppColors.expenseRed
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isOverbudget
                                      ? 'Nombok ${CurrencyFormatter.format(remainingBudget.abs())}'
                                      : (totalSpent == 0
                                          ? 'Dompet masih utuh aman terkendali'
                                          : 'Masih ada sisa ${CurrencyFormatter.format(remainingBudget)}'),
                                  style: AppTypography.captionText.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isOverbudget
                                        ? AppColors.expenseRed
                                        : AppColors.incomeGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Bottom Details Pill Row: Batas & Sisa Jatah (Responsive 2-column bento, zero overflow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppColors.textSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Total Jatah',
                                        style: AppTypography.captionText.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      CurrencyFormatter.format(totalLimit),
                                      style: AppTypography.itemTitle.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: AppColors.textSecondary.withValues(alpha: 0.2),
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isOverbudget
                                              ? AppColors.expenseRed
                                              : AppColors.incomeGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOverbudget ? 'Tekor' : 'Sisa Jatah',
                                        style: AppTypography.captionText.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOverbudget
                                              ? AppColors.expenseRed
                                              : AppColors.incomeGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      isOverbudget
                                          ? '-${CurrencyFormatter.format(remainingBudget.abs())}'
                                          : CurrencyFormatter.format(remainingBudget),
                                      style: AppTypography.itemTitle.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: isOverbudget
                                            ? AppColors.expenseRed
                                            : AppColors.incomeGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Financial Allocation Guardrail
                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, profileState) {
                    double income = 0;
                    if (profileState is ProfileLoaded) {
                      income = profileState.profile.monthlyIncome;
                    }
                    final idealCap = income * 0.80;
                    final isOverIncome = income > 0 && totalLimit > income;
                    final isSqueezingSavings =
                        income > 0 && totalLimit > idealCap && totalLimit <= income;
                    final overIncomeDiff = totalLimit - income;
                    final remainingForSavings =
                        (income - totalLimit).clamp(0.0, double.infinity);
                    final allocatedPct =
                        income > 0 ? ((totalLimit / income) * 100).round() : 0;

                    if (!isOverIncome && !isSqueezingSavings) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isOverIncome
                              ? AppColors.expenseRedBg
                              : AppColors.warningOrangeBg,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusBentoAndItem,
                          ),
                          border: Border.all(
                            color: (isOverIncome
                                    ? AppColors.expenseRed
                                    : AppColors.warningOrange)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIcons.warningCircle(
                                PhosphorIconsStyle.fill,
                              ),
                              color: isOverIncome
                                  ? AppColors.expenseRed
                                  : AppColors.warningOrange,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOverIncome
                                        ? 'Over-Alokasi: Jatah Melebihi Gaji ($allocatedPct%)!'
                                        : 'Alokasi Menggerus Tabungan 20% ($allocatedPct% Gaji)',
                                    style: AppTypography.itemTitle.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isOverIncome
                                          ? AppColors.expenseRed
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isOverIncome
                                        ? 'Total rencana jatah belanja (${CurrencyFormatter.format(totalLimit)}) melampaui pemasukan bulananmu (${CurrencyFormatter.format(income)}) sebesar ${CurrencyFormatter.format(overIncomeDiff)}. Kurangi jatah kategori agar tidak defisit.'
                                        : 'Total jatah belanja (${CurrencyFormatter.format(totalLimit)}) melewati batas ideal 80% gaji (${CurrencyFormatter.format(idealCap)}). Jatah tabungan rutinmu bulan ini menyempit tinggal ${CurrencyFormatter.format(remainingForSavings)}.',
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
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Pos Jatah Belanja Section
                Text(
                  'Pos Jatah Belanja Per Kategori',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 10),

                if (budgets.isEmpty)
                  _buildEmptyBudgetCard(context)
                else
                  ...budgets.map((b) => _buildCategoryBudgetCard(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBudgetCard(BudgetEntity b) {
    final catName = b.categoryName ?? 'Anggaran Belanja';
    final limit = b.limitAmount;
    final spent = b.spentAmount;
    final remaining = limit - spent;
    final ratio = limit > 0 ? (spent / limit) : 0.0;
    final isExceeded = remaining < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _iconForCategory(catName),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ExplanationSheet.show(
                      context,
                      title: 'Jatah $catName',
                      metricValue: CurrencyFormatter.format(limit),
                      formula:
                          '${CurrencyFormatter.format(limit)} (Jatah) - ${CurrencyFormatter.format(spent)} (Terpakai) = ${CurrencyFormatter.format(remaining)} (Sisa)',
                      explanation:
                          'Pos belanja "$catName" memiliki alokasi batas belanja sebesar ${CurrencyFormatter.format(limit)}. Hingga saat ini telah terpakai ${CurrencyFormatter.format(spent)} (${(ratio * 100).round()}%).\n\n${isExceeded ? 'Pengeluaran pada pos ini telah melampaui jatah sebesar ${CurrencyFormatter.format(remaining.abs())}.' : 'Sisa jatah belanja aman yang masih bisa kamu gunakan adalah ${CurrencyFormatter.format(remaining)}.'}',
                      tip: isExceeded
                          ? 'Tahan pengeluaran untuk $catName hingga bulan berikutnya agar keuangan lekas pulih.'
                          : 'Pertahankan rata-rata belanja harian agar jatah cukup hingga akhir bulan.',
                      icon: _iconForCategory(catName),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              catName,
                              style: AppTypography.itemTitle.copyWith(
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIcons.info(PhosphorIconsStyle.bold),
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      Text(
                        'Jatah: ${CurrencyFormatter.format(limit)}',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildStatusChip(ratio),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceFieldFill,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded
                    ? AppColors.expenseRed
                    : (ratio >= 0.85
                        ? AppColors.warningOrange
                        : AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Terpakai: ${CurrencyFormatter.format(spent)}',
                  style: AppTypography.captionText.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isExceeded ? AppColors.expenseRed : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showEditBudgetDialog(
                  context,
                  categoryId: b.categoryId,
                  categoryName: catName,
                  currentLimit: limit,
                  spentAmount: spent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExceeded
                          ? 'Tekor ${CurrencyFormatter.format(remaining.abs())}'
                          : 'Sisa ${CurrencyFormatter.format(remaining)}',
                      style: AppTypography.captionText.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isExceeded
                            ? AppColors.expenseRed
                            : AppColors.incomeGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      PhosphorIcons.pencilSimple(),
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudgetCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.chartPieSlice(),
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Jatah Belanja Aktif',
              style: AppTypography.itemTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan pos jatah belanja per kategori agar pengeluaran bulananmu tetap terkawal.',
              textAlign: TextAlign.center,
              style: AppTypography.captionText.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Tambah Pos Jatah Belanja',
              onPressed: () => _showAddCategoryBudgetSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}
