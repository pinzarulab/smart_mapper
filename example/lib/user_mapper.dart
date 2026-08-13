import 'package:smart_mapper/smart_mapper.dart';

import 'models.dart';

part 'user_mapper.g.dart';

@SmartMapper()
abstract class UserMapper {
  @MapField(target: 'name', source: 'fullName')
  User map(UserResponse source);

  UserBox toLocal(UserResponse source);

  @MapField(target: 'name', source: 'fullName')
  User fromLocal(UserBox source);

  UserSummary toSummary(UserResponse source);
}
