import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../../transactions/presentation/cubit/transaction_state.dart';
import '../cubit/debt_cubit.dart';
import '../cubit/debt_state.dart';
import '../../domain/entities/debt_entity.dart';

class ActiveDebtsPage extends StatelessWidget {
  const ActiveDebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DebtCubit>(
      create: (_) => sl<DebtCubit>()..loadDebts(),
      child: const _ActiveDebtsView(),
    );
  }
}

class _ActiveDebtsView extends StatefulWidget {
  const _ActiveDebtsView();

  @override
  State<_ActiveDebtsView> createState() => _ActiveDebtsViewState();
}

class _ActiveDebtsViewState extends State<_ActiveDebtsView> {
  int _activeDebtsLimit = 10;
  bool _showAllCompletedDebts = false;

  void _showAddDebtSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final paymentCtrl = TextEditingController();
    final remainingCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final dueDayCtrl = TextEditingController();
    final interestCtrl = TextEditingController();
    DateTime selectedStartDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  'Tambah Cicilan Baru',
                  style: AppTypography.screenTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Catat kewajiban rutin agar rasio beban utang (DSR) tetap terkontrol.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 18),

                // Nama Cicilan
                Text('Nama Cicilan / Utang',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: 'Misal: Cicilan HP, KPR Rumah, Motor',
                    hintStyle: AppTypography.bodySecondary,
                    filled: true,
                    fillColor: AppColors.surfaceFieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cicilan per bulan
                Text('Nominal Cicilan per Bulan',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: paymentCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  style: AppTypography.bigNumber.copyWith(fontSize: 24),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: AppTypography.bigNumber.copyWith(fontSize: 22),
                    hintText: '1.000.000',
                    hintStyle: AppTypography.bigNumber.copyWith(
                      fontSize: 22,
                      color: AppColors.textPlaceholder,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceFieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Tenor Row (Sisa & Total)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sisa Tenor (Bulan)',
                              style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: remainingCtrl,
                            keyboardType: TextInputType.number,
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Misal: 6',
                              hintStyle: AppTypography.bodySecondary,
                              filled: true,
                              fillColor: AppColors.surfaceFieldFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Tenor (Bulan)',
                              style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: totalCtrl,
                            keyboardType: TextInputType.number,
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Misal: 12',
                              hintStyle: AppTypography.bodySecondary,
                              filled: true,
                              fillColor: AppColors.surfaceFieldFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bunga per Tahun & Tanggal Mulai Cicilan
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bunga per Tahun (%)',
                              style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: interestCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              suffixText: '%/thn',
                              suffixStyle: AppTypography.captionText.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              hintText: '0 (Bebas Bunga)',
                              hintStyle: AppTypography.bodySecondary,
                              filled: true,
                              fillColor: AppColors.surfaceFieldFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mulai Cicilan',
                              style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: sheetCtx,
                                initialDate: selectedStartDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedStartDate = picked);
                              }
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceFieldFill,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${selectedStartDate.day}/${selectedStartDate.month}/${selectedStartDate.year}',
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
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
                const SizedBox(height: 14),

                // Due Day
                Text('Tanggal Jatuh Tempo Tiap Bulan',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: dueDayCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: 'Tgl ',
                    prefixStyle: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    hintText: 'Misal: 10',
                    hintStyle: AppTypography.bodySecondary,
                    filled: true,
                    fillColor: AppColors.surfaceFieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Simpan Cicilan',
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final payment = CurrencyInputFormatter.parse(paymentCtrl.text);
                    final remaining = int.tryParse(remainingCtrl.text.trim()) ?? 1;
                    final total = int.tryParse(totalCtrl.text.trim()) ?? remaining;
                    final due = int.tryParse(dueDayCtrl.text.trim()) ?? 10;
                    final annualRate = double.tryParse(
                      interestCtrl.text.replaceAll(',', '.').replaceAll('%', '').trim(),
                    ) ?? 0.0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(content: Text('Masukkan nama cicilan')),
                        );
                      return;
                    }
                    if (payment <= 0) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(content: Text('Nominal cicilan per bulan harus lebih dari 0')),
                        );
                      return;
                    }

                    context.read<DebtCubit>().addDebt(
                          name: name,
                          monthlyPayment: payment,
                          remainingTenor: remaining,
                          totalTenor: total < remaining ? remaining : total,
                          dueDay: due.clamp(1, 31),
                          annualInterestRate: annualRate,
                          startDate: selectedStartDate,
                        );

                    Navigator.pop(sheetCtx);
                    try {
                      context.read<ProfileCubit>().loadProfile();
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmPayInstallment(BuildContext context, DebtEntity debt) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bayar Cicilan Bulan Ini?',
            style: AppTypography.itemTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aksi ini akan mencatat pengeluaran ${CurrencyFormatter.format(debt.monthlyPayment)} ke pos tagihan dan mengurangi sisa tenor ${debt.name} dari ${debt.remainingTenorMonths} bulan menjadi ${debt.remainingTenorMonths - 1} bulan.',
              style: AppTypography.body.copyWith(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.calendarCheck(PhosphorIconsStyle.bold),
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jatuh tempo: Setiap tanggal ${debt.dueDay}',
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await context.read<DebtCubit>().payInstallment(debt.id);
              if (ok && context.mounted) {
                try {
                  context.read<ProfileCubit>().loadProfile();
                } catch (_) {}
                try {
                  context.read<TransactionCubit>().loadTransactions();
                } catch (_) {}
                try {
                  context.read<BudgetCubit>().loadBudgets();
                } catch (_) {}
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(debt.remainingTenorMonths <= 1
                          ? 'Alhamdulillah! Cicilan ${debt.name} telah lunas sepenuhnya!'
                          : 'Pembayaran cicilan ${debt.name} berhasil dicatat!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
              }
            },
            child: const Text('Bayar Sekarang',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Manajemen Cicilan Aktif',
          style: AppTypography.pageHeader,
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: AppIconButton(
            icon: PhosphorIcons.arrowLeft(),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: AppIconButton(
              icon: PhosphorIcons.plus(),
              onPressed: () => _showAddDebtSheet(context),
            ),
          ),
        ],
      ),
      body: BlocBuilder<DebtCubit, DebtState>(
        builder: (context, state) {
          if (state is DebtLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final debts = state is DebtLoaded ? state.debts : <DebtEntity>[];
          final activeDebts =
              debts.where((d) => !d.isCompleted && d.remainingTenorMonths > 0).toList();
          final completedDebts =
              debts.where((d) => d.isCompleted || d.remainingTenorMonths <= 0).toList();

          final totalMonthly = activeDebts.fold<double>(0.0, (s, d) => s + d.monthlyPayment);
          final totalRemaining = activeDebts.fold<double>(0.0, (s, d) => s + d.remainingAmount);

          return BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, profState) {
              double income = 0.0;
              if (profState is ProfileLoaded) {
                income = profState.profile.monthlyIncome;
              }
              try {
                final txState = context.watch<TransactionCubit>().state;
                if (txState is TransactionLoaded) {
                  final now = DateTime.now();
                  final txIncome = txState.transactions
                      .where((tx) =>
                          tx.transactionType == TransactionType.income &&
                          tx.status == TransactionStatus.confirmed &&
                          tx.transactionDate.year == now.year &&
                          tx.transactionDate.month == now.month)
                      .fold<double>(0.0, (s, tx) => s + tx.amount);
                  if (txIncome > income) {
                    income = txIncome;
                  }
                }
              } catch (_) {}

              final dsrPct = income > 0 ? (totalMonthly / income) * 100 : 0.0;
              final isDsrSafe = dsrPct <= 30.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bento Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.darkCardGradient,
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Beban Cicilan Bulanan',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              isDsrSafe
                                  ? StatusChip.aman('DSR ${dsrPct.toStringAsFixed(0)}% (Aman)')
                                  : StatusChip.melebihi('DSR ${dsrPct.toStringAsFixed(0)}% (Tinggi)'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.format(totalMonthly),
                            style: AppTypography.bigNumber.copyWith(
                              color: Colors.white,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(PhosphorIcons.wallet(PhosphorIconsStyle.fill),
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sisa Pokok Utang:',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  CurrencyFormatter.format(totalRemaining),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section: Cicilan Aktif
                    Text(
                      'Cicilan Berjalan (${activeDebts.length})',
                      style: AppTypography.sectionLabel.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 12),

                    if (activeDebts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.incomeGreenBg,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                                    color: AppColors.incomeGreen, size: 28),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text('Bebas Cicilan & Utang',
                                style: AppTypography.itemTitle.copyWith(fontSize: 16)),
                            const SizedBox(height: 6),
                            Text(
                              'Kamu tidak memiliki komitmen cicilan aktif. Seluruh penghasilan bersihmu bebas dialokasikan ke pos tabungan dan investasi.',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...activeDebts
                          .take(_activeDebtsLimit)
                          .map((debt) => _buildDebtCard(context, debt)),
                      if (activeDebts.length > _activeDebtsLimit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _activeDebtsLimit += 10;
                                });
                              },
                              icon: Icon(PhosphorIcons.caretDown(),
                                  size: 15, color: AppColors.primary),
                              label: Text(
                                'Tampilkan ${activeDebts.length - _activeDebtsLimit} cicilan aktif lainnya',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],

                    // Completed Debts Section
                    if (completedDebts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Lunas (${completedDebts.length})',
                            style: AppTypography.sectionLabel
                                .copyWith(fontSize: 15),
                          ),
                          if (completedDebts.length > 5)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showAllCompletedDebts =
                                      !_showAllCompletedDebts;
                                });
                              },
                              child: Text(
                                _showAllCompletedDebts
                                    ? 'Sembunyikan'
                                    : 'Lihat Semua (${completedDebts.length})',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(_showAllCompletedDebts
                              ? completedDebts
                              : completedDebts.take(5))
                          .map((debt) => _buildCompletedCard(context, debt)),
                    ],

                    const SizedBox(height: 36),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtEntity debt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
                      color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      style: AppTypography.itemTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Jatuh tempo tgl ${debt.dueDay} tiap bulan',
                              style: AppTypography.captionText.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text('•',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            )),
                        Text(
                          debt.annualInterestRate > 0
                              ? 'Bunga ${debt.annualInterestRate.toStringAsFixed(debt.annualInterestRate.truncateToDouble() == debt.annualInterestRate ? 0 : 1)}%/thn'
                              : 'Bunga 0%',
                          style: AppTypography.captionText.copyWith(
                            color: debt.annualInterestRate > 0
                                ? AppColors.warningOrange
                                : AppColors.incomeGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
                    size: 18, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'delete') {
                    context.read<DebtCubit>().deleteDebt(debt.id);
                    context.read<ProfileCubit>().loadProfile();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus Cicilan', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar Tenor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tenor: ${debt.totalTenorMonths - debt.remainingTenorMonths} dari ${debt.totalTenorMonths} bln',
                style: AppTypography.captionText.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                'Sisa ${debt.remainingTenorMonths} bulan',
                style: AppTypography.captionText.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: debt.progressRatio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceFieldFill,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),

          // Nominal Breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceFieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kewajiban Bulanan',
                        style: AppTypography.captionText.copyWith(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.format(debt.monthlyPayment)}/bln',
                      style: AppTypography.itemTitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Sisa Utang',
                        style: AppTypography.captionText.copyWith(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(debt.remainingAmount),
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (debt.appliedInterestAmount > 0)
                      Text(
                        'Pokok: ${CurrencyFormatter.format(debt.remainingPrincipal)}',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (debt.appliedInterestAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningTint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warningOrange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.trendUp(PhosphorIconsStyle.bold),
                    color: AppColors.warningOrange,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bunga ${debt.annualInterestRate.toStringAsFixed(0)}%/thn (+${CurrencyFormatter.format(debt.appliedInterestAmount)}) telah bertambah otomatis ke sisa cicilan setelah genap ${debt.appliedYears} tahun.',
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.warningOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmPayInstallment(context, debt),
              icon: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), size: 16),
              label: const Text('Bayar Cicilan Bulan Ini'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primaryDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context, DebtEntity debt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.incomeGreenBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(PhosphorIcons.check(PhosphorIconsStyle.bold),
                  color: AppColors.incomeGreen, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.name, style: AppTypography.itemTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Total ${CurrencyFormatter.format(debt.totalAmount)} (${debt.totalTenorMonths} bulan)',
                  style: AppTypography.captionText.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          StatusChip.aman('Lunas'),
        ],
      ),
    );
  }
}
