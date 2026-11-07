import 'package:equatable/equatable.dart';
import '../../domain/entities/profile_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final ProfileEntity profile;

  const ProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileUpdating extends ProfileState {
  final ProfileEntity currentProfile;

  const ProfileUpdating(this.currentProfile);

  @override
  List<Object?> get props => [currentProfile];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

