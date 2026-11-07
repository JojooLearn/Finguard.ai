import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  final PushNotificationService? pushNotificationService;
  StreamSubscription? _authSubscription;

  AuthCubit({
    required this.authRepository,
    this.pushNotificationService,
  }) : super(const AuthInitial()) {
    _checkInitialAuth();
    _listenAuthChanges();
  }

  void _checkInitialAuth() {
    final user = authRepository.getCurrentUser();
    if (user != null) {
      pushNotificationService?.login(user.id);
      emit(Authenticated(user));
    } else {
      emit(const Unauthenticated());
    }
  }

  void _listenAuthChanges() {
    _authSubscription = authRepository.authStateChanges.listen((user) {
      if (user != null) {
        pushNotificationService?.login(user.id);
        emit(Authenticated(user));
      } else {
        pushNotificationService?.logout();
        emit(const Unauthenticated());
      }
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthLoading());
    final result = await authRepository.signIn(email: email, password: password);
    result.fold(
      (user) {
        pushNotificationService?.login(user.id);
        pushNotificationService?.requestPermission();
        emit(Authenticated(user));
      },
      (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    emit(const AuthLoading());
    final result = await authRepository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    result.fold(
      (user) {
        pushNotificationService?.login(user.id);
        pushNotificationService?.requestPermission();
        emit(Authenticated(user));
      },
      (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> signOut() async {
    emit(const AuthLoading());
    await pushNotificationService?.logout();
    await authRepository.signOut();
    emit(const Unauthenticated());
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}

