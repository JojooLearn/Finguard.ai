import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../domain/usecases/analyze_stock.dart';
import 'stock_analysis_state.dart';

class StockAnalysisCubit extends Bloc<StockAnalysisEvent, StockAnalysisState> {
  final AnalyzeStock analyzeStockUseCase;
  Timer? _progressTimer;

  static const List<String> _loadingSteps = [
    'Mengumpulkan data harga bursa & OHLCV...',
    'Menghitung indikator teknikal & VWAP...',
    'Menganalisis bandarmologi & antrean order book...',
    'Membaca berita pasar, sentimen & prospektus e-IPO...',
    'Meracik rekomendasi & sinkronisasi saldo dengan AI...',
  ];

  StockAnalysisCubit(this.analyzeStockUseCase)
      : super(const StockAnalysisInitial()) {
    on<_UpdateLoadingStep>((event, emit) {
      if (state is StockAnalysisLoading) {
        emit(StockAnalysisLoading(
          ticker: event.ticker,
          loadingStepMessage: _loadingSteps[event.stepIndex],
          stepIndex: event.stepIndex,
        ));
      }
    });

    on<_ExecuteAnalysis>((event, emit) async {
      final cleanTicker = event.ticker.trim().toUpperCase();
      emit(StockAnalysisLoading(
        ticker: cleanTicker,
        loadingStepMessage: _loadingSteps[0],
        stepIndex: 0,
      ));

      _progressTimer?.cancel();
      int step = 0;
      _progressTimer = Timer.periodic(const Duration(milliseconds: 950), (timer) {
        if (step < _loadingSteps.length - 1) {
          step++;
          add(_UpdateLoadingStep(cleanTicker, step));
        } else {
          timer.cancel();
        }
      });

      final result = await analyzeStockUseCase(cleanTicker);
      _progressTimer?.cancel();

      result.fold(
        (data) => emit(StockAnalysisLoaded(data)),
        (failure) => emit(StockAnalysisError(failure.message, ticker: cleanTicker)),
      );
    });

    on<_ResetAnalysis>((event, emit) {
      _progressTimer?.cancel();
      emit(const StockAnalysisInitial());
    });
  }

  void analyze(String ticker) {
    if (ticker.trim().isEmpty) return;
    add(_ExecuteAnalysis(ticker));
  }

  void reset() {
    add(const _ResetAnalysis());
  }

  @override
  Future<void> close() {
    _progressTimer?.cancel();
    return super.close();
  }
}

abstract class StockAnalysisEvent {
  const StockAnalysisEvent();
}

class _ExecuteAnalysis extends StockAnalysisEvent {
  final String ticker;
  const _ExecuteAnalysis(this.ticker);
}

class _UpdateLoadingStep extends StockAnalysisEvent {
  final String ticker;
  final int stepIndex;
  const _UpdateLoadingStep(this.ticker, this.stepIndex);
}

class _ResetAnalysis extends StockAnalysisEvent {
  const _ResetAnalysis();
}
