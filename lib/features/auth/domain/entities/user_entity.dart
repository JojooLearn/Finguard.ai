class UserEntity {
  final String id;
  final String email;
  final String? displayName;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
  });

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
