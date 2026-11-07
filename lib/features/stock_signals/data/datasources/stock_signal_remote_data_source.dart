import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/stock_signal.dart';
import '../models/stock_signal_model.dart';

abstract class StockSignalRemoteDataSource {
  Future<List<StockSignalModel>> getLatestSignals({int limit = 10});
  Future<StockSignalModel?> getSignalByTicker(String ticker);
  Future<Map<String, dynamic>> analyzeStock(String ticker);
}

class StockSignalRemoteDataSourceImpl implements StockSignalRemoteDataSource {
  final SupabaseClient client;

  StockSignalRemoteDataSourceImpl(this.client);

  static const List<Map<String, dynamic>> _default5Watchlist = [
    {
      'ticker': 'BBCA',
      'signal_type': 'BUY',
      'price_at_signal': 5200.0,
      'timeframe': '1D',
      'analysis_notes': 'Akumulasi di support MA20, RSI netral-bullish',
    },
    {
      'ticker': 'BBRI',
      'signal_type': 'BUY',
      'price_at_signal': 2810.0,
      'timeframe': '1D',
      'analysis_notes': 'Rebound dari support kuat, volume naik',
    },
    {
      'ticker': 'BMRI',
      'signal_type': 'BUY',
      'price_at_signal': 3700.0,
      'timeframe': '1D',
      'analysis_notes': 'Breakout resisten minor, tren uptrend',
    },
    {
      'ticker': 'TLKM',
      'signal_type': 'HOLD',
      'price_at_signal': 2850.0,
      'timeframe': '1D',
      'analysis_notes': 'Konsolidasi di area support kunci',
    },
    {
      'ticker': 'ASII',
      'signal_type': 'BUY',
      'price_at_signal': 5000.0,
      'timeframe': '1D',
      'analysis_notes': 'Uji resisten 5.000, momentum positif',
    },
  ];

  @override
  Future<List<StockSignalModel>> getLatestSignals({int limit = 10}) async {
    try {
      final response = await client
          .from('stock_signals')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final List<StockSignalModel> existing = (response as List)
          .map((json) => StockSignalModel.fromJson(json as Map<String, dynamic>))
          .toList();

      final existingTickers =
          existing.map((s) => s.ticker.toUpperCase()).toSet();
      final missingDefaults = _default5Watchlist
          .where((item) =>
              !existingTickers.contains((item['ticker'] as String).toUpperCase()))
          .toList();

      // If all 5 exist (or none missing), return existing
      if (missingDefaults.isEmpty && existing.isNotEmpty) {
        return existing;
      }

      // If some or all missing, try to auto-seed missing rows to DB
      if (missingDefaults.isNotEmpty) {
        final now = DateTime.now();
        final validUntil = now.add(const Duration(days: 30)).toIso8601String();
        final toInsert = missingDefaults.map((m) => {
              'ticker': m['ticker'],
              'signal_type': m['signal_type'],
              'price_at_signal': m['price_at_signal'],
              'timeframe': m['timeframe'],
              'analysis_notes': m['analysis_notes'],
              'valid_until': validUntil,
              'created_at': now.toIso8601String(),
            }).toList();

        try {
          await client.from('stock_signals').insert(toInsert);
          // Refetch from database so we have valid DB IDs
          final refreshed = await client
              .from('stock_signals')
              .select()
              .order('created_at', ascending: false)
              .limit(limit);
          return (refreshed as List)
              .map((json) =>
                  StockSignalModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } catch (_) {
          // If insert fails (e.g. offline or DB restrictions), supplement with in-memory models
          final fallbackModels = missingDefaults.map((m) {
            return StockSignalModel(
              id: 'local_${m['ticker']}',
              ticker: m['ticker'] as String,
              signalType: StockSignalType.fromString(m['signal_type'] as String),
              priceAtSignal: (m['price_at_signal'] as num).toDouble(),
              timeframe: m['timeframe'] as String? ?? '1D',
              analysisNotes: m['analysis_notes'] as String?,
              validUntil: now.add(const Duration(days: 30)),
              createdAt: now,
            );
          }).toList();
          return [...existing, ...fallbackModels];
        }
      }

      return existing;
    } catch (_) {
      // Offline fallback: provide default 5 watchlist stocks in-memory
      final now = DateTime.now();
      return _default5Watchlist.map((m) {
        return StockSignalModel(
          id: 'local_${m['ticker']}',
          ticker: m['ticker'] as String,
          signalType: StockSignalType.fromString(m['signal_type'] as String),
          priceAtSignal: (m['price_at_signal'] as num).toDouble(),
          timeframe: m['timeframe'] as String? ?? '1D',
          analysisNotes: m['analysis_notes'] as String?,
          validUntil: now.add(const Duration(days: 30)),
          createdAt: now,
        );
      }).toList();
    }
  }

  @override
  Future<StockSignalModel?> getSignalByTicker(String ticker) async {
    final normalized = ticker.trim().toUpperCase();
    try {
      final response = await client
          .from('stock_signals')
          .select()
          .eq('ticker', normalized)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return StockSignalModel.fromJson(response);
      }
    } catch (_) {}

    // Check if it's one of the default 5 watchlist stocks
    final defaultItem = _default5Watchlist.firstWhere(
      (item) => (item['ticker'] as String).toUpperCase() == normalized,
      orElse: () => const {},
    );

    if (defaultItem.isNotEmpty) {
      final now = DateTime.now();
      final validUntil = now.add(const Duration(days: 30)).toIso8601String();
      try {
        final inserted = await client
            .from('stock_signals')
            .insert({
              'ticker': defaultItem['ticker'],
              'signal_type': defaultItem['signal_type'],
              'price_at_signal': defaultItem['price_at_signal'],
              'timeframe': defaultItem['timeframe'],
              'analysis_notes': defaultItem['analysis_notes'],
              'valid_until': validUntil,
              'created_at': now.toIso8601String(),
            })
            .select()
            .single();
        return StockSignalModel.fromJson(inserted);
      } catch (_) {
        return StockSignalModel(
          id: 'local_${defaultItem['ticker']}',
          ticker: defaultItem['ticker'] as String,
          signalType:
              StockSignalType.fromString(defaultItem['signal_type'] as String),
          priceAtSignal: (defaultItem['price_at_signal'] as num).toDouble(),
          timeframe: defaultItem['timeframe'] as String? ?? '1D',
          analysisNotes: defaultItem['analysis_notes'] as String?,
          validUntil: now.add(const Duration(days: 30)),
          createdAt: now,
        );
      }
    }

    return null;
  }

  @override
  Future<Map<String, dynamic>> analyzeStock(String ticker) async {
    final clean = ticker.trim().toUpperCase();
    final res = await client.functions.invoke(
      'analyze-stock',
      body: {'ticker': clean},
    );

    if (res.data != null && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception('Respons analisis saham tidak valid dari server');
  }
}
