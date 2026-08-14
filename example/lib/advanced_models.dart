class ProfileDto {
  const ProfileDto({
    required this.createdAt,
    required this.tags,
    required this.reviewers,
  });

  final String createdAt;
  final Iterable<String>? tags;
  final List<String?> reviewers;
}

class Profile {
  const Profile.fromDto({
    this.id = 0,
    required this.createdAt,
    required this.tags,
    required this.reviewers,
    required this.status,
  });

  final int id;
  final DateTime createdAt;
  final Set<String>? tags;
  final Set<Reviewer?> reviewers;
  final String status;
}

class Reviewer {
  const Reviewer(this.name);

  final String name;
}

class TaskEntity {
  const TaskEntity({required this.owner});

  final OwnerEntity? owner;
}

class OwnerEntity {
  const OwnerEntity({required this.name});

  final String name;
}

class TaskBox {
  TaskBox({this.id = 0});

  final int id;
  final owner = ToOne<OwnerBox>();
}

class OwnerBox {
  const OwnerBox({this.id = 0, required this.name});

  final int id;
  final String name;
}

class ToOne<T> {
  T? target;
}
