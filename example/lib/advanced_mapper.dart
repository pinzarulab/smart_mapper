import 'package:smart_mapper/smart_mapper.dart';

import 'advanced_models.dart';

part 'advanced_mapper.g.dart';

DateTime parseDate(String value) => DateTime.parse(value);

Reviewer parseReviewer(String value) => Reviewer(value);

@SmartMapper()
abstract class AdvancedMapper {
  @MapConstructor('fromDto')
  @MapIgnore('id')
  @MapField(target: 'createdAt', source: 'createdAt', using: 'parseDate')
  @MapField(target: 'reviewers', source: 'reviewers', using: 'parseReviewer')
  @MapDefault(target: 'status', value: 'active')
  Profile fromRemote(ProfileDto source);

  @MapIgnore('id')
  @MapRelation(target: 'owner', source: 'owner', using: 'ownerToLocal')
  TaskBox toLocal(TaskEntity source);

  @MapIgnore('id')
  OwnerBox ownerToLocal(OwnerEntity source);

  @MapRelation(target: 'owner', source: 'owner', using: 'ownerFromLocal')
  TaskEntity fromLocal(TaskBox source);

  OwnerEntity ownerFromLocal(OwnerBox source);
}
