import '../../../../core/result/result.dart';
import '../entities/stock_analysis_result.dart';
import '../repositories/stock_signal_repository.dart';

class AnalyzeStock {
  final StockSignalRepository repository;

  AnalyzeStock(this.repository);

  Future<Result<StockAnalysisResult>> call(String ticker) {
    return repository.analyzeStock(ticker);
  }
}

