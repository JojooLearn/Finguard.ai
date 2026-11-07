import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_signal_model.dart';

abstract class StockSignalRemoteDataSource {
  Future<List<StockSignalModel>> getLatestSignals({int limit = 10});
  Future<StockSignalModel?> getSignalByTicker(String ticker);
  Future<Map<String, dynamic>> analyzeStock(String ticker);
}

class StockSignalRemoteDataSourceImpl implements StockSignalRemoteDataSource {
  final SupabaseClient client;

  StockSignalRemoteDataSourceImpl(this.client);

  @override
  Future<List<StockSignalModel>> getLatestSignals({int limit = 10}) async {
    final response = await client
        .from('stock_signals')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => StockSignalModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StockSignalModel?> getSignalByTicker(String ticker) async {
    final normalized = ticker.trim().toUpperCase();
    final response = await client
        .from('stock_signals')
        .select()
        .eq('ticker', normalized)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return StockSignalModel.fromJson(response);
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
