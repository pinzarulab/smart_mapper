import 'package:smart_mapper/smart_mapper.dart';

import 'schedule_models.dart';

part 'schedule_mapper.g.dart';

@SmartMapper()
abstract class ScheduleMapper {
  Schedule fromRemote(ScheduleDto source);

  ScheduleItem itemFromRemote(ScheduleItemDto source);

  ScheduleBox toLocal(Schedule source);

  ScheduleItemBox itemToLocal(ScheduleItem source);

  Schedule fromLocal(ScheduleBox source);

  ScheduleItem itemFromLocal(ScheduleItemBox source);
}
