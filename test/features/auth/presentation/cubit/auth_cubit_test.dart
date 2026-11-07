import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/auth/domain/entities/user_entity.dart';
import 'package:finguard/features/auth/domain/repositories/auth_repository.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_state.dart';

// Mock
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late StreamController<UserEntity?> authStreamController;

  const testUser = UserEntity(
    id: 'test-uid-123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authStreamController = StreamController<UserEntity?>.broadcast();

    // Default stubs
    when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
    when(() => mockAuthRepository.authStateChanges)
        .thenAnswer((_) => authStreamController.stream);
  });

  tearDown(() {
    authStreamController.close();
  });

  group('AuthCubit', () {
    group('initial state', () {
      test('has Unauthenticated state when no current user', () {
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        expect(cubit.state, isA<Unauthenticated>());
        cubit.close();
      });

      test('has Authenticated state when current user exists', () {
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(testUser);
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        expect(cubit.state, isA<Authenticated>());
        cubit.close();
      });

      test('Authenticated state contains correct user data', () {
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(testUser);
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        expect(cubit.state, isA<Authenticated>());
        final state = cubit.state as Authenticated;
        expect(state.user.id, equals('test-uid-123'));
        expect(state.user.email, equals('test@example.com'));
        expect(state.user.displayName, equals('Test User'));
        cubit.close();
      });
    });

    group('signIn', () {
      blocTest<AuthCubit, AuthState>(
        'ends in Authenticated state on successful sign-in',
        build: () {
          when(() => mockAuthRepository.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer((_) async => const Success(testUser));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) =>
            cubit.signIn(email: 'test@example.com', password: 'password123'),
        verify: (cubit) {
          expect(cubit.state, isA<Authenticated>());
          final state = cubit.state as Authenticated;
          expect(state.user.email, equals('test@example.com'));
        },
      );

      blocTest<AuthCubit, AuthState>(
        'calls repository.signIn with correct parameters',
        build: () {
          when(() => mockAuthRepository.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer((_) async => const Success(testUser));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) =>
            cubit.signIn(email: 'test@example.com', password: 'password123'),
        verify: (_) {
          verify(() => mockAuthRepository.signIn(
                email: 'test@example.com',
                password: 'password123',
              )).called(1);
        },
      );

      blocTest<AuthCubit, AuthState>(
        'ends in AuthError state on failed sign-in',
        build: () {
          when(() => mockAuthRepository.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer(
            (_) async =>
                const ErrorResult(AuthFailure('Email atau password salah')),
          );
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) =>
            cubit.signIn(email: 'wrong@example.com', password: 'wrong'),
        verify: (cubit) {
          expect(cubit.state, isA<AuthError>());
          expect((cubit.state as AuthError).message,
              equals('Email atau password salah'));
        },
      );
    });

    group('signUp', () {
      blocTest<AuthCubit, AuthState>(
        'ends in Authenticated state on successful sign-up',
        build: () {
          when(() => mockAuthRepository.signUp(
                email: any(named: 'email'),
                password: any(named: 'password'),
                fullName: any(named: 'fullName'),
              )).thenAnswer((_) async => const Success(testUser));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) => cubit.signUp(
          email: 'new@example.com',
          password: 'password123',
          fullName: 'New User',
        ),
        verify: (cubit) {
          expect(cubit.state, isA<Authenticated>());
          final state = cubit.state as Authenticated;
          expect(state.user.email, equals('test@example.com'));
        },
      );

      blocTest<AuthCubit, AuthState>(
        'calls repository.signUp with correct parameters',
        build: () {
          when(() => mockAuthRepository.signUp(
                email: any(named: 'email'),
                password: any(named: 'password'),
                fullName: any(named: 'fullName'),
              )).thenAnswer((_) async => const Success(testUser));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) => cubit.signUp(
          email: 'new@example.com',
          password: 'password123',
          fullName: 'New User',
        ),
        verify: (_) {
          verify(() => mockAuthRepository.signUp(
                email: 'new@example.com',
                password: 'password123',
                fullName: 'New User',
              )).called(1);
        },
      );

      blocTest<AuthCubit, AuthState>(
        'ends in AuthError state on failed sign-up',
        build: () {
          when(() => mockAuthRepository.signUp(
                email: any(named: 'email'),
                password: any(named: 'password'),
                fullName: any(named: 'fullName'),
              )).thenAnswer(
            (_) async =>
                const ErrorResult(AuthFailure('Email sudah terdaftar')),
          );
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) => cubit.signUp(
          email: 'existing@example.com',
          password: 'password123',
          fullName: 'Existing User',
        ),
        verify: (cubit) {
          expect(cubit.state, isA<AuthError>());
          expect((cubit.state as AuthError).message,
              equals('Email sudah terdaftar'));
        },
      );
    });

    group('signOut', () {
      blocTest<AuthCubit, AuthState>(
        'ends in Unauthenticated state after sign-out',
        build: () {
          when(() => mockAuthRepository.getCurrentUser()).thenReturn(testUser);
          when(() => mockAuthRepository.signOut())
              .thenAnswer((_) async => const Success(null));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) => cubit.signOut(),
        verify: (cubit) {
          expect(cubit.state, isA<Unauthenticated>());
        },
      );

      blocTest<AuthCubit, AuthState>(
        'calls repository.signOut',
        build: () {
          when(() => mockAuthRepository.getCurrentUser()).thenReturn(testUser);
          when(() => mockAuthRepository.signOut())
              .thenAnswer((_) async => const Success(null));
          return AuthCubit(authRepository: mockAuthRepository);
        },
        act: (cubit) => cubit.signOut(),
        verify: (_) {
          verify(() => mockAuthRepository.signOut()).called(1);
        },
      );
    });

    group('auth state stream', () {
      test('updates state when auth stream emits a user', () async {
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        expect(cubit.state, isA<Unauthenticated>());

        authStreamController.add(testUser);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(cubit.state, isA<Authenticated>());
        final state = cubit.state as Authenticated;
        expect(state.user.id, equals('test-uid-123'));

        await cubit.close();
      });

      test('updates state when auth stream emits null', () async {
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(testUser);
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        expect(cubit.state, isA<Authenticated>());

        authStreamController.add(null);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(cubit.state, isA<Unauthenticated>());

        await cubit.close();
      });
    });

    group('cleanup', () {
      test('cancels auth stream subscription on close', () async {
        final cubit = AuthCubit(authRepository: mockAuthRepository);
        await cubit.close();

        // After close, adding to stream should not cause errors
        authStreamController.add(testUser);
        await Future.delayed(const Duration(milliseconds: 50));

        // State should remain Unauthenticated (last state before close)
        expect(cubit.state, isA<Unauthenticated>());
      });
    });
  });
}
