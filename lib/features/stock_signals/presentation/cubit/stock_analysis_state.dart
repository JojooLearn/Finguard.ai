import 'package:equatable/equatable.dart';
import '../../domain/entities/stock_analysis_result.dart';

abstract class StockAnalysisState extends Equatable {
  const StockAnalysisState();

  @override
  List<Object?> get props => [];
}

class StockAnalysisInitial extends StockAnalysisState {
  const StockAnalysisInitial();
}

class StockAnalysisLoading extends StockAnalysisState {
  final String ticker;
  final String loadingStepMessage;
  final int stepIndex; // 0 to 4

  const StockAnalysisLoading({
    required this.ticker,
    required this.loadingStepMessage,
    this.stepIndex = 0,
  });

  @override
  List<Object?> get props => [ticker, loadingStepMessage, stepIndex];
}

class StockAnalysisLoaded extends StockAnalysisState {
  final StockAnalysisResult result;

  const StockAnalysisLoaded(this.result);

  @override
  List<Object?> get props => [result];
}

class StockAnalysisError extends StockAnalysisState {
  final String message;
  final String? ticker;

  const StockAnalysisError(this.message, {this.ticker});

  @override
  List<Object?> get props => [message, ticker];
}

