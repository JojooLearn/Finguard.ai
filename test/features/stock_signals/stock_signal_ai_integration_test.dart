import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:finguard/core/config/app_config.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  late SupabaseClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    client = Supabase.instance.client;
  });

  group('Revision 2 DoD - On-Demand Stock Engine Integration Tests', () {
    test('DoD 1, 2, 3, 4: On-demand engine fetches BBNI with RSI, MA50, Fundamental in < 8s', () async {
      final authRes = await client.auth.signInWithPassword(
        email: 'user_a_finguard@finguard.internal',
        password: 'Password123!Secure',
      );
      expect(authRes.user, isNotNull);

      final stopwatch = Stopwatch()..start();

      final response = await client.functions.invoke(
        'coach-chat',
        body: {
          'message': 'Bagaimana saham BBNI hari ini?',
          'client_date': '2026-11-06',
          'client_request_id': const Uuid().v4(),
        },
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      expect(response.status, 200);
      final data = response.data as Map<String, dynamic>;
      expect(data['intent'], 'query_stock_signal');

      final reply = (data['reply'] as String).toLowerCase();

      // DoD 4: Latency under 8 seconds
      expect(
        elapsedMs,
        lessThan(8000),
        reason: 'Latency must be under 8 seconds (elapsed: ${elapsedMs}ms)',
      );

      // Mentions ticker BBNI
      expect(reply.contains('bbni') || reply.contains('bank negara indonesia'), isTrue);

      // DoD 2 & 3: Reflects server technical indicators (RSI and/or MA50)
      expect(
        reply.contains('rsi') ||
            reply.contains('oversold') ||
            reply.contains('overbought') ||
            reply.contains('ma50') ||
            reply.contains('moving average') ||
            reply.contains('trend') ||
            reply.contains('uptrend') ||
            reply.contains('downtrend'),
        isTrue,
        reason: 'Reply must reflect server technical analysis: $reply',
      );

      // Fundamental / Price
      expect(
        reply.contains('rp') ||
            reply.contains('p/e') ||
            reply.contains('pe') ||
            reply.contains('pbv') ||
            reply.contains('harga') ||
            reply.contains('3.400') ||
            reply.contains('3400'),
        isTrue,
        reason: 'Reply must include price or fundamental metrics: $reply',
      );

      // Mandatory risk disclaimer
      expect(
        reply.contains('risiko') ||
            reply.contains('disclaimer') ||
            reply.contains('bukan jaminan') ||
            reply.contains('fomo') ||
            reply.contains('keputusan'),
        isTrue,
        reason: 'AI reply must contain the mandatory risk disclaimer',
      );
    });

    test('Priority 1 + On-Demand: BBCA uses local signal and on-demand market data', () async {
      final response = await client.functions.invoke(
        'coach-chat',
        body: {
          'message': 'Gimana sinyal saham BBCA hari ini?',
          'client_date': '2026-11-06',
          'client_request_id': const Uuid().v4(),
        },
      );

      expect(response.status, 200);
      final data = response.data as Map<String, dynamic>;
      expect(data['intent'], 'query_stock_signal');

      final reply = (data['reply'] as String).toLowerCase();
      // Should mention BBCA
      expect(reply.contains('bbca'), isTrue);
      // Mentions technical signal (BUY/beli)
      expect(reply.contains('buy') || reply.contains('beli'), isTrue);

      // Mandatory risk disclaimer
      expect(
        reply.contains('risiko') ||
            reply.contains('disclaimer') ||
            reply.contains('bukan jaminan') ||
            reply.contains('fomo') ||
            reply.contains('indikator teknikal'),
        isTrue,
        reason: 'AI reply must contain the mandatory risk disclaimer',
      );
    });

    test('DoD 5: Invalid ticker INVALIDXYZ handled gracefully without crash', () async {
      final response = await client.functions.invoke(
        'coach-chat',
        body: {
          'message': 'Gimana analisa saham INVALIDXYZ999?',
          'client_date': '2026-11-06',
          'client_request_id': const Uuid().v4(),
        },
      );

      expect(response.status, 200);
      final data = response.data as Map<String, dynamic>;
      expect(data['intent'], isNotNull);
      final reply = (data['reply'] as String).toLowerCase();
      expect(reply.isNotEmpty, isTrue);
      // Explains data not accessible or ticker not found
      expect(
        reply.contains('tidak') ||
            reply.contains('belum') ||
            reply.contains('gak') ||
            reply.contains('ga') ||
            reply.contains('ditemukan') ||
            reply.contains('diakses'),
        isTrue,
        reason: 'Should explain gracefully that data is not accessible: $reply',
      );
    });

    test('User Query: Rekomendasi saham berdasarkan pemasukan & dana riil di database', () async {
      final authRes = await client.auth.signInWithPassword(
        email: 'user_a_finguard@finguard.internal',
        password: 'Password123!Secure',
      );
      expect(authRes.user, isNotNull);

      final response = await client.functions.invoke(
        'coach-chat',
        body: {
          'message': 'kalau dengan pemasukan sekarang, saya ingin membeli saham, kira kira apa yang cocok dari jumlah dana yang saya miliki sekarang dan rekomendasi dan prospek sahamnya seperti apa',
          'client_date': '2026-11-06',
          'client_request_id': const Uuid().v4(),
        },
      );

      expect(response.status, 200);
      final data = response.data as Map<String, dynamic>;
      expect(data['intent'], 'query_stock_signal');

      final reply = (data['reply'] as String).toLowerCase();

      // Must mention at least one top watchlist ticker
      expect(
        reply.contains('bbca') ||
            reply.contains('bbri') ||
            reply.contains('bmri') ||
            reply.contains('tlkm') ||
            reply.contains('asii'),
        isTrue,
        reason: 'Reply should recommend from top watchlist stocks: $reply',
      );

      // Must address financial capacity / emergency fund / lot / uang dingin
      expect(
        reply.contains('uang dingin') ||
            reply.contains('pemasukan') ||
            reply.contains('dana darurat') ||
            reply.contains('lot') ||
            reply.contains('anggaran') ||
            reply.contains('saldo'),
        isTrue,
        reason: 'Reply must evaluate user financial capacity: $reply',
      );

      // Must have risk disclaimer
      expect(
        reply.contains('bukan saran investasi') ||
            reply.contains('disclaimer') ||
            reply.contains('risiko') ||
            reply.contains('keputusan'),
        isTrue,
        reason: 'Reply must include investment risk disclaimer: $reply',
      );
    });
  });
}
