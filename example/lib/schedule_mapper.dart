import 'package:smart_mapper/smart_mapper.dart';

import 'schedule_models.dart';

part 'schedule_mapper.g.dart';

@SmartMapper()
abstract class ScheduleMapper {
  Schedule fromRemote(ScheduleDto source);

  ScheduleItem itemFromRemote(ScheduleItemDto source);

  @MapRelation(
    target: 'monday',
    source: 'monday',
    using: 'itemToLocal',
  )
  ScheduleBox toLocal(Schedule source);

  @MapIgnore('id')
  ScheduleItemBox itemToLocal(ScheduleItem source);

  Schedule fromLocal(ScheduleBox source);

  ScheduleItem itemFromLocal(ScheduleItemBox source);
}
