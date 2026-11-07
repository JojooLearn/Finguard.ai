import 'dart:async';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final StreamController<UserEntity?> _localAuthController =
      StreamController<UserEntity?>.broadcast();

  UserEntity? _currentUser;
  final Set<String> _completedUserIds = {};

  AuthRepositoryImpl(this.remoteDataSource) {
    // Initialize with remote user if exists
    _currentUser = remoteDataSource.getCurrentUser();
    if (_currentUser != null) {
      loadOnboardingStatus();
    }
    // Listen to remote changes
    remoteDataSource.authStateChanges.listen((user) {
      if (user != null) {
        _currentUser = user;
        loadOnboardingStatus();
        _localAuthController.add(user);
      }
    });
  }

  @override
  Future<Result<UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final user = await remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      _currentUser = user;
      _localAuthController.add(user);
      return Success(user);
    } on AuthException catch (e) {
      return ErrorResult(AuthFailure(e.message, code: e.code));
    } catch (e) {
      return ErrorResult(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.signIn(
        email: email,
        password: password,
      );
      _currentUser = user;
      await loadOnboardingStatus();
      _localAuthController.add(user);
      return Success(user);
    } on AuthException catch (e) {
      return ErrorResult(AuthFailure(e.message, code: e.code));
    } catch (e) {
      return ErrorResult(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await remoteDataSource.signOut();
    } catch (_) {}
    _currentUser = null;
    _completedUserIds.clear();
    _localAuthController.add(null);
    return const Success(null);
  }

  @override
  UserEntity? getCurrentUser() => _currentUser ?? remoteDataSource.getCurrentUser();

  @override
  Stream<UserEntity?> get authStateChanges => _localAuthController.stream;

  @override
  bool hasCompletedOnboarding() {
    final user = getCurrentUser();
    if (user == null) return false;
    return _completedUserIds.contains(user.id);
  }

  @override
  Future<bool> loadOnboardingStatus() async {
    final user = getCurrentUser();
    if (user == null) return false;
    final isDone = await remoteDataSource.checkOnboardingCompleted(user.id);
    if (isDone) {
      _completedUserIds.add(user.id);
    }
    return isDone;
  }

  @override
  void setOnboardingCompleted(bool completed) {
    final user = getCurrentUser();
    if (user != null) {
      if (completed) {
        _completedUserIds.add(user.id);
      } else {
        _completedUserIds.remove(user.id);
      }
    }
  }

  @override
  void updateCurrentUserDisplayName(String name) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(displayName: name);
      _localAuthController.add(_currentUser);
    }
  }
}

