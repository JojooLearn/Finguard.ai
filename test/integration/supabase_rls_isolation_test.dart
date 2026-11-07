import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finguard/app/di/injection.dart';
import 'package:finguard/core/config/app_config.dart';
import 'package:finguard/features/auth/domain/repositories/auth_repository.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_cubit.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_state.dart';

class _RealHttpOverrides extends HttpOverrides {}

/// PRD v3.0 Bab 15: Lapis 2 Integration Test (Koneksi Nyata & RLS Isolasi)
/// Menguji kepatuhan Zero-Tolerance RLS (Row Level Security):
/// 1. Verifikasi koneksi live Supabase dan tabel public master categories.
/// 2. User A login/mendaftar, melengkapi data awal, dan mencatat transaksi.
/// 3. User A logout, seluruh state di BLoC/Cubit dibersihkan (Zero Leakage).
/// 4. User B login/mendaftar, kueri database untuk data transaksi User A.
/// 5. Terbukti RLS & State Isolation memblokir akses lintas-akun.
void main() {
  late SupabaseClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    client = Supabase.instance.client;
    await initDependencies();
  });

  tearDownAll(() async {
    await sl.reset();
  });

  group('PRD v3.0 Bab 15 - Real Supabase & RLS Multi-Tenant Isolation Tests', () {
    const testEmailA = 'user_a_finguard@finguard.internal';
    const testEmailB = 'user_b_finguard@finguard.internal';
    const testPassword = 'Password123!Secure';

    test('1. Supabase live connection delivers real master categories', () async {
      final response = await client
          .from('categories')
          .select('id, name')
          .limit(5);

      expect(response, isA<List>());
      final list = response as List;
      if (list.isNotEmpty) {
        expect(list.any((c) => c['name'] == 'Makan & Minum'), isTrue);
      }
    });

    test('2. User A authenticates and records a transaction in app state', () async {
      final authRepo = sl<AuthRepository>();
      final txCubit = sl<TransactionCubit>();

      // Authenticate User A
      var signInResult = await authRepo.signIn(
        email: testEmailA,
        password: testPassword,
      );

      var userA = signInResult.fold((u) => u, (f) {
        return null;
      });

      if (userA == null) {
        final signUpRes = await authRepo.signUp(
          email: testEmailA,
          password: testPassword,
          fullName: 'User A',
        );
        userA = signUpRes.fold((u) => u, (_) => null);
      }

      expect(userA, isNotNull);
      expect(userA!.email, equals(testEmailA));

      // Record transaction for User A
      await txCubit.addTransaction(
        amount: 85000,
        type: TransactionType.expense,
        transactionDate: DateTime.now(),
        categoryId: 'cat_makan',
        accountId: 'acc_wallet',
        note: 'Makan Malam Rahasia User A',
      );

      // Allow Cubit internal async reload to finish with live network response
      if (txCubit.state is TransactionLoading) {
        await txCubit.stream
            .firstWhere((s) => s is! TransactionLoading)
            .timeout(const Duration(seconds: 5));
      }

      // Verify User A can see their transaction
      expect(txCubit.state, isA<TransactionLoaded>());
      final stateA = txCubit.state as TransactionLoaded;
      expect(
        stateA.transactions.any((tx) => tx.note == 'Makan Malam Rahasia User A'),
        isTrue,
      );
    });

    test('3. User A signs out triggers Zero Leakage App State Reset', () async {
      final authRepo = sl<AuthRepository>();
      final txCubit = sl<TransactionCubit>();

      // Sign out User A
      await authRepo.signOut();
      expect(authRepo.getCurrentUser(), isNull);

      // Verify all BLoC/Cubit state is completely reset (Zero-Tolerance Bab 1)
      expect(txCubit.state, isA<TransactionInitial>());
    });

    test('4. User B authenticates and verifies strict cross-account isolation', () async {
      final authRepo = sl<AuthRepository>();
      final txCubit = sl<TransactionCubit>();

      // Authenticate User B
      var signInResultB = await authRepo.signIn(
        email: testEmailB,
        password: testPassword,
      );

      var userB = signInResultB.fold((u) => u, (_) => null);
      if (userB == null) {
        final signUpResB = await authRepo.signUp(
          email: testEmailB,
          password: testPassword,
          fullName: 'User B',
        );
        userB = signUpResB.fold((u) => u, (_) => null);
      }

      expect(userB, isNotNull);
      expect(userB!.email, equals(testEmailB));

      // Load transactions for User B
      await txCubit.loadTransactions();
      if (txCubit.state is TransactionLoading) {
        await txCubit.stream
            .firstWhere((s) => s is! TransactionLoading)
            .timeout(const Duration(seconds: 5));
      }

      // Zero Leakage: User B MUST NOT see User A's transaction
      if (txCubit.state is TransactionLoaded) {
        final stateB = txCubit.state as TransactionLoaded;
        final hasUserATx = stateB.transactions
            .any((tx) => tx.note == 'Makan Malam Rahasia User A');
        expect(hasUserATx, isFalse);
      } else {
        expect(txCubit.state, isA<TransactionInitial>());
      }

      // Clean up User B
      await authRepo.signOut();
    });
  });
}
