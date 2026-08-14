import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:smart_mapper_generator/smart_mapper_generator.dart';
import 'package:test/test.dart';

void main() {
  test('reports incompatible scalar types during generation', () async {
    final logs = <String>[];

    await testBuilder(
      smartMapperBuilder(BuilderOptions.empty),
      {
        'smart_mapper|lib/smart_mapper.dart': r'''
class SmartMapper {
  const SmartMapper();
}
''',
        'smart_mapper_generator|lib/strict_validation_fixture.dart': r'''
import 'package:smart_mapper/smart_mapper.dart';

part 'mapper.g.dart';

class Source {
  const Source({required this.dueDate});
  final String? dueDate;
}

class Homework {
  const Homework({required this.dueDate});
  final DateTime dueDate;
}

@SmartMapper()
abstract class HomeworkMapper {
  Homework map(Source source);
}
''',
      },
      outputs: {},
      generateFor: {
        'smart_mapper_generator|lib/strict_validation_fixture.dart',
      },
      rootPackage: 'smart_mapper_generator',
      onLog: (record) => logs.add(record.toString()),
    );

    expect(
      logs.join('\n'),
      contains('Cannot assign String? to DateTime for Homework.dueDate.'),
    );
  });
}
