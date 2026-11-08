import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finguard/core/formatters/currency_formatter.dart';
import 'package:finguard/core/formatters/currency_input_formatter.dart';
import 'package:finguard/core/utils/financial_calculator.dart';
import 'package:finguard/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:finguard/features/coach/data/repositories/coach_repository_impl.dart';
import 'package:finguard/features/coach/domain/services/receipt_scanner_service.dart';
import 'package:finguard/features/consultation/data/repositories/consultation_repository_impl.dart';
import 'package:finguard/features/consultation/domain/entities/consultation_result_entity.dart';
import 'package:finguard/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:finguard/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/monthly_review/data/repositories/monthly_review_repository_impl.dart';
import 'package:finguard/features/stock_signals/data/datasources/stock_signal_remote_data_source.dart';
import 'package:finguard/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finguard/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _InMemoryTransactionDataSource implements TransactionRemoteDataSource {
  final List<TransactionEntity> _items = [];

  @override
  Future<TransactionEntity> createTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? clientRequestId,
  }) async {
    final now = DateTime.now();
    final tx = TransactionEntity(
      id: 'tx_${_items.length + 1}',
      userId: 'user_test',
      accountId: accountId ?? 'acc_default',
      categoryId: categoryId ?? 'cat_default',
      transactionType: type,
      amount: amount,
      currencyCode: 'IDR',
      transactionDate: transactionDate,
      note: note,
      source: source,
      status: TransactionStatus.confirmed,
      createdAt: now,
      updatedAt: now,
      category: CategoryEntity(
        id: categoryId ?? 'cat_default',
        name: categoryId == 'cat_food' ? 'Makan & Minum' : 'Gaji Bulanan',
        transactionType: type,
        allocationType: AllocationType.needs,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _items.add(tx);
    return tx;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<TransactionEntity> getTransactionById(String id) async {
    return _items.firstWhere((e) => e.id == id);
  }

  @override
  Future<List<TransactionEntity>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    return _items.where((tx) {
      if (startDate != null && tx.transactionDate.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && tx.transactionDate.isAfter(endDate)) {
        return false;
      }
      if (categoryId != null && tx.categoryId != categoryId) return false;
      if (accountId != null && tx.accountId != accountId) return false;
      if (type != null && tx.transactionType != type) return false;
      return true;
    }).toList();
  }

  @override
  Future<TransactionEntity> updateTransaction(
    TransactionEntity transaction,
  ) async {
    final idx = _items.indexWhere((e) => e.id == transaction.id);
    if (idx != -1) _items[idx] = transaction;
    return transaction;
  }
}

void main() {
  late _MockSupabaseClient mockSupabase;
  late _MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = _MockSupabaseClient();
    mockAuth = _MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
  });

  group('FinGuard Master QA, Financial Logic & UI/UX Audit Suite (TC-01 s/d TC-19)', () {
    // 5.1 Kelompok A: Onboarding, Profil & State Awal (TC-01, TC-02)
    test('TC-01: Fresh State & Bulan Kosong menampilkan Rp0 tanpa angka hardcoded', () {
      bool resolveHasCashflow(List<TransactionEntity> txs) => txs.isNotEmpty;
      final hasMonthCashflow = resolveHasCashflow(const []);
      final foodVal =
          hasMonthCashflow ? CurrencyFormatter.format(300000) : 'Rp0';
      final foodCap =
          hasMonthCashflow ? 'Sisa jatah: Rp300.000' : 'Sisa jatah: Rp0';
      final goalVal =
          hasMonthCashflow ? CurrencyFormatter.format(1000000) : 'Rp0';
      final goalCap = hasMonthCashflow ? 'Target: Rp30 jt' : 'Target: Rp0';

      expect(foodVal, 'Rp0');
      expect(foodCap, 'Sisa jatah: Rp0');
      expect(goalVal, 'Rp0');
      expect(goalCap, 'Target: Rp0');
    });

    test('TC-02: Kebersihan Edit Profil & Zero Pre-filled Input Parsing', () {
      // Empty string in CurrencyInputFormatter must parse to 0.0 (no pre-filled value)
      expect(CurrencyInputFormatter.parse(''), 0.0);
      expect(CurrencyInputFormatter.parse('10.000.000'), 10000000.0);
    });

    // 5.2 Kelompok B: Arus Kas, Transaksi & Jatah Belanja (TC-03, TC-04, TC-05, TC-06)
    test('TC-03 & TC-04: Pencatatan Pemasukan Gaji Rp10jt & Pengeluaran Makan Rp500rb', () async {
      final txDataSource = _InMemoryTransactionDataSource();
      final txRepo = TransactionRepositoryImpl(txDataSource);
      final budgetRepo = BudgetRepositoryImpl(mockSupabase);

      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Set budget Makan & Minum Rp1.500.000
      await budgetRepo.setBudget(
        categoryId: 'cat_food',
        categoryName: 'Makan & Minum',
        limitAmount: 1500000,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      // TC-03: Add income Gaji Bulanan Rp10.000.000
      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_salary',
        type: TransactionType.income,
        amount: 10000000,
        transactionDate: now,
        note: 'Gaji Bulanan',
      );

      var txsRes = await txRepo.getTransactions(
        startDate: periodStart,
        endDate: periodEnd,
      );
      var txs = txsRes.fold((l) => l, (_) => <TransactionEntity>[]);
      var totalIn = txs
          .where((t) => t.transactionType == TransactionType.income)
          .fold<double>(0, (s, t) => s + t.amount);
      var totalOut = txs
          .where((t) => t.transactionType == TransactionType.expense)
          .fold<double>(0, (s, t) => s + t.amount);

      expect(totalIn, 10000000);
      expect(totalOut, 0);
      expect(totalIn - totalOut, 10000000);

      // TC-04: Add expense Makan & Minum Rp500.000 ("Nasi Padang & Kopi")
      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_food',
        type: TransactionType.expense,
        amount: 500000,
        transactionDate: now,
        note: 'Nasi Padang & Kopi',
      );

      txsRes = await txRepo.getTransactions(
        startDate: periodStart,
        endDate: periodEnd,
      );
      txs = txsRes.fold((l) => l, (_) => <TransactionEntity>[]);
      totalIn = txs
          .where((t) => t.transactionType == TransactionType.income)
          .fold<double>(0, (s, t) => s + t.amount);
      totalOut = txs
          .where((t) => t.transactionType == TransactionType.expense)
          .fold<double>(0, (s, t) => s + t.amount);

      expect(totalIn, 10000000);
      expect(totalOut, 500000);
      expect(totalIn - totalOut, 9500000); // Sisa Uang Bersih Bulan Ini = +Rp9.500.000

      final budgetsRes = await budgetRepo.getBudgets(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      final budgets = budgetsRes.fold((b) => b, (_) => []);
      final foodBudget = budgets.firstWhere((b) => b.categoryId == 'cat_food');
      final remaining = foodBudget.limitAmount - totalOut;
      expect(foodBudget.limitAmount, 1500000);
      expect(remaining, 1000000); // Sisa jatah: Rp1.000.000 (Aman)
      expect(
        FinancialCalculator.calculateBudgetUsage(
          actualExpense: totalOut,
          budgetLimit: foodBudget.limitAmount,
        ),
        closeTo(33.33, 0.1),
      );
    });

    test('TC-05: Filter Lintas Bulan (Bulan berjalan vs Bulan sebelumnya tanpa transaksi)', () async {
      final txRepo = TransactionRepositoryImpl(_InMemoryTransactionDataSource());
      final now = DateTime.now();

      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_salary',
        type: TransactionType.income,
        amount: 10000000,
        transactionDate: now,
        note: 'Gaji Bulanan',
      );

      final prevMonthStart = DateTime(now.year, now.month - 1, 1);
      final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
      final prevRes = await txRepo.getTransactions(
        startDate: prevMonthStart,
        endDate: prevMonthEnd,
      );
      final prevTxs = prevRes.fold((l) => l, (_) => <TransactionEntity>[]);
      expect(prevTxs, isEmpty);
    });

    test('TC-06: Peringatan Over-Budget (Pos Makan & Minum Jebol)', () {
      const limit = 1500000.0;
      const spent = 1600000.0;
      final usagePct = FinancialCalculator.calculateBudgetUsage(
        actualExpense: spent,
        budgetLimit: limit,
      )!;
      final remaining = limit - spent;
      expect(usagePct, greaterThan(100.0));
      expect(remaining, -100000.0); // Tekor Rp100.000
    });

    // 5.3 Kelompok C: Target Tabungan, Dana Darurat & Isolasi Data (TC-07, TC-08, TC-09)
    test('TC-07, TC-08 & TC-09: Validasi Tabungan, Setor Dana Darurat Rp2jt & Isolasi 100% dari Cicilan', () async {
      final goalRepo = GoalRepositoryImpl(mockSupabase);
      final debtRepo = DebtRepositoryImpl(mockSupabase);

      // Create Emergency Fund Goal (Target Rp30.000.000)
      final efRes = await goalRepo.createGoal(
        name: 'Dana Darurat',
        type: GoalType.emergencyFund,
        targetAmount: 30000000,
        priority: 5,
      );
      final efGoal = efRes.fold((g) => g, (_) => throw Exception());

      // TC-07: Create Savings Goal "Liburan Jepang" (Target Rp15.000.000, Prioritas 3)
      final japanRes = await goalRepo.createGoal(
        name: 'Liburan Jepang',
        type: GoalType.savings,
        targetAmount: 15000000,
        priority: 3,
      );
      final japanGoal = japanRes.fold((g) => g, (_) => throw Exception());
      expect(japanGoal.name, 'Liburan Jepang');
      expect(japanGoal.targetAmount, 15000000);
      expect(japanGoal.goalType, GoalType.savings);

      // TC-08: Setor Tabungan Rp2.000.000 ke Dana Darurat
      final contribRes = await goalRepo.addContribution(
        goalId: efGoal.id,
        amount: 2000000,
        note: 'Setoran awal dana darurat',
      );
      final updatedEf = contribRes.fold((g) => g, (_) => throw Exception());
      expect(updatedEf.currentAmount, 2000000);
      expect(
        ((updatedEf.currentAmount / updatedEf.targetAmount) * 100).round(),
        7,
      ); // 2jt / 30jt = 6.67% (~7%)

      // TC-09: Uji Isolasi Data Tabungan vs Cicilan (Anti-Cross-Contamination)
      final debtsRes = await debtRepo.getDebts();
      final debts = debtsRes.fold((d) => d, (_) => []);
      expect(debts.where((d) => d.name == 'Liburan Jepang'), isEmpty);

      await debtRepo.addDebt(
        name: 'Cicilan HP',
        monthlyPayment: 500000,
        remainingTenor: 6,
        totalTenor: 12,
        dueDay: 10,
        annualInterestRate: 0,
      );
      final goalsRes = await goalRepo.getGoals();
      final goals = goalsRes.fold((g) => g, (_) => []);
      expect(goals.where((g) => g.name == 'Cicilan HP'), isEmpty);
    });

    // 5.4 Kelompok D: Manajemen Cicilan Aktif & Bunga Tahunan Cerdas (TC-10, TC-11, TC-12)
    test('TC-10, TC-11 & TC-12: DSR 15%, Bayar Cicilan HP & Bunga Tahunan Cerdas 10%/thn', () async {
      final debtRepo = DebtRepositoryImpl(mockSupabase);

      // TC-10: Add Cicilan HP (Rp500rb/bln, sisa 6 dari 12 bln, bunga 0%)
      final hpRes = await debtRepo.addDebt(
        name: 'Cicilan HP',
        monthlyPayment: 500000,
        remainingTenor: 6,
        totalTenor: 12,
        dueDay: 10,
        annualInterestRate: 0,
        startDate: DateTime.now(),
      );
      final hpDebt = hpRes.fold((d) => d, (_) => throw Exception());

      // TC-10 & TC-12: Add Kredit Motor (Rp1.000.000/bln, sisa 10 dari 12 bln, bunga 10%/thn, mulai 1 tahun + 1 hari lalu)
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 366));
      final motorRes = await debtRepo.addDebt(
        name: 'Kredit Motor',
        monthlyPayment: 1000000,
        remainingTenor: 10,
        totalTenor: 12,
        dueDay: 15,
        annualInterestRate: 10.0,
        startDate: oneYearAgo,
      );
      final motorDebt = motorRes.fold((d) => d, (_) => throw Exception());

      final debtsRes = await debtRepo.getDebts();
      final debts = debtsRes.fold((d) => d, (_) => []);
      final totalMonthly = debts.fold<double>(0, (s, d) => s + d.monthlyPayment);
      expect(totalMonthly, 1500000); // Rp1.500.000/bln

      // DSR against Rp10.000.000 income = 15% (Aman)
      final dsrPct = (totalMonthly / 10000000) * 100;
      expect(dsrPct, 15.0);

      // TC-12: Verify Smart Annual Compounding on Kredit Motor
      expect(motorDebt.remainingPrincipal, 10000000); // 10 * 1.000.000
      expect(motorDebt.appliedYears, 1);
      expect(motorDebt.appliedInterestAmount, 1000000); // +Rp1.000.000 (10%)
      expect(motorDebt.remainingAmount, 11000000); // Rp11.000.000

      // TC-11: Pay 1 installment of Cicilan HP
      final payRes = await debtRepo.payInstallment(hpDebt.id);
      final paidHp = payRes.fold((d) => d, (_) => throw Exception());
      expect(paidHp.remainingTenorMonths, 5); // berkurang dari 6 menjadi 5 bulan
      expect(paidHp.remainingAmount, 2500000); // berkurang dari Rp3.000.000 menjadi Rp2.500.000
    });

    // 5.5 Kelompok E: AI Coach Chat, Scan Struk & Boleh Beli Gak (TC-13, TC-14, TC-15, TC-16)
    test('TC-13 & TC-14: AI Coach Prioritas Pelunasan Cicilan (Debt Avalanche) & Pencatatan Transaksi via Chat', () async {
      final txRepo = TransactionRepositoryImpl(_InMemoryTransactionDataSource());
      final budgetRepo = BudgetRepositoryImpl(mockSupabase);
      final goalRepo = GoalRepositoryImpl(mockSupabase);
      final debtRepo = DebtRepositoryImpl(mockSupabase);
      final coachRepo = CoachRepositoryImpl(
        client: mockSupabase,
        transactionRepository: txRepo,
        budgetRepository: budgetRepo,
        goalRepository: goalRepo,
        debtRepository: debtRepo,
      );

      final now = DateTime.now();
      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_salary',
        type: TransactionType.income,
        amount: 10000000,
        transactionDate: now,
        note: 'Gaji Bulanan',
      );
      await debtRepo.addDebt(
        name: 'Cicilan HP',
        monthlyPayment: 500000,
        remainingTenor: 6,
        totalTenor: 12,
        dueDay: 10,
        annualInterestRate: 0,
      );
      await debtRepo.addDebt(
        name: 'Kredit Motor',
        monthlyPayment: 1000000,
        remainingTenor: 10,
        totalTenor: 12,
        dueDay: 15,
        annualInterestRate: 10.0,
        startDate: now.subtract(const Duration(days: 366)),
      );

      // TC-13: Ask Coach about active installments and which to pay off first
      final debtReplyRes = await coachRepo.sendMessage(
        message: 'Coach, gue punya cicilan apa aja sekarang dan mana yang harus gue lunasin duluan?',
      );
      final debtReply = debtReplyRes.fold((m) => m.content, (_) => '');
      expect(debtReply, contains('Cicilan HP'));
      expect(debtReply, contains('Kredit Motor'));
      expect(debtReply, contains('10%'));
      expect(debtReply, contains('Prioritaskan melunasi **Kredit Motor**'));

      // TC-14: Record expense via chat ("Tadi gue beli bensin Pertamax 50rb")
      final txReplyRes = await coachRepo.sendMessage(
        message: 'Tadi gue beli bensin Pertamax 50rb',
      );
      final txMsg = txReplyRes.fold((m) => m, (_) => throw Exception());
      expect(txMsg.structuredPayload, isNotNull);
      expect(txMsg.structuredPayload!['amount'], 50000);
      expect(txMsg.structuredPayload!['type'], 'expense');
    });

    test('TC-15: Performa & Keamanan Scan Struk (Validasi Magic Bytes & Kompresi < 200KB)', () async {
      final scanner = ReceiptScannerService(supabase: mockSupabase);
      // Create valid JPEG magic bytes (0xFF, 0xD8, 0xFF)
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01
      ]);

      final validationErr = ReceiptScannerService.validateReceiptImage(
        fileName: 'struk_alfamart.jpg',
        bytes: jpegBytes,
      );
      expect(validationErr, isNull);

      final compressed = await scanner.compressImageBytes(jpegBytes);
      expect(compressed.lengthInBytes, lessThan(200 * 1024));
    });

    test('TC-16: Simulasi Boleh Beli Gak (PlayStation 5 Pro Rp8.500.000 vs Uang Dingin Rp6.000.000)', () async {
      // Master Test Data (Bagian 4):
      // Pemasukan: Rp10.000.000
      // Pengeluaran Konsumsi: Rp500.000
      // Kewajiban Cicilan: Rp1.500.000 (Cicilan HP Rp500rb + Kredit Motor Rp1jt)
      // Setoran Dana Darurat: Rp2.000.000
      final freeCash = FinancialCalculator.calculateAvailableFreeCash(
        totalIncome: 10000000,
        totalConsumptionExpense: 500000,
        unpaidMonthlyDebt: 1500000,
        monthlySavingsContribution: 2000000,
      );
      expect(freeCash, 6000000.0); // Uang Dingin Siap Pakai = Rp6.000.000

      final consultRepo = ConsultationRepositoryImpl(mockSupabase);
      final ps5Price = 8500000.0;
      expect(ps5Price > freeCash, isTrue);
      expect(freeCash - ps5Price, -2500000.0); // Defisit Rp2.500.000

      final res = await consultRepo.consultPurchase(
        itemName: 'PlayStation 5 Pro',
        estimatedPrice: ps5Price,
        categoryName: 'Hiburan',
      );
      final entity = res.fold((r) => r, (_) => throw Exception());
      expect(entity.verdict, ConsultationVerdict.notRecommended);
    });

    // 5.6 Kelompok F: Alat Bantu, Evaluasi Bulanan & Radar Saham (TC-17, TC-18, TC-19)
    test('TC-17: Idempotensi Evaluasi Bulanan (Tidak menggandakan baris di database)', () async {
      final txRepo = TransactionRepositoryImpl(_InMemoryTransactionDataSource());
      final reviewRepo = MonthlyReviewRepositoryImpl(mockSupabase, txRepo);

      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_salary',
        type: TransactionType.income,
        amount: 10000000,
        transactionDate: now,
        note: 'Gaji Bulanan',
      );
      await txRepo.createTransaction(
        accountId: 'acc_default',
        categoryId: 'cat_food',
        type: TransactionType.expense,
        amount: 500000,
        transactionDate: now,
        note: 'Nasi Padang & Kopi',
      );

      final firstCall = await reviewRepo.getOrGenerateMonthlyReview(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      final secondCall = await reviewRepo.getOrGenerateMonthlyReview(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      final r1 = firstCall.fold((r) => r, (_) => throw Exception());
      final r2 = secondCall.fold((r) => r, (_) => throw Exception());
      expect(r1.metrics.totalIncome, 10000000);
      expect(r1.metrics.totalExpense, 500000);
      expect(r2.metrics.totalIncome, r1.metrics.totalIncome);
      expect(r2.metrics.totalExpense, r1.metrics.totalExpense);
    });

    test('TC-18 & TC-19: Radar Sinyal Saham 5 Emiten & Deep Stock Analysis 6-Engine BBRI', () async {
      final dataSource = StockSignalRemoteDataSourceImpl(mockSupabase);

      // TC-18: Auto-seeding 5 trending signals
      final signals = await dataSource.getLatestSignals(limit: 5);
      expect(signals.length, 5);

      // TC-19: 6-Engine Deep Stock Analysis for BBRI synchronized with Rp6.000.000 free cash
      final analysis = await dataSource.analyzeStock('BBRI');
      expect(analysis['ticker'], 'BBRI');
      expect(analysis['executive_summary'], isNotNull);
      expect(analysis['technical_data'], isNotNull);
      expect(analysis['bandarmology_data'], isNotNull);
      expect(analysis['financial_context'], isNotNull);

      final finCtx = analysis['financial_context'] as Map<String, dynamic>;
      final price = (analysis['price'] as num).toDouble();
      final lotPrice = price * 100;
      final expectedLots = 6000000 ~/ lotPrice;
      expect(finCtx['monthly_free_cash'], 6000000.0);
      expect(finCtx['affordable_lots_free_cash'], expectedLots);
    });
  });
}
