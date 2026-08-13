# smart_mapper

Focused object mapping for Clean Architecture boundaries. It generates small,
plain Dart mappers between Remote DTOs, Local Models, and Domain Entities.

## Setup

Add runtime annotations and generator:

```yaml
dependencies:
  smart_mapper: ^0.1.0

dev_dependencies:
  build_runner: ^2.16.0
  smart_mapper_generator: ^0.1.0
```

Define an abstract mapper. Same-name properties map automatically. Declare
renames explicitly:

```dart
import 'package:smart_mapper/smart_mapper.dart';

part 'user_mapper.g.dart';

@SmartMapper()
abstract class UserMapper {
  @MapField(target: 'name', source: 'fullName')
  User map(UserResponse source);

  UserBox toLocal(UserResponse source);

  User fromLocal(UserBox source);
}
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

Generated implementation stays intentionally boring: constructor calls and
property reads. Missing properties, duplicate mappings, unsupported methods,
and inaccessible constructors fail during generation.

## Nested collections and ObjectBox `ToMany`

Declare item mapping methods beside parent mapping methods:

```dart
@SmartMapper()
abstract class ScheduleMapper {
  Schedule fromRemote(ScheduleDto source);
  ScheduleItem itemFromRemote(ScheduleItemDto source);

  ScheduleBox toLocal(Schedule source);
  ScheduleItemBox itemToLocal(ScheduleItem source);

  Schedule fromLocal(ScheduleBox source);
  ScheduleItem itemFromLocal(ScheduleItemBox source);
}
```

`List<SourceItem>` to `List<TargetItem>` uses matching item mapper and
generates `.map(itemMapper).toList()`. A target `ToMany<TargetItem>` field is
populated after construction:

```dart
final target = ScheduleBox(group: source.group);
target.monday.addAll(source.monday.map(itemToLocal));
return target;
```

Missing or ambiguous item mapper methods fail during generation.

## Scope

Version `0.1.0` supports synchronous methods with exactly one required
positional source parameter and target types with an unnamed generative or
factory constructor. Nested `List`, `Iterable`, and ObjectBox `ToMany`
collections are supported through item mapper methods. General converters,
async mapping, and update-in-place mapping are outside this first release.
