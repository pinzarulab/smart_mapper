# smart_mapper

Focused object mapping for Clean Architecture boundaries. It generates small,
plain Dart mappers between Remote DTOs, Local Models, and Domain Entities.

## Setup

Add runtime annotations and generator:

```yaml
dependencies:
  smart_mapper: ^0.2.0

dev_dependencies:
  build_runner: ^2.16.0
  smart_mapper_generator: ^0.2.0
```

Define an abstract mapper. Same-name, assignable properties map automatically.
Declare renames and converters explicitly:

```dart
import 'package:smart_mapper/smart_mapper.dart';

part 'user_mapper.g.dart';

@SmartMapper()
abstract class UserMapper {
  @MapField(
    target: 'name',
    source: 'fullName',
    using: 'normalizeName',
  )
  User map(UserResponse source);

  UserBox toLocal(UserResponse source);

  User fromLocal(UserBox source);
}

String normalizeName(String value) => value.trim();
```

Generate code:

```sh
dart run build_runner build
```

Use generated factory:

```dart
final mapper = createUserMapper();
final user = mapper.map(response);
```

Generated implementation stays intentionally boring: constructor calls,
property reads, and explicit converter calls.

## Strict validation

Every direct assignment is checked with analyzer's type system. Invalid
boundaries fail during generation instead of producing broken Dart:

```text
Cannot assign String? to DateTime for Homework.dueDate.
```

Use a top-level converter when source and target types differ:

```dart
@MapField(target: 'createdAt', source: 'createdAt', using: 'parseDate')
Profile fromRemote(ProfileDto source);

DateTime parseDate(String value) => DateTime.parse(value);
```

## Constructor controls

```dart
@MapConstructor('fromDto')
@MapIgnore('id')
@MapDefault(target: 'status', value: 'active')
Profile fromRemote(ProfileDto source);
```

`MapDefault` accepts constant `null`, `bool`, numbers, strings, lists, sets,
and maps.

## Nested collections and ObjectBox `ToMany`

Declare item mapping methods beside parent mapping methods:

```dart
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
  ScheduleItemBox itemToLocal(ScheduleItem source);

  Schedule fromLocal(ScheduleBox source);
  ScheduleItem itemFromLocal(ScheduleItemBox source);
}
```

`List`, `Set`, and `Iterable` collections use matching item mappers. ObjectBox
relations require `@MapRelation`; no relation is mutated implicitly. A target
`ToMany<TargetItem>` field is populated after construction:

```dart
final target = ScheduleBox(group: source.group);
target.monday.addAll(source.monday.map(itemToLocal));
return target;
```

Missing or ambiguous item mapper methods fail during generation.

ObjectBox `ToOne` is also supported. Nullable targets remain nullable, with
converter calls guarded against `null`.

## Scope

Version `0.2.0` supports synchronous methods with exactly one required
positional source parameter and target types with an unnamed generative or
factory constructor. Named constructors, nested `List`/`Set`/`Iterable`,
nullable collections/items, and ObjectBox `ToMany`/`ToOne` relations are
supported. Async and update-in-place mapping remain outside current scope.
