import 'package:smart_mapper/smart_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('annotations retain configuration', () {
    const mapper = SmartMapper();
    const field = MapField(target: 'name', source: 'fullName');

    expect(mapper, isA<SmartMapper>());
    expect(field.target, 'name');
    expect(field.source, 'fullName');
  });
}
