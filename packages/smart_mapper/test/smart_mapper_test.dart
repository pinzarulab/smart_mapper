import 'package:smart_mapper/smart_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('annotations retain configuration', () {
    const mapper = SmartMapper();
    const field = MapField(
      target: 'name',
      source: 'fullName',
      using: 'normalizeName',
    );
    const relation = MapRelation(
      target: 'items',
      source: 'items',
      using: 'mapItem',
    );
    const ignore = MapIgnore('id');
    const defaultValue = MapDefault(target: 'status', value: 'active');
    const constructor = MapConstructor('fromDto');

    expect(mapper, isA<SmartMapper>());
    expect(field.target, 'name');
    expect(field.source, 'fullName');
    expect(field.using, 'normalizeName');
    expect(relation.target, 'items');
    expect(relation.source, 'items');
    expect(relation.using, 'mapItem');
    expect(ignore.target, 'id');
    expect(defaultValue.target, 'status');
    expect(defaultValue.value, 'active');
    expect(constructor.name, 'fromDto');
  });
}
