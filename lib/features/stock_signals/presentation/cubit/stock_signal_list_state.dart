import 'package:equatable/equatable.dart';
import '../../domain/entities/stock_signal.dart';

abstract class StockSignalListState extends Equatable {
  const StockSignalListState();

  @override
  List<Object?> get props => [];
}

class StockSignalInitial extends StockSignalListState {
  const StockSignalInitial();
}

class StockSignalLoading extends StockSignalListState {
  const StockSignalLoading();
}

class StockSignalLoaded extends StockSignalListState {
  final List<StockSignal> signals;

  const StockSignalLoaded(this.signals);

  @override
  List<Object?> get props => [signals];
}

class StockSignalError extends StockSignalListState {
  final String message;

  const StockSignalError(this.message);

  @override
  List<Object?> get props => [message];
}

