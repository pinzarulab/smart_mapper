import 'package:smart_mapper_example/advanced_mapper.dart';
import 'package:smart_mapper_example/advanced_models.dart';
import 'package:test/test.dart';

void main() {
  final mapper = createAdvancedMapper();

  test('uses named constructor, converters, defaults, Set, and nullability',
      () {
    const source = ProfileDto(
      createdAt: '2026-08-14T08:00:00Z',
      tags: {'dart', 'mapping'},
      reviewers: ['Ada', null],
    );

    final profile = mapper.fromRemote(source);

    expect(profile.id, 0);
    expect(profile.createdAt, DateTime.utc(2026, 8, 14, 8));
    expect(profile.tags, {'dart', 'mapping'});
    expect(profile.reviewers.first?.name, 'Ada');
    expect(profile.reviewers.last, isNull);
    expect(profile.status, 'active');
  });

  test('maps nullable ObjectBox ToOne relations in both directions', () {
    const source = TaskEntity(owner: OwnerEntity(name: 'Grace'));

    final local = mapper.toLocal(source);
    final restored = mapper.fromLocal(local);

    expect(local.owner.target?.name, 'Grace');
    expect(restored.owner?.name, 'Grace');

    final empty = mapper.fromLocal(TaskBox());
    expect(empty.owner, isNull);
  });
}
