import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDataSource {
  Future<UserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  UserEntity? getCurrentUser();

  Stream<UserEntity?> get authStateChanges;

  Future<bool> checkOnboardingCompleted(String userId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final sb.SupabaseClient supabase;

  AuthRemoteDataSourceImpl(this.supabase);

  @override
  Future<UserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('Gagal membuat akun');
      }
      // If session is null, immediately signInWithPassword since DB trigger auto-confirms email
      if (res.session == null) {
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (_) {}
      }
      return UserEntity(
        id: user.id,
        email: user.email ?? email,
        displayName: fullName,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('User tidak ditemukan');
      }
      final metaName = user.userMetadata?['full_name'] as String?;
      return UserEntity(
        id: user.id,
        email: user.email ?? email,
        displayName: metaName,
      );
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  UserEntity? getCurrentUser() {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['full_name'] as String?,
    );
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return supabase.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return UserEntity(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String?,
      );
    });
  }

  @override
  Future<bool> checkOnboardingCompleted(String userId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && currentUser.id == userId) {
      if (currentUser.userMetadata?['onboarding_completed'] == true) {
        return true;
      }
    }

    try {
      final res = await supabase
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && res['onboarding_completed_at'] != null) {
        try {
          await supabase.auth.updateUser(
            sb.UserAttributes(data: {'onboarding_completed': true}),
          );
        } catch (_) {}
        return true;
      }
      return false;
    } catch (_) {
      return currentUser?.userMetadata?['onboarding_completed'] == true;
    }
  }
}

