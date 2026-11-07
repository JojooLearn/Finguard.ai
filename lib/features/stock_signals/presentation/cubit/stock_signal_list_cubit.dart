import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_latest_signals.dart';
import 'stock_signal_list_state.dart';

class StockSignalListCubit extends Cubit<StockSignalListState> {
  final GetLatestSignals getLatestSignals;

  StockSignalListCubit(this.getLatestSignals)
      : super(const StockSignalInitial());

  Future<void> loadSignals({int limit = 10}) async {
    emit(const StockSignalLoading());
    final result = await getLatestSignals(limit: limit);

    result.fold(
      (signals) => emit(StockSignalLoaded(signals)),
      (failure) => emit(StockSignalError(failure.message)),
    );
  }

  Future<void> refresh() => loadSignals();
}

