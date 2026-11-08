import '../../../../core/result/result.dart';
import '../entities/stock_signal.dart';
import '../repositories/stock_signal_repository.dart';

class GetLatestSignals {
  final StockSignalRepository repository;

  GetLatestSignals(this.repository);

  Future<Result<List<StockSignal>>> call({
    int limit = 5,
    bool forceRefresh = false,
  }) {
    return repository.getLatestSignals(
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }
}

