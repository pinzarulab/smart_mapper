class ScheduleDto {
  const ScheduleDto({required this.group, required this.monday});

  final String group;
  final List<ScheduleItemDto> monday;
}

class ScheduleItemDto {
  const ScheduleItemDto({required this.subject});

  final String subject;
}

class Schedule {
  const Schedule({required this.group, required this.monday});

  final String group;
  final List<ScheduleItem> monday;
}

class ScheduleItem {
  const ScheduleItem({required this.subject});

  final String subject;
}

class ScheduleBox {
  ScheduleBox({this.id = 0, required this.group});

  final int id;
  final String group;
  final monday = ToMany<ScheduleItemBox>();
}

class ScheduleItemBox {
  const ScheduleItemBox({this.id = 0, required this.subject});

  final int id;
  final String subject;
}

class ToMany<T> extends Iterable<T> {
  final List<T> _items = [];

  void addAll(Iterable<T> items) => _items.addAll(items);

  @override
  Iterator<T> get iterator => _items.iterator;
}
