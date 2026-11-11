import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../budgets/domain/entities/budget_entity.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../budgets/presentation/cubit/budget_state.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../goals/presentation/cubit/goal_state.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../../transactions/presentation/cubit/transaction_state.dart';
import '../../../stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import '../../../stock_signals/presentation/cubit/stock_signal_list_state.dart';
import '../../../stock_signals/presentation/widgets/stock_signal_dashboard_card.dart';
import '../../../notifications/domain/notification_helper.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/status_chip.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onOpenAddSheet;
  final ValueChanged<int>? onSwitchTab;

  const HomePage({super.key, this.onOpenAddSheet, this.onSwitchTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _selectedMonth;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PushNotificationService().requestPermission();
      if (mounted) {
        context.read<StockSignalListCubit>().loadSignals();
      }
      _checkUnreadNotifications();
    });
  }

  Future<void> _checkUnreadNotifications() async {
    if (!mounted) return;
    StockSignalListState? stockState;
    try {
      stockState = context.read<StockSignalListCubit>().state;
    } catch (_) {}
    final hasUnread = await NotificationHelper.hasUnread(
      budgetState: context.read<BudgetCubit>().state,
      goalState: context.read<GoalCubit>().state,
      profileState: context.read<ProfileCubit>().state,
      transactionState: context.read<TransactionCubit>().state,
      stockSignalState: stockState,
    );
    if (mounted && _hasUnreadNotifications != hasUnread) {
      setState(() {
        _hasUnreadNotifications = hasUnread;
      });
    }
  }

  void _showMonthPickerSheet() {
    int pickerYear = _selectedMonth.year;

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
                        'Pilih Periode Bulan',
                        style: AppTypography.screenTitle.copyWith(fontSize: 18),
                      ),
                      TextButton(
                        onPressed: () {
                          final currentMonth = DateTime(now.year, now.month, 1);
                          setState(() {
                            _selectedMonth = currentMonth;
                          });
                          context.read<BudgetCubit>().loadBudgets(
                            start: currentMonth,
                            end: DateTime(now.year, now.month + 1, 0),
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
                          pickerYear == _selectedMonth.year &&
                          monthNum == _selectedMonth.month;
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
                              _selectedMonth = chosenMonth;
                            });
                            context.read<BudgetCubit>().loadBudgets(
                              start: chosenMonth,
                              end: DateTime(pickerYear, monthNum + 1, 0),
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

  // Notifications navigated to /notifications page via NotificationCenterPage
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        String userName = 'Pengguna';
        if (authState is Authenticated &&
            authState.user.displayName != null &&
            authState.user.displayName!.trim().isNotEmpty) {
          userName = authState.user.displayName!.trim().split(' ').first;
        }

        final now = DateTime.now();
        final isCurrentMonth =
            _selectedMonth.year == now.year &&
            _selectedMonth.month == now.month;
        final currentPeriodLabel = DateFormatter.formatMonthYear(
          _selectedMonth,
        );
        final monthSubtitle = isCurrentMonth ? 'Bulan ini' : currentPeriodLabel;

        return MultiBlocListener(
          listeners: [
            BlocListener<TransactionCubit, TransactionState>(
              listener: (context, state) => _checkUnreadNotifications(),
            ),
            BlocListener<BudgetCubit, BudgetState>(
              listener: (context, state) => _checkUnreadNotifications(),
            ),
            BlocListener<GoalCubit, GoalState>(
              listener: (context, state) => _checkUnreadNotifications(),
            ),
            BlocListener<ProfileCubit, ProfileState>(
              listener: (context, state) => _checkUnreadNotifications(),
            ),
          ],
          child: RefreshIndicator(
            color: AppColors.primaryDark,
            onRefresh: () async {
              await Future.wait([
                context.read<TransactionCubit>().loadTransactions(),
                context.read<BudgetCubit>().loadBudgets(
                  start: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                  end: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
                ),
                context.read<GoalCubit>().loadGoals(),
                context.read<StockSignalListCubit>().refresh(),
              ]);
              _checkUnreadNotifications();
            },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(
              left: AppSpacing.sideMargin,
              right: AppSpacing.sideMargin,
              top: 16,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Avatar + "Hai, [Nama]" + action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onSwitchTab?.call(4),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: Center(
                                child: Text(
                                  userName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hai, $userName',
                                    style: AppTypography.sectionLabel.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Selamat datang kembali',
                                    style: AppTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppIconButton(
                      icon: Icons.notifications_none_rounded,
                      showBadgeDot: _hasUnreadNotifications,
                      onPressed: () async {
                        await context.push('/notifications');
                        _checkUnreadNotifications();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Period Filter Pill
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _showMonthPickerSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: AppSpacing.softShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.calendarBlank(
                              PhosphorIconsStyle.bold,
                            ),
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentPeriodLabel,
                            style: AppTypography.sectionLabel.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Hero Label & Huge Net Cash Flow Number + 2x2 Grid
                GestureDetector(
                  onTap: () {
                    final txState = context.read<TransactionCubit>().state;
                    final goalState = context.read<GoalCubit>().state;
                    double cashFlowValNum = 0.0;
                    double mIncVal = 0.0;
                    double mExpVal = 0.0;
                    final double mSavingsTransfer = goalState is GoalLoaded
                        ? goalState.netSavingsForMonth(
                            _selectedMonth.year,
                            _selectedMonth.month,
                          )
                        : 0.0;
                    int incCount = 0;
                    int expCount = 0;
                    if (txState is TransactionLoaded) {
                      final monthTxs = txState.transactions.where((t) {
                        return t.transactionDate.year == _selectedMonth.year &&
                            t.transactionDate.month == _selectedMonth.month &&
                            t.status == TransactionStatus.confirmed;
                      }).toList();
                      final incList = monthTxs.where(
                        (t) => t.transactionType == TransactionType.income,
                      );
                      final expList = monthTxs.where(
                        (t) => t.transactionType == TransactionType.expense,
                      );
                      mIncVal = incList.fold(0.0, (s, t) => s + t.amount);
                      mExpVal = expList.fold(0.0, (s, t) => s + t.amount);
                      incCount = incList.length;
                      expCount = expList.length;
                      cashFlowValNum = FinancialCalculator.calculateNetCashFlow(
                        totalIncome: mIncVal,
                        totalExpense: mExpVal,
                        savingsTransfer: mSavingsTransfer,
                      );
                    }
                    final isSurplus = cashFlowValNum >= 0;
                    final cashFlowVal = CurrencyFormatter.formatSigned(
                      cashFlowValNum,
                      isIncome: isSurplus,
                    );
                    final String formulaText;
                    final String transferExplanation;
                    if (mSavingsTransfer > 0) {
                      formulaText =
                          '${CurrencyFormatter.format(mIncVal)} (Masuk) - ${CurrencyFormatter.format(mExpVal)} (Belanja) - ${CurrencyFormatter.format(mSavingsTransfer)} (Tabungan/Darurat) = $cashFlowVal';
                      transferExplanation =
                          ' serta dikurangi dana yang sudah dipindahkan ke pos Tabungan / Dana Darurat sebesar ${CurrencyFormatter.format(mSavingsTransfer)}';
                    } else if (mSavingsTransfer < 0) {
                      formulaText =
                          '${CurrencyFormatter.format(mIncVal)} (Masuk) - ${CurrencyFormatter.format(mExpVal)} (Belanja) + ${CurrencyFormatter.format(mSavingsTransfer.abs())} (Pakai Dana Darurat) = $cashFlowVal';
                      transferExplanation =
                          ' serta disesuaikan penarikan Dana Darurat sebesar ${CurrencyFormatter.format(mSavingsTransfer.abs())}';
                    } else {
                      formulaText =
                          '${CurrencyFormatter.format(mIncVal)} (Pemasukan) - ${CurrencyFormatter.format(mExpVal)} (Belanja) = $cashFlowVal';
                      transferExplanation = '';
                    }
                    ExplanationSheet.show(
                      context,
                      title: isCurrentMonth
                          ? 'Sisa Uang Bersih Bulan Ini'
                          : 'Sisa Uang Bersih ($currentPeriodLabel)',
                      metricValue: cashFlowVal,
                      formula: formulaText,
                      explanation:
                          'Sisa Uang Bersih dompet utama dihitung dari total pemasukan tercatat (${CurrencyFormatter.format(mIncVal)} dari $incCount transaksi) dikurangi seluruh belanja (${CurrencyFormatter.format(mExpVal)} dari $expCount transaksi)$transferExplanation pada $currentPeriodLabel.\n\n${isSurplus ? 'Kas dompet utamamu saat ini masih surplus ${CurrencyFormatter.format(cashFlowValNum)} (terpisah dari celengan Tabungan & Dana Darurat).' : 'Pengeluaran dan alokasi tabunganmu melebihi pemasukan (defisit ${CurrencyFormatter.format(cashFlowValNum.abs())}). Tahan belanja non-esensial agar dompet lekas pulih.'}',
                      tip:
                          'Setiap dana yang kamu pindahkan ke Tabungan atau Dana Darurat otomatis mengurangi angka ini agar terpisah dari uang belanja harian.',
                      icon: PhosphorIcons.coins(PhosphorIconsStyle.fill),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        isCurrentMonth
                            ? 'Sisa Uang Bersih Bulan Ini'
                            : 'Sisa Uang Bersih ($currentPeriodLabel)',
                        style: AppTypography.caption.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        PhosphorIcons.info(PhosphorIconsStyle.bold),
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                BlocBuilder<GoalCubit, GoalState>(
                  builder: (context, goalState) {
                    final double mSavingsTransfer = goalState is GoalLoaded
                        ? goalState.netSavingsForMonth(
                            _selectedMonth.year,
                            _selectedMonth.month,
                          )
                        : 0.0;
                    return BlocBuilder<TransactionCubit, TransactionState>(
                      builder: (context, txState) {
                        String cashFlowText = 'Rp0';
                        String incomeText = 'Rp0';
                        String expenseText = 'Rp0';
                        List<TransactionEntity> incTxs = [];
                        List<TransactionEntity> expTxs = [];
                        double mInc = 0.0;
                        double mExp = 0.0;
                        bool hasMonthCashflow = false;
                        if (txState is TransactionLoaded) {
                          final monthTxs = txState.transactions.where((t) {
                            return t.transactionDate.year == _selectedMonth.year &&
                                t.transactionDate.month == _selectedMonth.month &&
                                t.status == TransactionStatus.confirmed;
                          }).toList();

                          incTxs = monthTxs
                              .where(
                                (t) => t.transactionType == TransactionType.income,
                              )
                              .toList();
                          expTxs = monthTxs
                              .where(
                                (t) => t.transactionType == TransactionType.expense,
                              )
                              .toList();
                          mInc = incTxs.fold(0.0, (s, t) => s + t.amount);
                          mExp = expTxs.fold(0.0, (s, t) => s + t.amount);
                          final mNet = FinancialCalculator.calculateNetCashFlow(
                            totalIncome: mInc,
                            totalExpense: mExp,
                            savingsTransfer: mSavingsTransfer,
                          );
                          hasMonthCashflow =
                              mInc > 0 || mExp > 0 || mSavingsTransfer != 0;

                          cashFlowText = CurrencyFormatter.formatSigned(
                            mNet,
                            isIncome: mNet >= 0,
                          );
                          incomeText = CurrencyFormatter.format(mInc);
                          expenseText = CurrencyFormatter.format(mExp);
                        }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cashFlowText,
                            style: AppTypography.bigNumber,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 4. Section of 4 Equal Square Statistic Cards (2x2 Grid)
                        BlocBuilder<BudgetCubit, BudgetState>(
                          builder: (context, budgetState) {
                            String budgetLabel = 'Jatah Belanja';
                            String budgetVal = 'Belum Diatur';
                            String budgetCap = 'Atur Jatah di Menu Budget';
                            double? budgetProgress;
                            Color? budgetProgressColor;
                            IconData budgetIcon = PhosphorIcons.wallet(
                              PhosphorIconsStyle.fill,
                            );
                            Widget budgetChip = StatusChip.aman('Aman');
                            BudgetEntity? topBudget;

                            if (budgetState is BudgetLoaded &&
                                budgetState.budgets.isNotEmpty) {
                              final sorted = [...budgetState.budgets]
                                ..sort(
                                  (a, b) => b.usagePercentage.compareTo(
                                    a.usagePercentage,
                                  ),
                                );
                              topBudget = sorted.first;
                              budgetLabel = topBudget.categoryName ?? 'Pos Belanja';
                              final uuidRegex = RegExp(
                                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                              );
                              if (uuidRegex.hasMatch(budgetLabel) ||
                                  budgetLabel.length > 25) {
                                budgetLabel = 'Pos Belanja';
                              }

                              final lowerName = budgetLabel.toLowerCase();
                              if (lowerName.contains('makan') ||
                                  lowerName.contains('minum') ||
                                  lowerName.contains('kuliner')) {
                                budgetIcon = PhosphorIcons.forkKnife(
                                  PhosphorIconsStyle.fill,
                                );
                              } else if (lowerName.contains('trans') ||
                                  lowerName.contains('bensin') ||
                                  lowerName.contains('ojol')) {
                                budgetIcon = PhosphorIcons.car(
                                  PhosphorIconsStyle.fill,
                                );
                              } else if (lowerName.contains('tagihan') ||
                                  lowerName.contains('listrik') ||
                                  lowerName.contains('utilitas')) {
                                budgetIcon = PhosphorIcons.receipt(
                                  PhosphorIconsStyle.fill,
                                );
                              } else if (lowerName.contains('hiburan') ||
                                  lowerName.contains('nonton') ||
                                  lowerName.contains('hobi')) {
                                budgetIcon = PhosphorIcons.gameController(
                                  PhosphorIconsStyle.fill,
                                );
                              }

                              if (!hasMonthCashflow) {
                                budgetVal = 'Rp0';
                                budgetCap = 'Tidak ada transaksi';
                                budgetProgress = 0.0;
                                budgetChip = const StatusChip(
                                  label: '-',
                                  type: StatusType.neutral,
                                );
                              } else {
                                budgetVal = CurrencyFormatter.format(
                                  topBudget.spentAmount,
                                );
                                budgetCap =
                                    'Sisa jatah: ${CurrencyFormatter.format(topBudget.remainingAmount)}';
                                budgetProgress = topBudget.usagePercentage.clamp(
                                  0.0,
                                  1.0,
                                );

                                if (topBudget.isExceeded) {
                                  budgetChip = StatusChip.melebihi('Jebol');
                                  budgetProgressColor = AppColors.expenseRed;
                                } else if (topBudget.usagePercentage >= 0.85) {
                                  budgetChip = StatusChip.hampirHabis('Menipis');
                                  budgetProgressColor = AppColors.warningOrange;
                                } else {
                                  budgetChip = StatusChip.aman('Aman');
                                  budgetProgressColor = AppColors.primaryLime;
                                }
                              }
                            } else if (!hasMonthCashflow) {
                              budgetVal = 'Rp0';
                              budgetCap = 'Tidak ada transaksi';
                              budgetProgress = 0.0;
                              budgetChip = const StatusChip(
                                label: '-',
                                type: StatusType.neutral,
                              );
                            }

                            String goalLabel = 'Dana Darurat';
                            String goalVal = 'Mulai Nabung';
                                String goalCap = 'Buat celenganmu di profil';
                                double? goalProgress;
                                GoalEntity? topGoal;
                                IconData goalIcon = PhosphorIcons.shieldCheck(
                                  PhosphorIconsStyle.fill,
                                );
                                Widget goalChip = Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    '0%',
                                    style: AppTypography.smallCaption.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                );

                                if (goalState is GoalLoaded &&
                                    goalState.goals.isNotEmpty) {
                                  final emergencyGoals = goalState.goals
                                      .where((g) =>
                                          g.goalType == GoalType.emergencyFund)
                                      .toList();
                                  topGoal = emergencyGoals.isNotEmpty
                                      ? emergencyGoals.first
                                      : goalState.goals.first;
                                  goalLabel = topGoal.name;
                                  if (topGoal.goalType == GoalType.emergencyFund) {
                                    goalIcon = PhosphorIcons.shieldCheck(
                                      PhosphorIconsStyle.fill,
                                    );
                                  } else {
                                    goalIcon = PhosphorIcons.piggyBank(
                                      PhosphorIconsStyle.fill,
                                    );
                                  }
                                }

                                double effectiveSaved = 0.0;
                                final double targetAmt =
                                    topGoal?.targetAmount ?? 0.0;

                                if (!hasMonthCashflow) {
                                  effectiveSaved = 0.0;
                                  goalVal = 'Rp0';
                                  goalCap = 'Target: Rp0';
                                  goalProgress = 0.0;
                                } else {
                                  effectiveSaved =
                                      topGoal?.currentAmount ?? 0.0;
                                  goalVal =
                                      CurrencyFormatter.format(effectiveSaved);
                                  goalCap = targetAmt > 0
                                      ? 'Target: ${CurrencyFormatter.formatCompact(targetAmt)}'
                                      : (topGoal != null
                                          ? 'Target: Belum diatur'
                                          : 'Buat celenganmu');
                                  goalProgress = targetAmt > 0
                                      ? (effectiveSaved / targetAmt)
                                          .clamp(0.0, 1.0)
                                      : 0.0;
                                }

                                final pct = goalProgress;
                                goalChip = Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    '${(pct * 100).round()}%',
                                    style: AppTypography.smallCaption
                                        .copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                  ),
                                );

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Row 1: Pemasukan & Pengeluaran
                                    SizedBox(
                                      height: 148,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: MetricCard(
                                              cardTheme: MetricCardTheme.lime,
                                              icon: PhosphorIcons.arrowDownLeft(
                                                PhosphorIconsStyle.bold,
                                              ),
                                              label: 'Total Pemasukan',
                                              value: incomeText,
                                              caption: monthSubtitle,
                                              showInfoIcon: false,
                                              statusChip: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusPill,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Masuk',
                                                  style: AppTypography
                                                      .smallCaption
                                                      .copyWith(
                                                        color: AppColors
                                                            .primaryDark,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ),
                                              infoExplanation:
                                                  'Akumulasi dari ${incTxs.length} transaksi pemasukan yang kamu catat pada $currentPeriodLabel dengan total ${CurrencyFormatter.format(mInc)}. Angka ini menjadi dasar patokan batas belanja dan jatah tabunganmu.',
                                              infoFormula:
                                                  '${incTxs.length} Transaksi Masuk = ${CurrencyFormatter.format(mInc)}',
                                              infoTip:
                                                  'Catat pemasukan rutin dan sampingan tepat waktu agar kalkulasi keuanganmu tetap presisi.',
                                              onTap: null,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.cardGap,
                                          ),
                                          Expanded(
                                            child: MetricCard(
                                              cardTheme: MetricCardTheme.dark,
                                              icon: PhosphorIcons.arrowUpRight(
                                                PhosphorIconsStyle.bold,
                                              ),
                                              label: 'Total Pengeluaran',
                                              value: expenseText,
                                              caption: expenseText == 'Rp0'
                                                  ? 'Belum ada belanja'
                                                  : monthSubtitle,
                                              showInfoIcon: false,
                                              statusChip: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusPill,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Keluar',
                                                  style: AppTypography
                                                      .smallCaption
                                                      .copyWith(
                                                        color:
                                                            AppColors.textLight,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 10,
                                                      ),
                                                ),
                                              ),
                                              infoExplanation:
                                                  'Akumulasi dari ${expTxs.length} transaksi pengeluaran atau belanja yang sudah terpakai pada $currentPeriodLabel dengan total ${CurrencyFormatter.format(mExp)}. FinGuard membandingkannya secara real-time dengan jatah belanja dan total pemasukanmu.',
                                              infoFormula:
                                                  '${expTxs.length} Transaksi Keluar = ${CurrencyFormatter.format(mExp)}',
                                              infoTip:
                                                  'Pantau pengeluaran harianmu agar tidak melebihi batas belanja dan tetap memiliki sisa uang dingin.',
                                              onTap: null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.cardGap),
                                    // Row 2: Budget (Pos Belanja) & Goal (Dana Darurat)
                                    SizedBox(
                                      height: 148,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: MetricCard(
                                              cardTheme: MetricCardTheme.dark,
                                              icon: budgetIcon,
                                              label: budgetLabel,
                                              value: budgetVal,
                                              caption: budgetCap,
                                              showInfoIcon: false,
                                              statusChip: budgetChip,
                                              progress: budgetProgress,
                                              progressColor:
                                                  budgetProgressColor,
                                              infoExplanation: !hasMonthCashflow
                                                   ? 'Tidak ada transaksi belanja tercatat pada $currentPeriodLabel.'
                                                   : topBudget != null
                                                  ? 'Jatah belanja untuk kategori "$budgetLabel" dialokasikan sebesar ${CurrencyFormatter.format(topBudget.limitAmount)}. Hingga saat ini telah terpakai ${CurrencyFormatter.format(topBudget.spentAmount)} (${(topBudget.usagePercentage * 100).round()}%). ${topBudget.isExceeded ? 'Pengeluaran telah melebihi batas jatah sebesar ${CurrencyFormatter.format(topBudget.spentAmount - topBudget.limitAmount)}.' : 'Sisa jatah aman yang masih bisa kamu belanjakan adalah ${CurrencyFormatter.format(topBudget.remainingAmount)}.'}'
                                                  : 'Belum ada jatah belanja yang aktif untuk bulan ini. Buka menu Anggaran untuk membagi batas belanja per kategori.',
                                              infoFormula: !hasMonthCashflow
                                                   ? 'Tidak Ada Transaksi'
                                                   : topBudget != null
                                                  ? '${CurrencyFormatter.format(topBudget.limitAmount)} (Jatah) - ${CurrencyFormatter.format(topBudget.spentAmount)} (Terpakai) = ${CurrencyFormatter.format(topBudget.remainingAmount)} (Sisa)'
                                                  : 'Batas Belanja - Belanja Terpakai',
                                              infoTip: topBudget != null && topBudget.isExceeded
                                                  ? 'Rem belanja kategori ini sampai awal bulan berikutnya agar dompet tidak makin boncos.'
                                                  : 'Jika jatah kategori ini menipis, rem belanja yang bersifat keinginan agar tidak boncos.',
                                              onTap: null,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.cardGap,
                                          ),
                                          Expanded(
                                            child: MetricCard(
                                              cardTheme: MetricCardTheme.lime,
                                              icon: goalIcon,
                                              label: goalLabel,
                                              value: goalVal,
                                              caption: goalCap,
                                              showInfoIcon: false,
                                              statusChip: goalChip,
                                              progress: goalProgress,
                                              progressColor:
                                                  AppColors.primaryDark,
                                              infoExplanation: !hasMonthCashflow
                                                  ? 'Tidak ada aktivitas keuangan atau alokasi tabungan tercatat pada $currentPeriodLabel.'
                                                  : (topGoal != null
                                                      ? 'Target celengan "${topGoal.name}" sebesar ${CurrencyFormatter.format(topGoal.targetAmount)}. Saat ini telah terkumpul ${CurrencyFormatter.format(effectiveSaved)} (${(pct * 100).round()}%).'
                                                      : 'Belum ada target tabungan yang diatur.'),
                                              infoFormula: !hasMonthCashflow
                                                  ? 'Tidak Ada Alokasi'
                                                  : (targetAmt > 0
                                                      ? 'Terkumpul ${CurrencyFormatter.format(effectiveSaved)} / Target ${CurrencyFormatter.format(targetAmt)} (${(pct * 100).round()}%)'
                                                      : 'Target Tabungan: Belum Diatur'),
                                               infoTip:
                                                  'Setor sisa uang dingin setiap akhir bulan ke celengan ini agar target cepat tercapai.',
                                              onTap: null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 5. Reactive Dynamic Insight Card with Sparkle Icon
                BlocBuilder<BudgetCubit, BudgetState>(
                  builder: (context, bState) {
                    String alertText =
                        'Dompetmu aman terkendali! Belum ada pos yang jebol bulan ini.';
                    Color iconColor = AppColors.primary;
                    Color iconBg = AppColors.primaryLight;
                    IconData iconData = Icons.auto_awesome_rounded;

                    if (bState is BudgetLoaded) {
                      final overbudgetList = bState.budgets
                          .where((b) => b.spentAmount > b.limitAmount)
                          .toList();
                      if (overbudgetList.isNotEmpty) {
                        final worst = overbudgetList.first;
                        final overAmount =
                            worst.spentAmount - worst.limitAmount;
                        String catTitle = worst.categoryName ?? 'Pos belanja';
                        final uuidRegex = RegExp(
                          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                        );
                        if (uuidRegex.hasMatch(catTitle) ||
                            catTitle.length > 25) {
                          catTitle = 'Pos Belanja';
                        }
                        alertText =
                            '$catTitle melebihi budget ${CurrencyFormatter.format(overAmount)}. Tahan dulu pengeluaran non-esensial.';
                        iconColor = AppColors.warning;
                        iconBg = AppColors.warningTint;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        boxShadow: AppSpacing.softShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alertText,
                                  style: AppTypography.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: () => context.push('/review'),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Cek Evaluasi Bulanan',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
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

                const SizedBox(height: 20),

                // 6. Section "Radar Sinyal Saham (TradingView)"
                const StockSignalDashboardCard(),

                const SizedBox(height: 20),

                // 7. Section "Transaksi terbaru" + link "Lihat semua"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaksi terbaru',
                      style: AppTypography.sectionLabel.copyWith(fontSize: 16),
                    ),
                    InkWell(
                      onTap: () => context.push('/transactions'),
                      child: Text(
                        'Lihat semua',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pure Reactive Transaction rows filtered by selected month
                BlocBuilder<TransactionCubit, TransactionState>(
                  builder: (context, txState) {
                    if (txState is TransactionLoaded) {
                      final monthTxs = txState.transactions.where((t) {
                        return t.transactionDate.year == _selectedMonth.year &&
                            t.transactionDate.month == _selectedMonth.month &&
                            t.status == TransactionStatus.confirmed;
                      }).toList();

                      if (monthTxs.isNotEmpty) {
                        final recent = monthTxs.take(3).toList();
                        return Column(
                          children: [
                            for (int i = 0; i < recent.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _buildTransactionRow(
                                icon:
                                    recent[i].transactionType ==
                                        TransactionType.income
                                    ? Icons.account_balance_wallet_rounded
                                    : Icons.receipt_long_rounded,
                                title: recent[i].note?.isNotEmpty == true
                                    ? recent[i].note!
                                    : (recent[i].category?.name ?? 'Transaksi'),
                                subtitle:
                                    '${recent[i].category?.name ?? (recent[i].transactionType == TransactionType.income ? 'Pemasukan' : 'Pengeluaran')} · ${_formatDateShort(recent[i].transactionDate, recent[i].createdAt)}',
                                amountText: CurrencyFormatter.formatSigned(
                                  recent[i].amount,
                                  isIncome:
                                      recent[i].transactionType ==
                                      TransactionType.income,
                                ),
                                isIncome:
                                    recent[i].transactionType ==
                                    TransactionType.income,
                                onTap: () => context.push('/transactions'),
                              ),
                            ],
                          ],
                        );
                      }
                    }

                    // Zero-Tolerance Clean Empty State
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 36,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isCurrentMonth
                                ? 'Dompet masih sepi nih!'
                                : 'Tidak ada transaksi di periode ini',
                            style: AppTypography.sectionLabel.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCurrentMonth
                                ? 'Catat jajan atau pemasukan lu biar ga boncos akhir bulan.'
                                : 'Belum ada catatan transaksi pada bulan $currentPeriodLabel.',
                            style: AppTypography.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  String _formatDateShort(DateTime dt, [DateTime? createdAt]) {
    final target = createdAt?.toLocal() ?? dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(target.year, target.month, target.day);
    final diffDays = today.difference(itemDay).inDays;

    final timeStr = DateFormatter.formatTime(target);
    if (diffDays == 0) {
      return 'Hari ini, $timeStr';
    }
    if (diffDays == 1) {
      return 'Kemarin, $timeStr';
    }
    return '${DateFormatter.formatShortDayMonth(target)}, $timeStr';
  }

  Widget _buildTransactionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amountText,
    required bool isIncome,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isIncome
                        ? AppColors.successTint
                        : AppColors.surfaceFieldFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isIncome ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.sectionLabel.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? AppColors.success : AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
