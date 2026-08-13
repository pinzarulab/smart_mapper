// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_mapper.dart';

// **************************************************************************
// SmartMapperGenerator
// **************************************************************************

class _$ScheduleMapper implements ScheduleMapper {
  const _$ScheduleMapper();
  @override
  Schedule fromRemote(ScheduleDto source) {
    return Schedule(
      group: source.group,
      monday: source.monday.map(itemFromRemote).toList(),
    );
  }

  @override
  ScheduleItem itemFromRemote(ScheduleItemDto source) {
    return ScheduleItem(
      subject: source.subject,
    );
  }

  @override
  ScheduleBox toLocal(Schedule source) {
    final target = ScheduleBox(
      group: source.group,
    );
    target.monday.addAll(source.monday.map(itemToLocal));
    return target;
  }

  @override
  ScheduleItemBox itemToLocal(ScheduleItem source) {
    return ScheduleItemBox(
      subject: source.subject,
    );
  }

  @override
  Schedule fromLocal(ScheduleBox source) {
    return Schedule(
      group: source.group,
      monday: source.monday.map(itemFromLocal).toList(),
    );
  }

  @override
  ScheduleItem itemFromLocal(ScheduleItemBox source) {
    return ScheduleItem(
      subject: source.subject,
    );
  }
}

ScheduleMapper createScheduleMapper() => const _$ScheduleMapper();
