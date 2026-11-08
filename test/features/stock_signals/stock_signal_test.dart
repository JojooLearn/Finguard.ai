import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/features/stock_signals/data/datasources/stock_signal_remote_data_source.dart';
import 'package:finguard/features/stock_signals/data/models/stock_signal_model.dart';
import 'package:finguard/features/stock_signals/data/repositories/stock_signal_repository_impl.dart';
import 'package:finguard/features/stock_signals/domain/entities/stock_signal.dart';
import 'package:finguard/features/stock_signals/domain/repositories/stock_signal_repository.dart';
import 'package:finguard/features/stock_signals/domain/usecases/get_latest_signals.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_state.dart';

class MockStockSignalRemoteDataSource implements StockSignalRemoteDataSource {
  bool shouldThrow = false;
  List<StockSignalModel> signals = [];

  @override
  Future<List<StockSignalModel>> getLatestSignals({
    int limit = 5,
    bool forceRefresh = false,
  }) async {
    if (shouldThrow) throw Exception('Network timeout error');
    return signals;
  }

  @override
  Future<StockSignalModel?> getSignalByTicker(String ticker) async {
    if (shouldThrow) throw Exception('Network timeout error');
    try {
      return signals.firstWhere((s) => s.ticker == ticker.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeStock(String ticker) async {
    if (shouldThrow) throw Exception('Network timeout error');
    return {
      'ticker': ticker.toUpperCase(),
      'company_name': 'Sample Company Tbk',
      'price': 5200.0,
      'currency': 'IDR',
      'last_trade_date': '2026-11-06',
      'change_percent': 1.5,
      'previous_close': 5125.0,
      'volume_lots': 150000,
      'turnover_idr': 78000000000.0,
      'vwap_price': 5200.0,
      'is_ipo': false,
      'executive_summary': {
        'verdict': 'BUY',
        'buy_percentage': 75,
        'hold_percentage': 15,
        'sell_percentage': 10,
        'target_price': 'Rp 5.400 - Rp 5.600',
        'stop_loss': 'Rp 4.950',
        'executive_rationale': 'Akumulasi bandar kuat di area support.',
      },
      'financial_context': {
        'available_cash': 10000000.0,
        'monthly_free_cash': 1500000.0,
        'emergency_fund': 4500000.0,
        'lot_price': 520000.0,
        'affordable_lots_free_cash': 2,
        'affordable_lots_liquid': 19,
        'wallet_sync_advice': 'Cukup ambil 2 lot dari uang dingin bulanan.',
      },
      'technical_data': {
        'rsi': 42.5,
        'rsi_status': 'Netral',
        'sma50': 5050.0,
        'ma50_status': 'Uptrend',
        'pe_ratio': 18.5,
        'pbv': 2.1,
      },
      'bandarmologi_data': {
        'total_bid_lots': 120000,
        'total_offer_lots': 80000,
        'order_book_summary': 'HAKA dominan',
        'broker_summary': 'Top 3 Buyer: AK, ZP, BK',
      },
      'news_headlines': ['Kinerja kuartal solid'],
      'markdown_analysis': 'Analisis mendalam sampel',
      'timestamp': '2026-11-06T17:00:00Z',
    };
  }
}

void main() {
  group('StockSignal Entity & Model Tests', () {
    test('StockSignalModel parses JSON correctly with uppercase ticker and local time', () {
      final json = {
        'id': 'sig-123',
        'ticker': 'bbca',
        'signal_type': 'BUY',
        'price_at_signal': 9500.0,
        'timeframe': '1D',
        'analysis_notes': 'RSI Oversold',
        'valid_until': '2026-11-07T12:00:00Z',
        'created_at': '2026-11-06T12:00:00Z',
      };

      final model = StockSignalModel.fromJson(json);

      expect(model.id, 'sig-123');
      expect(model.ticker, 'BBCA'); // uppercase
      expect(model.signalType, StockSignalType.buy);
      expect(model.priceAtSignal, 9500.0);
      expect(model.timeframe, '1D');
      expect(model.analysisNotes, 'RSI Oversold');
      expect(model.isBuy, isTrue);
      expect(model.isSell, isFalse);
      expect(model.isHold, isFalse);
    });

    test('StockSignalType parses various string formats correctly', () {
      expect(StockSignalType.fromString('BUY'), StockSignalType.buy);
      expect(StockSignalType.fromString('SELL'), StockSignalType.sell);
      expect(StockSignalType.fromString('HOLD'), StockSignalType.hold);
      expect(StockSignalType.fromString('STRONG_BUY'), StockSignalType.strongBuy);
      expect(StockSignalType.fromString('STRONG_SELL'), StockSignalType.strongSell);
      expect(StockSignalType.fromString('strong buy'), StockSignalType.strongBuy);
    });

    test('toJson produces valid map matching database expectations', () {
      final model = StockSignalModel(
        id: 'sig-456',
        ticker: 'TLKM',
        signalType: StockSignalType.hold,
        priceAtSignal: 2850.0,
        timeframe: '1D',
        analysisNotes: 'Support MA200',
        validUntil: DateTime.parse('2026-11-07T23:59:59Z'),
        createdAt: DateTime.parse('2026-11-06T08:00:00Z'),
      );

      final json = model.toJson();
      expect(json['ticker'], 'TLKM');
      expect(json['signal_type'], 'HOLD');
      expect(json['price_at_signal'], 2850.0);
      expect(json['timeframe'], '1D');
    });
  });

  group('StockSignalRepositoryImpl Tests', () {
    late MockStockSignalRemoteDataSource mockDataSource;
    late StockSignalRepository repository;

    setUp(() {
      mockDataSource = MockStockSignalRemoteDataSource();
      repository = StockSignalRepositoryImpl(mockDataSource);
    });

    test('getLatestSignals returns Success when data source succeeds', () async {
      mockDataSource.signals = [
        StockSignalModel(
          id: '1',
          ticker: 'BBCA',
          signalType: StockSignalType.buy,
          priceAtSignal: 9500,
          validUntil: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      ];

      final result = await repository.getLatestSignals();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, 1);
      expect(result.dataOrNull?.first.ticker, 'BBCA');
    });

    test('getLatestSignals returns ErrorResult when data source fails', () async {
      mockDataSource.shouldThrow = true;

      final result = await repository.getLatestSignals();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('getSignalByTicker returns correct signal or null', () async {
      mockDataSource.signals = [
        StockSignalModel(
          id: '1',
          ticker: 'GOTO',
          signalType: StockSignalType.sell,
          priceAtSignal: 68,
          validUntil: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      ];

      final result = await repository.getSignalByTicker('goto');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.ticker, 'GOTO');

      final notFound = await repository.getSignalByTicker('UNVR');
      expect(notFound.isSuccess, isTrue);
      expect(notFound.dataOrNull, isNull);
    });
  });

  group('StockSignalListCubit Tests', () {
    late MockStockSignalRemoteDataSource mockDataSource;
    late StockSignalRepository repository;
    late GetLatestSignals getLatestSignals;
    late StockSignalListCubit cubit;

    setUp(() {
      mockDataSource = MockStockSignalRemoteDataSource();
      repository = StockSignalRepositoryImpl(mockDataSource);
      getLatestSignals = GetLatestSignals(repository);
      cubit = StockSignalListCubit(getLatestSignals);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is StockSignalInitial', () {
      expect(cubit.state, const StockSignalInitial());
    });

    test('emits [StockSignalLoading, StockSignalLoaded] when loadSignals succeeds', () async {
      mockDataSource.signals = [
        StockSignalModel(
          id: '1',
          ticker: 'BBCA',
          signalType: StockSignalType.buy,
          priceAtSignal: 9500,
          validUntil: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      ];

      final expectedStates = [
        const StockSignalLoading(),
        isA<StockSignalLoaded>().having(
          (s) => s.signals.first.ticker,
          'ticker',
          'BBCA',
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));
      await cubit.loadSignals();
    });

    test('emits [StockSignalLoading, StockSignalError] when loadSignals fails', () async {
      mockDataSource.shouldThrow = true;

      final expectedStates = [
        const StockSignalLoading(),
        isA<StockSignalError>(),
      ];

      expectLater(cubit.stream, emitsInOrder(expectedStates));
      await cubit.loadSignals();
    });
  });
}
