import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../cubit/monthly_review_cubit.dart';
import '../cubit/monthly_review_state.dart';

class MonthlyReviewPage extends StatefulWidget {
  const MonthlyReviewPage({super.key});

  @override
  State<MonthlyReviewPage> createState() => _MonthlyReviewPageState();
}

class _MonthlyReviewPageState extends State<MonthlyReviewPage> {
  late DateTime _currentMonth;
  late final MonthlyReviewCubit _cubit;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _cubit = sl<MonthlyReviewCubit>()
      ..loadReviewForMonth(_currentMonth, forceRegenerate: true);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
        1,
      );
    });
    _cubit.loadReviewForMonth(_currentMonth, forceRegenerate: true);
  }

  void _showMonthPickerSheet() {
    int pickerYear = _currentMonth.year;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final now = DateTime.now();
            const shortMonthNames = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'Mei',
              'Jun',
              'Jul',
              'Agu',
              'Sep',
              'Okt',
              'Nov',
              'Des',
            ];

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Periode Evaluasi',
                        style: AppTypography.screenTitle.copyWith(fontSize: 18),
                      ),
                      TextButton(
                        onPressed: () {
                          final currentMonth = DateTime(now.year, now.month, 1);
                          setState(() {
                            _currentMonth = currentMonth;
                          });
                          _cubit.loadReviewForMonth(
                            _currentMonth,
                            forceRegenerate: true,
                          );
                          Navigator.pop(modalCtx);
                        },
                        child: Text(
                          'Bulan Ini',
                          style: AppTypography.sectionLabel.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFieldFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            size: 18,
                          ),
                          color: AppColors.primaryDark,
                          onPressed: () => setSheetState(() => pickerYear--),
                        ),
                        Text(
                          '$pickerYear',
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 18,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                            size: 18,
                          ),
                          color: AppColors.primaryDark,
                          onPressed: () => setSheetState(() => pickerYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.8,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected =
                          pickerYear == _currentMonth.year &&
                          monthNum == _currentMonth.month;
                      final isRealCurrent =
                          pickerYear == now.year && monthNum == now.month;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final chosenMonth = DateTime(
                              pickerYear,
                              monthNum,
                              1,
                            );
                            setState(() {
                              _currentMonth = chosenMonth;
                            });
                            _cubit.loadReviewForMonth(
                              _currentMonth,
                              forceRegenerate: true,
                            );
                            Navigator.pop(modalCtx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isRealCurrent
                                        ? AppColors.primaryLight
                                        : AppColors.surfaceFieldFill),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: isRealCurrent
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              shortMonthNames[index],
                              style: AppTypography.sectionLabel.copyWith(
                                fontSize: 13,
                                fontWeight: isSelected || isRealCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isRealCurrent
                                          ? AppColors.primary
                                          : AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Builder(
        builder: (context) {
          final monthName = DateFormatter.formatMonthYear(_currentMonth);

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
              title: Text('Evaluasi Bulanan', style: AppTypography.pageHeader),
              centerTitle: true,
            ),
            body: SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceCard,
                onRefresh: () async {
                  await _cubit.loadReviewForMonth(
                    _currentMonth,
                    forceRegenerate: true,
                  );
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month Switcher Pill Selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                PhosphorIcons.caretLeft(),
                                color: AppColors.primary,
                              ),
                              onPressed: () => _changeMonth(-1),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _showMonthPickerSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      monthName,
                                      style: AppTypography.sectionLabel
                                          .copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      PhosphorIcons.caretDown(
                                        PhosphorIconsStyle.bold,
                                      ),
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                PhosphorIcons.caretRight(),
                                color: AppColors.primary,
                              ),
                              onPressed: () => _changeMonth(1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Review Content State
                      BlocBuilder<MonthlyReviewCubit, MonthlyReviewState>(
                        builder: (context, state) {
                          if (state is MonthlyReviewLoading ||
                              state is MonthlyReviewInitial) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 60),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Menghitung evaluasi bulanan...',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (state is MonthlyReviewError) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.expenseRedBg,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.expenseRed,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    state.message,
                                    style: const TextStyle(
                                      color: AppColors.expenseRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  AppButton(
                                    label: 'Coba Lagi',
                                    onPressed: () => _cubit.loadReviewForMonth(
                                      _currentMonth,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (state is MonthlyReviewLoaded) {
                            final metrics = state.review.metrics;
                            final isSurplus = metrics.netCashFlow >= 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 2 Side-by-Side MetricCards
                                Row(
                                  children: [
                                    Expanded(
                                      child: MetricCard(
                                        cardTheme: MetricCardTheme.lime,
                                        icon: PhosphorIcons.arrowDownLeft(
                                          PhosphorIconsStyle.bold,
                                        ),
                                        label: 'Pemasukan',
                                        value: CurrencyFormatter.format(
                                          metrics.totalIncome,
                                        ),
                                        caption: 'Bulan ini',
                                        showInfoIcon: false,
                                        infoFormula:
                                            '${metrics.incomeTransactionCount} Transaksi Masuk = ${CurrencyFormatter.format(metrics.totalIncome)}',
                                        infoExplanation:
                                            'Total seluruh uang masuk tercatat sebesar ${CurrencyFormatter.format(metrics.totalIncome)} dari ${metrics.incomeTransactionCount} transaksi pemasukan pada periode ini.',
                                        infoTip:
                                            'Catat pemasukan rutin dan sampingan tepat waktu agar evaluasi bulananmu selalu presisi.',
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.cardGap),
                                    Expanded(
                                      child: MetricCard(
                                        cardTheme: MetricCardTheme.dark,
                                        icon: PhosphorIcons.arrowUpRight(
                                          PhosphorIconsStyle.bold,
                                        ),
                                        label: 'Pengeluaran',
                                        value: CurrencyFormatter.format(
                                          metrics.totalExpense,
                                        ),
                                        caption: 'Bulan ini',
                                        showInfoIcon: false,
                                        infoFormula:
                                            '${metrics.expenseTransactionCount} Transaksi Keluar = ${CurrencyFormatter.format(metrics.totalExpense)}',
                                        infoExplanation:
                                            'Total seluruh uang keluar atau belanja tercatat sebesar ${CurrencyFormatter.format(metrics.totalExpense)} dari ${metrics.expenseTransactionCount} transaksi pengeluaran pada periode ini.',
                                        infoTip:
                                            'Bandingkan dengan total jatah anggaranmu untuk memantau pos mana saja yang melebihi batas.',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Sisa Duit Bersih Card (Proportional font & segmented stat pills)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusBentoAndItem,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              final incStr =
                                                  CurrencyFormatter.format(
                                                    metrics.totalIncome,
                                                  );
                                              final expStr =
                                                  CurrencyFormatter.format(
                                                    metrics.totalExpense,
                                                  );
                                              final netStr =
                                                  CurrencyFormatter.format(
                                                    metrics.netCashFlow.abs(),
                                                  );
                                              final signStr = isSurplus
                                                  ? '+'
                                                  : '-';
                                              final formulaStr =
                                                  metrics.totalIncome > 0
                                                  ? '($incStr - $expStr) / $incStr x 100% = ${metrics.savingsRate.toStringAsFixed(1)}%'
                                                  : '$incStr - $expStr = $signStr$netStr';

                                              ExplanationSheet.show(
                                                context,
                                                title:
                                                    'Sisa Uang Bersih & Rasio Simpan',
                                                metricValue:
                                                    '${metrics.savingsRate.toStringAsFixed(0)}% ($signStr$netStr)',
                                                formula: formulaStr,
                                                explanation:
                                                    'Total pemasukan sebesar $incStr dikurangi seluruh pengeluaran $expStr menghasilkan sisa arus kas bersih sebesar $signStr$netStr (${isSurplus ? 'Surplus' : 'Defisit'}).\n\nRasio simpan menunjukkan bahwa kamu berhasil mempertahankan ${metrics.savingsRate.toStringAsFixed(0)}% dari pendapatanmu pada bulan ini.',
                                                tip:
                                                    'Idealnya sisihkan minimal 20% pemasukan ke pos tabungan atau dana darurat sebelum dipakai belanja gaya hidup.',
                                                icon: PhosphorIcons.piggyBank(
                                                  PhosphorIconsStyle.fill,
                                                ),
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Sisa Duit Bersih',
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  PhosphorIcons.info(
                                                    PhosphorIconsStyle.bold,
                                                  ),
                                                  size: 13,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ],
                                            ),
                                          ),
                                          isSurplus
                                              ? StatusChip.aman('Surplus')
                                              : StatusChip.melebihi('Defisit'),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        CurrencyFormatter.formatSigned(
                                          metrics.netCashFlow,
                                          isIncome: isSurplus,
                                        ),
                                        style: AppTypography.itemTitle.copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: isSurplus
                                              ? AppColors.incomeGreen
                                              : AppColors.expenseRed,
                                        ),
                                      ),
                                      // Micro-stats Segmented Row (Resolves long run-on text)
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgCanvasMain,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusInnerElement,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildMicroStat(
                                              'Rasio Simpan',
                                              '${metrics.savingsRate.toStringAsFixed(0)}%',
                                              valueColor: isSurplus
                                                  ? AppColors.incomeGreen
                                                  : AppColors.expenseRed,
                                            ),
                                            Container(
                                              width: 1,
                                              height: 22,
                                              color: Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                            ),
                                            _buildMicroStat(
                                              'Pemasukan',
                                              '${metrics.incomeTransactionCount}x',
                                            ),
                                            Container(
                                              width: 1,
                                              height: 22,
                                              color: Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                            ),
                                            _buildMicroStat(
                                              'Belanja',
                                              '${metrics.expenseTransactionCount}x',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Distribusi Pengeluaran Card (Dipakai Buat Apa Aja?)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusBentoAndItem,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            PhosphorIcons.chartPie(
                                              PhosphorIconsStyle.fill,
                                            ),
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Dipakai Buat Apa Aja?',
                                            style: AppTypography.itemTitle
                                                .copyWith(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (metrics.totalExpense <= 0 &&
                                          metrics.categoryBreakdown.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.incomeGreenBg
                                                .withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusInnerElement,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                PhosphorIcons.checkCircle(
                                                  PhosphorIconsStyle.fill,
                                                ),
                                                size: 18,
                                                color: AppColors.incomeGreen,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Pemasukanmu masih utuh 100%! Belum ada pengeluaran belanja di bulan ini.',
                                                  style: AppTypography
                                                      .captionText
                                                      .copyWith(
                                                        color: AppColors
                                                            .incomeGreen,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 11.5,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ..._buildCategoryList(
                                          metrics.categoryBreakdown.isNotEmpty
                                              ? metrics.categoryBreakdown
                                              : {
                                                  'Belanja & Pengeluaran':
                                                      metrics.totalExpense,
                                                },
                                          metrics.totalExpense,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // AI Narrative Card (Ulasan Coach)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusBentoAndItem,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Ulasan Coach',
                                            style: AppTypography.itemTitle
                                                .copyWith(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        state.review.narrative,
                                        style: AppTypography.body.copyWith(
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Catatan Seluruh Transaksi Bulan Ini
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusBentoAndItem,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                PhosphorIcons.receipt(
                                                  PhosphorIconsStyle.fill,
                                                ),
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Rincian Transaksi Bulan Ini',
                                                style: AppTypography.itemTitle
                                                    .copyWith(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${state.review.transactions.length} catatan',
                                            style: AppTypography.captionText
                                                .copyWith(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (state.review.transactions.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Belum ada transaksi tercatat di periode ini.',
                                            style: AppTypography.captionText
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        )
                                      else
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              state.review.transactions.length,
                                          separatorBuilder: (_, index) =>
                                              Divider(
                                                height: 16,
                                                thickness: 1,
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                              ),
                                          itemBuilder: (context, index) {
                                            final tx = state
                                                .review
                                                .transactions[index];
                                            final isInc =
                                                tx.transactionType ==
                                                TransactionType.income;
                                            String noteText =
                                                tx.note?.isNotEmpty == true
                                                ? tx.note!
                                                : (tx.category?.name ??
                                                      'Transaksi');
                                            if (noteText.startsWith(
                                              'Pemasukan Bulanan Awal',
                                            )) {
                                              noteText = 'Gaji Bulanan';
                                            }

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: isInc
                                                          ? AppColors
                                                                .incomeGreenBg
                                                          : AppColors
                                                                .expenseRedBg,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        isInc
                                                            ? PhosphorIcons.arrowDownLeft()
                                                            : PhosphorIcons.arrowUpRight(),
                                                        color: isInc
                                                            ? AppColors
                                                                  .incomeGreen
                                                            : AppColors
                                                                  .expenseRed,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          noteText,
                                                          style: AppTypography
                                                              .itemTitle
                                                              .copyWith(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '${DateFormat('dd MMM yyyy', 'id_ID').format(tx.transactionDate)} · ${tx.category?.name ?? (isInc ? 'Pemasukan' : 'Pengeluaran')}',
                                                          style: AppTypography
                                                              .captionText
                                                              .copyWith(
                                                                fontSize: 11,
                                                                color: AppColors
                                                                    .textSecondary,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Text(
                                                    CurrencyFormatter.formatSigned(
                                                      tx.amount,
                                                      isIncome: isInc,
                                                    ),
                                                    style: AppTypography
                                                        .itemTitle
                                                        .copyWith(
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: isInc
                                                              ? AppColors
                                                                    .incomeGreen
                                                              : AppColors
                                                                    .textPrimary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Tombol Cetak Laporan PDF Resmi (Bab 9 PRD) & Hitung Ulang
                                AppButton(
                                  label: 'Cetak Laporan PDF Resmi',
                                  icon: Icon(PhosphorIcons.printer(), size: 18),
                                  onPressed: () {
                                    final authState = context
                                        .read<AuthCubit>()
                                        .state;
                                    String userName = 'Pengguna';
                                    if (authState is Authenticated &&
                                        authState.user.displayName != null &&
                                        authState
                                            .user
                                            .displayName!
                                            .isNotEmpty) {
                                      userName = authState.user.displayName!;
                                    }
                                    PdfReportService.printMonthlyReport(
                                      review: state.review,
                                      userName: userName,
                                      monthName: monthName,
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMicroStat(String label, String value, {Color? valueColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.captionText.copyWith(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.itemTitle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryList(Map<String, double> breakdown, double total) {
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final widgets = <Widget>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 12));
      widgets.add(_buildCategoryBar(sorted[i].key, sorted[i].value, total));
    }
    return widgets;
  }

  Widget _buildCategoryBar(String name, double amount, double total) {
    final ratio = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final percentage = (ratio * 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$name ($percentage%)',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              CurrencyFormatter.format(amount),
              style: AppTypography.sectionLabel.copyWith(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: Colors.black.withValues(alpha: 0.06),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
