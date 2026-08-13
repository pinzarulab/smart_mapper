import 'package:smart_mapper_example/schedule_mapper.dart';
import 'package:smart_mapper_example/schedule_models.dart';
import 'package:test/test.dart';

void main() {
  test('maps nested lists into and out of ToMany relations', () {
    final mapper = createScheduleMapper();
    const remote = ScheduleDto(
      group: 'A',
      monday: [ScheduleItemDto(subject: 'Math')],
    );

    final domain = mapper.fromRemote(remote);
    final local = mapper.toLocal(domain);
    final restored = mapper.fromLocal(local);

    expect(domain.monday.single.subject, 'Math');
    expect(local.monday.single, isA<ScheduleItemBox>());
    expect(restored.monday.single.subject, 'Math');
  });
}
