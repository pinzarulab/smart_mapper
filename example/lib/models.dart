class UserResponse {
  const UserResponse({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;
}

class UserBox {
  const UserBox({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;
}

class User {
  const User({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}

abstract class UserSummary {
  factory UserSummary({required String id, required String email}) =
      UserSummaryData;

  String get id;
  String get email;
}

class UserSummaryData implements UserSummary {
  const UserSummaryData({required this.id, required this.email});

  @override
  final String id;

  @override
  final String email;
}
