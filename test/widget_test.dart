import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finguard/app/app.dart';
import 'package:finguard/app/di/injection.dart';
import 'package:finguard/core/network/connectivity_service.dart';
import 'package:finguard/features/auth/domain/entities/user_entity.dart';
import 'package:finguard/features/auth/domain/repositories/auth_repository.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_cubit.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'has_seen_walkthrough': true});
    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
    when(() => mockAuthRepository.authStateChanges)
        .thenAnswer((_) => const Stream<UserEntity?>.empty());

    sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
    sl.registerLazySingleton<AuthRepository>(() => mockAuthRepository);
    sl.registerFactory<AuthCubit>(
      () => AuthCubit(authRepository: sl<AuthRepository>()),
    );
  });

  tearDownAll(() async {
    await sl.reset();
  });

  testWidgets('FinGuardApp redirects unauthenticated user to LoginPage after splash', (WidgetTester tester) async {
    await tester.pumpWidget(const FinGuardApp());
    // Advance splash delay
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify LoginPage is loaded
    expect(find.text('Masuk ke FinGuard'), findsWidgets);
    expect(find.text('Navigasi Keuangan Cerdas & Terdisiplin'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata sandi'), findsOneWidget);
  });
}
