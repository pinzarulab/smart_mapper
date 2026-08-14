# smart_mapper_generator

Source generator for the
[`smart_mapper`](https://pub.dev/packages/smart_mapper) annotations package.
It generates constructor-based mappings for Clean Architecture boundaries:

```text
Remote DTO -> Local Model -> Domain Entity
```

## Setup

Add it as a dev dependency, annotate an abstract mapper, then run:

```yaml
dependencies:
  smart_mapper: ^0.2.0

dev_dependencies:
  build_runner: ^2.16.0
  smart_mapper_generator: ^0.2.0
```

```sh
dart run build_runner build
```

Application code should import `package:smart_mapper/smart_mapper.dart`, not
this package directly.

## Supported mappings

- Same-name constructor fields
- Strict analyzer-based type validation
- Explicit field renames and converters with `@MapField`
- Explicit ObjectBox relations with `@MapRelation`
- Ignored targets and constant defaults
- Named constructors
- Freezed factory constructors
- Nested `List`, `Set`, and `Iterable` mappings
- Nullable collections and items
- ObjectBox `ToMany` and `ToOne` relations
- Compile-time errors for missing or ambiguous item mappers

See the [`smart_mapper` usage guide](https://pub.dev/packages/smart_mapper)
for mapper declarations and generated-code examples.
