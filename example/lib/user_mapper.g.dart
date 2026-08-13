// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_mapper.dart';

// **************************************************************************
// SmartMapperGenerator
// **************************************************************************

class _$UserMapper implements UserMapper {
  const _$UserMapper();
  @override
  User map(UserResponse source) {
    return User(
      id: source.id,
      name: source.fullName,
      email: source.email,
    );
  }

  @override
  UserBox toLocal(UserResponse source) {
    return UserBox(
      id: source.id,
      fullName: source.fullName,
      email: source.email,
    );
  }

  @override
  User fromLocal(UserBox source) {
    return User(
      id: source.id,
      name: source.fullName,
      email: source.email,
    );
  }

  @override
  UserSummary toSummary(UserResponse source) {
    return UserSummary(
      id: source.id,
      email: source.email,
    );
  }
}

UserMapper createUserMapper() => const _$UserMapper();
