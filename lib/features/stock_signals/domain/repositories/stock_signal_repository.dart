import '../../../../core/result/result.dart';
import '../entities/stock_analysis_result.dart';
import '../entities/stock_signal.dart';

abstract class StockSignalRepository {
  /// Fetches the latest stock signals, ordered by creation time descending.
  Future<Result<List<StockSignal>>> getLatestSignals({
    int limit = 10,
    bool forceRefresh = false,
  });

  /// Fetches the latest stock signal for a specific ticker (e.g. 'BBCA').
  Future<Result<StockSignal?>> getSignalByTicker(String ticker);

  /// Performs deep multi-engine stock analysis (Technicals, Bandarmologi, e-IPO, News & Wallet Sync).
  Future<Result<StockAnalysisResult>> analyzeStock(String ticker);
}

