import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repository;

  ProfileCubit({required this.repository}) : super(const ProfileInitial());

  void reset() {
    repository.clearCache();
    emit(const ProfileInitial());
  }

  Future<void> loadProfile() async {
    emit(const ProfileLoading());
    final result = await repository.getProfile();
    result.fold(
      (profile) => emit(ProfileLoaded(profile)),
      (failure) => emit(ProfileError(failure.message)),
    );
  }

  Future<bool> updateProfile({
    String? displayName,
    double? monthlyIncome,
    double? essentialExpenses,
    double? monthlyDebt,
    int? strictnessLevel,
  }) async {
    final current = state is ProfileLoaded
        ? (state as ProfileLoaded).profile
        : (state is ProfileUpdating ? (state as ProfileUpdating).currentProfile : null);

    if (current != null) {
      emit(ProfileUpdating(current));
    } else {
      emit(const ProfileLoading());
    }

    final result = await repository.updateProfile(
      displayName: displayName,
      monthlyIncome: monthlyIncome,
      essentialExpenses: essentialExpenses,
      monthlyDebt: monthlyDebt,
      strictnessLevel: strictnessLevel,
    );

    return result.fold(
      (profile) {
        emit(ProfileLoaded(profile));
        return true;
      },
      (failure) {
        if (current != null) {
          emit(ProfileLoaded(current));
        } else {
          emit(ProfileError(failure.message));
        }
        return false;
      },
    );
  }

  Future<bool> recalculateBlueprint({
    required double monthlyIncome,
    int? strictnessLevel,
  }) async {
    final current = state is ProfileLoaded ? (state as ProfileLoaded).profile : null;
    if (current != null) {
      emit(ProfileUpdating(current));
    } else {
      emit(const ProfileLoading());
    }

    final result = await repository.recalculateBlueprintFromIncome(
      monthlyIncome: monthlyIncome,
      strictnessLevel: strictnessLevel,
    );

    return result.fold(
      (_) async {
        final profileRes = await repository.getProfile();
        profileRes.fold(
          (p) => emit(ProfileLoaded(p)),
          (f) => emit(ProfileError(f.message)),
        );
        return true;
      },
      (failure) {
        if (current != null) {
          emit(ProfileLoaded(current));
        } else {
          emit(ProfileError(failure.message));
        }
        return false;
      },
    );
  }
}

