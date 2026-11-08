import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/stock_analysis_result.dart';
import '../../domain/entities/stock_signal.dart';
import '../../domain/repositories/stock_signal_repository.dart';
import '../datasources/stock_signal_remote_data_source.dart';

class StockSignalRepositoryImpl implements StockSignalRepository {
  final StockSignalRemoteDataSource remoteDataSource;

  StockSignalRepositoryImpl(this.remoteDataSource);

  @override
  Future<Result<List<StockSignal>>> getLatestSignals({
    int limit = 5,
    bool forceRefresh = false,
  }) async {
    try {
      final models = await remoteDataSource.getLatestSignals(
        limit: limit,
        forceRefresh: forceRefresh,
      );
      return Success(models);
    } catch (e) {
      return ErrorResult(
        ServerFailure('Gagal memuat sinyal saham: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<StockSignal?>> getSignalByTicker(String ticker) async {
    try {
      final model = await remoteDataSource.getSignalByTicker(ticker);
      return Success(model);
    } catch (e) {
      return ErrorResult(
        ServerFailure('Gagal mencari sinyal saham $ticker: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<StockAnalysisResult>> analyzeStock(String ticker) async {
    try {
      final json = await remoteDataSource.analyzeStock(ticker);
      final result = StockAnalysisResult.fromJson(json);
      return Success(result);
    } catch (e) {
      return ErrorResult(
        ServerFailure('Gagal menganalisis saham $ticker: ${e.toString()}'),
      );
    }
  }
}

