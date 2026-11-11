import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/app/di/injection.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/auth/domain/entities/user_entity.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_state.dart';
import 'package:finguard/features/profile/domain/entities/profile_entity.dart';
import 'package:finguard/features/profile/domain/entities/user_preferences_entity.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_state.dart';
import 'package:finguard/features/profile/presentation/cubit/user_preferences_cubit.dart';
import 'package:finguard/features/profile/presentation/cubit/user_preferences_state.dart';
import 'package:finguard/features/profile/presentation/pages/profile_page.dart';
import 'package:finguard/features/stock_signals/domain/entities/stock_analysis_result.dart';
import 'package:finguard/features/stock_signals/domain/repositories/stock_signal_repository.dart';
import 'package:finguard/features/stock_signals/domain/usecases/analyze_stock.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_analysis_cubit.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_analysis_state.dart';
import 'package:finguard/features/stock_signals/presentation/pages/stock_analysis_page.dart';
import 'package:mocktail/mocktail.dart';

class MockStockSignalRepository extends Mock implements StockSignalRepository {}
class MockAnalyzeStock extends Mock implements AnalyzeStock {}
class MockProfileCubit extends MockCubit<ProfileState> implements ProfileCubit {}
class MockUserPreferencesCubit extends MockCubit<UserPreferencesState> implements UserPreferencesCubit {}
class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleAnalysisResult = StockAnalysisResult(
    ticker: 'DEWA',
    companyName: 'PT Darma Henwa Tbk',
    price: 224,
    currency: 'IDR',
    lastTradeDate: '2026-11-06',
    changePercent: 3.7,
    previousClose: 216,
    volumeLots: 4422328,
    turnoverIdr: 99060147200,
    vwapPrice: 221,
    isIpo: false,
    executiveSummary: const ExecutiveSummary(
      verdict: 'BUY',
      buyPercentage: 72,
      holdPercentage: 18,
      sellPercentage: 10,
      targetPrice: 'Rp 236 - Rp 250',
      stopLoss: 'Rp 214',
      executiveRationale: 'Akumulasi agresif bandar MG & YP pada support MA20.',
    ),
    financialContext: const FinancialContextSummary(
      availableCash: 2975000,
      monthlyFreeCash: 500000,
      emergencyFund: 0,
      lotPrice: 22400,
      affordableLotsFreeCash: 22,
      affordableLotsLiquid: 132,
      walletSyncAdvice: 'Cukup alokasikan 10-20 lot dari uang dingin bulanan.',
    ),
    technicalData: const TechnicalDataSummary(
      rsi: 32.8,
      rsiStatus: 'Oversold',
      sma50: 336.5,
      ma50Status: 'Downtrend',
      peRatio: 18.4,
      pbv: 1.32,
    ),
    bandarmologyData: const BandarmologyDataSummary(
      totalBidLots: 707572,
      totalOfferLots: 379057,
      orderBookSummary: 'Dominan HAKA / Bullish Bid Absorption',
      brokerSummary: 'Top 3 Buyer: MG, YP, YU vs Top 3 Seller: EP, PD, XC',
    ),
    newsHeadlines: const ['Saham DEWA rebound ditopang sektor energi'],
    markdownAnalysis: '### 📊 Analisis Saham DEWA\n\nAkumulasi bandar terpantau solid.',
    timestamp: DateTime.parse('2026-11-06T17:00:00Z'),
  );

  group('StockAnalysisResult Entity Tests', () {
    test('fromJson parses full API response correctly', () {
      final json = {
        'ticker': 'DEWA',
        'company_name': 'PT Darma Henwa Tbk',
        'price': 224.0,
        'currency': 'IDR',
        'last_trade_date': '2026-11-06',
        'change_percent': 3.7,
        'previous_close': 216.0,
        'volume_lots': 4422328,
        'turnover_idr': 99060147200.0,
        'vwap_price': 221.0,
        'is_ipo': false,
        'executive_summary': {
          'verdict': 'BUY',
          'buy_percentage': 72,
          'hold_percentage': 18,
          'sell_percentage': 10,
          'target_price': 'Rp 236 - Rp 250',
          'stop_loss': 'Rp 214',
          'executive_rationale': 'Akumulasi agresif bandar MG & YP.',
        },
        'financial_context': {
          'available_cash': 2975000.0,
          'monthly_free_cash': 500000.0,
          'emergency_fund': 0.0,
          'lot_price': 22400.0,
          'affordable_lots_free_cash': 22,
          'affordable_lots_liquid': 132,
          'wallet_sync_advice': 'Ambil 10-20 lot.',
        },
        'technical_data': {
          'rsi': 32.8,
          'rsi_status': 'Oversold',
          'sma50': 336.5,
          'ma50_status': 'Downtrend',
          'pe_ratio': 18.4,
          'pbv': 1.32,
        },
        'bandarmologi_data': {
          'total_bid_lots': 707572,
          'total_offer_lots': 379057,
          'order_book_summary': 'HAKA dominan',
          'broker_summary': 'Top 3 Buyer: MG, YP, YU',
        },
        'news_headlines': ['Berita DEWA'],
        'markdown_analysis': 'Analisis mendalam',
        'timestamp': '2026-11-06T17:00:00Z',
      };

      final parsed = StockAnalysisResult.fromJson(json);

      expect(parsed.ticker, 'DEWA');
      expect(parsed.price, 224.0);
      expect(parsed.executiveSummary.verdict, 'BUY');
      expect(parsed.executiveSummary.buyPercentage, 72);
      expect(parsed.financialContext.affordableLotsLiquid, 132);
      expect(parsed.technicalData.rsi, 32.8);
      expect(parsed.bandarmologyData.totalBidLots, 707572);
    });
  });

  group('StockAnalysisCubit Tests', () {
    late MockAnalyzeStock mockAnalyzeStock;

    setUp(() {
      mockAnalyzeStock = MockAnalyzeStock();
    });

    blocTest<StockAnalysisCubit, StockAnalysisState>(
      'emits [StockAnalysisLoading, StockAnalysisLoaded] when analyze succeeds',
      build: () {
        when(() => mockAnalyzeStock('DEWA')).thenAnswer((_) async => Success(sampleAnalysisResult));
        return StockAnalysisCubit(mockAnalyzeStock);
      },
      act: (cubit) => cubit.analyze('DEWA'),
      expect: () => [
        isA<StockAnalysisLoading>().having((s) => s.ticker, 'ticker', 'DEWA'),
        isA<StockAnalysisLoaded>().having((s) => s.result.ticker, 'ticker', 'DEWA'),
      ],
    );

    blocTest<StockAnalysisCubit, StockAnalysisState>(
      'emits [StockAnalysisLoading, StockAnalysisError] when analyze fails',
      build: () {
        when(() => mockAnalyzeStock('INVALID')).thenAnswer(
          (_) async => const ErrorResult(ServerFailure('Ticker tidak ditemukan')),
        );
        return StockAnalysisCubit(mockAnalyzeStock);
      },
      act: (cubit) => cubit.analyze('INVALID'),
      expect: () => [
        isA<StockAnalysisLoading>().having((s) => s.ticker, 'ticker', 'INVALID'),
        isA<StockAnalysisError>().having((s) => s.message, 'message', contains('tidak ditemukan')),
      ],
    );
  });

  group('UI StockAnalysisPage & Profile Footer Tests', () {
    late MockProfileCubit mockProfileCubit;
    late MockUserPreferencesCubit mockUserPreferencesCubit;
    late MockAuthCubit mockAuthCubit;

    setUp(() {
      mockProfileCubit = MockProfileCubit();
      mockUserPreferencesCubit = MockUserPreferencesCubit();
      mockAuthCubit = MockAuthCubit();

      when(() => mockProfileCubit.loadProfile()).thenAnswer((_) async {});
      when(() => mockProfileCubit.state).thenReturn(
        ProfileLoaded(
          ProfileEntity(
            id: 'user_1',
            displayName: 'Johan',
            email: 'johan@finguard.id',
            monthlyIncome: 3000000,
            strictnessLevel: 4,
            createdAt: DateTime.now(),
          ),
        ),
      );

      when(() => mockUserPreferencesCubit.loadPreferences()).thenAnswer((_) async {});
      when(() => mockUserPreferencesCubit.state).thenReturn(
        const UserPreferencesLoaded(
          UserPreferencesEntity(
            userId: 'user_1',
            notificationsEnabled: true,
            budgetAlertsEnabled: true,
            stockSignalsEnabled: true,
          ),
        ),
      );

      when(() => mockAuthCubit.state).thenReturn(
        const Authenticated(
          UserEntity(
            id: 'user_1',
            email: 'johan@finguard.id',
            displayName: 'Johan',
          ),
        ),
      );
    });

    testWidgets('ProfilePage displays "Cek & Analisa Saham" menu and johdev copyright footer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileCubit>.value(value: mockProfileCubit),
              BlocProvider<UserPreferencesCubit>.value(value: mockUserPreferencesCubit),
              BlocProvider<AuthCubit>.value(value: mockAuthCubit),
            ],
            child: const Scaffold(body: ProfilePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Cek & Analisa Saham" ListTile exists
      expect(find.text('Cek & Analisa Saham'), findsOneWidget);
      expect(find.text('Analisis teknikal, bandarmologi & kapasitas saldo'), findsOneWidget);

      // Verify johdev copyright footer exists (rendered in SingleChildScrollView)
      expect(find.text('FinGuard v1.0.0+1', skipOffstage: false), findsOneWidget);
      expect(find.text('johdev', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('© 2026 FinGuard', skipOffstage: false), findsOneWidget);
    });

    testWidgets(
      'StockAnalysisPage renders clean bold/italic formatting without raw asterisks and strips duplicate AI disclaimer',
      (tester) async {
        final mockAnalyze = MockAnalyzeStock();
        final resultWithDuplicateDisclaimer = StockAnalysisResult(
          ticker: 'TIFA',
          companyName: 'PT KDB Tifa Finance Tbk',
          price: 274,
          currency: 'IDR',
          lastTradeDate: '2026-11-11',
          changePercent: -1.4,
          previousClose: 278,
          volumeLots: 1200,
          turnoverIdr: 32880000,
          vwapPrice: 275,
          isIpo: false,
          executiveSummary: sampleAnalysisResult.executiveSummary,
          financialContext: sampleAnalysisResult.financialContext,
          technicalData: sampleAnalysisResult.technicalData,
          bandarmologyData: sampleAnalysisResult.bandarmologyData,
          newsHeadlines: const ['Likuiditas pasar saham lapis kedua tetap selektif.'],
          timestamp: DateTime(2026, 11, 11),
          markdownAnalysis: '''
### 5. 💼 Rekomendasi Alokasi Saldo
- **Alokasi Modal**: Fokuskan kas untuk **Dana Darurat** sebelum masuk saham *illiquid* berstatus *downtrend*.

---
⚠️ **Disclaimer Resmi FinGuard**
*Analisis ini dibuat secara independen berdasarkan data pasar modal untuk tujuan edukasi.*''',
        );

        when(() => mockAnalyze('TIFA')).thenAnswer(
          (_) async => Success(resultWithDuplicateDisclaimer),
        );

        if (sl.isRegistered<StockAnalysisCubit>()) {
          sl.unregister<StockAnalysisCubit>();
        }
        sl.registerFactory<StockAnalysisCubit>(() => StockAnalysisCubit(mockAnalyze));

        await tester.pumpWidget(
          const MaterialApp(
            home: StockAnalysisPage(initialTicker: 'TIFA'),
          ),
        );
        await tester.pumpAndSettle();

        // Embedded duplicate markdown disclaimer MUST be stripped completely
        expect(find.textContaining('Disclaimer Resmi FinGuard', skipOffstage: false), findsNothing);
        expect(find.textContaining('Analisis ini dibuat secara independen', skipOffstage: false), findsNothing);

        // Only ONE official footer disclaimer card renders
        expect(find.textContaining('Disclaimer FinGuard:', skipOffstage: false), findsOneWidget);

        // Inline markdown bold/italic renders cleanly without literal asterisks (*illiquid* -> illiquid)
        expect(find.textContaining('*illiquid*', findRichText: true, skipOffstage: false), findsNothing);
        expect(find.textContaining('**Dana Darurat**', findRichText: true, skipOffstage: false), findsNothing);
        expect(find.textContaining('illiquid', findRichText: true, skipOffstage: false), findsOneWidget);

        if (sl.isRegistered<StockAnalysisCubit>()) {
          sl.unregister<StockAnalysisCubit>();
        }
      },
    );
  });
}
