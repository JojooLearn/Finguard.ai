import 'package:equatable/equatable.dart';

enum StockSignalType {
  buy,
  sell,
  hold,
  strongBuy,
  strongSell;

  static StockSignalType fromString(String value) {
    switch (value.toUpperCase().replaceAll(' ', '_')) {
      case 'STRONG_BUY':
        return StockSignalType.strongBuy;
      case 'STRONG_SELL':
        return StockSignalType.strongSell;
      case 'SELL':
        return StockSignalType.sell;
      case 'HOLD':
        return StockSignalType.hold;
      case 'BUY':
      default:
        return StockSignalType.buy;
    }
  }

  String toDbString() {
    switch (this) {
      case StockSignalType.strongBuy:
        return 'STRONG_BUY';
      case StockSignalType.strongSell:
        return 'STRONG_SELL';
      case StockSignalType.sell:
        return 'SELL';
      case StockSignalType.hold:
        return 'HOLD';
      case StockSignalType.buy:
        return 'BUY';
    }
  }

  String get displayName {
    switch (this) {
      case StockSignalType.strongBuy:
        return 'STRONG BUY';
      case StockSignalType.strongSell:
        return 'STRONG SELL';
      case StockSignalType.sell:
        return 'SELL';
      case StockSignalType.hold:
        return 'HOLD';
      case StockSignalType.buy:
        return 'BUY';
    }
  }
}

class StockSignal extends Equatable {
  final String id;
  final String ticker;
  final StockSignalType signalType;
  final double priceAtSignal;
  final String timeframe;
  final String? analysisNotes;
  final DateTime validUntil;
  final DateTime createdAt;

  const StockSignal({
    required this.id,
    required this.ticker,
    required this.signalType,
    required this.priceAtSignal,
    this.timeframe = '1D',
    this.analysisNotes,
    required this.validUntil,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil.toLocal());

  bool get isBuy =>
      signalType == StockSignalType.buy || signalType == StockSignalType.strongBuy;

  bool get isSell =>
      signalType == StockSignalType.sell ||
      signalType == StockSignalType.strongSell;

  bool get isHold => signalType == StockSignalType.hold;

  @override
  List<Object?> get props => [
        id,
        ticker,
        signalType,
        priceAtSignal,
        timeframe,
        analysisNotes,
        validUntil,
        createdAt,
      ];
}

