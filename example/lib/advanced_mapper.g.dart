// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advanced_mapper.dart';

// **************************************************************************
// SmartMapperGenerator
// **************************************************************************

class _$AdvancedMapper implements AdvancedMapper {
  const _$AdvancedMapper();
  @override
  Profile fromRemote(ProfileDto source) {
    return Profile.fromDto(
      createdAt: parseDate(source.createdAt),
      tags: source.tags?.toSet(),
      reviewers: source.reviewers
          .map((item) => item == null ? null : parseReviewer(item))
          .toSet(),
      status: "active",
    );
  }

  @override
  TaskBox toLocal(TaskEntity source) {
    final target = TaskBox();
    target.owner.target =
        source.owner == null ? null : ownerToLocal(source.owner!);
    return target;
  }

  @override
  OwnerBox ownerToLocal(OwnerEntity source) {
    return OwnerBox(
      name: source.name,
    );
  }

  @override
  TaskEntity fromLocal(TaskBox source) {
    return TaskEntity(
      owner: source.owner.target == null
          ? null
          : ownerFromLocal(source.owner.target!),
    );
  }

  @override
  OwnerEntity ownerFromLocal(OwnerBox source) {
    return OwnerEntity(
      name: source.name,
    );
  }
}

AdvancedMapper createAdvancedMapper() => const _$AdvancedMapper();
