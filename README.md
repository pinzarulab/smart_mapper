# smart_mapper

Compile-time mappings for Clean Architecture boundaries:

```text
Remote DTO -> Local Model -> Domain Entity
```

This repository contains:

- `smart_mapper`: annotations used by application code.
- `smart_mapper_generator`: source generator and `build_runner` integration.
- `example`: complete Remote/Local/Domain mapping.

See [`packages/smart_mapper/README.md`](packages/smart_mapper/README.md) for usage.

## Publishing

Packages publish separately because applications need annotations at runtime
and generator only during development.

1. Commit all release changes so Git state is clean.
2. Publish `packages/smart_mapper` first.
3. Wait until version resolves from pub.dev.
4. Publish `packages/smart_mapper_generator` second.

Validate without publishing:

```sh
cd packages/smart_mapper
dart pub publish --dry-run

cd ../smart_mapper_generator
dart pub publish --dry-run
```
