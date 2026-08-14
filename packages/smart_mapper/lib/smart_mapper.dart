/// Marks an abstract mapper for code generation.
class SmartMapper {
  /// Creates a mapper annotation.
  const SmartMapper();
}

/// Renames one source property for a mapping method.
///
/// Put this annotation on a mapper method. Unannotated constructor parameters
/// map from source properties with the same name.
class MapField {
  /// Creates a field mapping from [source] to [target].
  const MapField({required this.target, required this.source, this.using});

  /// Target constructor parameter name.
  final String target;

  /// Source property name.
  final String source;

  /// Mapper method or top-level converter used for this field.
  final String? using;
}

/// Explicitly maps an ObjectBox or collection relation.
class MapRelation {
  /// Creates a relation mapping from [source] to [target].
  const MapRelation({
    required this.target,
    required this.source,
    this.using,
  });

  /// Target relation field or constructor parameter.
  final String target;

  /// Source property name.
  final String source;

  /// Mapper method or top-level converter used for relation values.
  final String? using;
}

/// Excludes one target field or optional constructor parameter.
class MapIgnore {
  /// Creates an ignore rule for [target].
  const MapIgnore(this.target);

  /// Target field or constructor parameter name.
  final String target;
}

/// Supplies a constant default for one constructor parameter.
class MapDefault {
  /// Creates a default value rule for [target].
  const MapDefault({required this.target, required this.value});

  /// Target constructor parameter name.
  final String target;

  /// Constant primitive value emitted into generated code.
  final Object? value;
}

/// Selects a named constructor for one mapping method.
class MapConstructor {
  /// Uses target constructor [name].
  const MapConstructor(this.name);

  /// Named constructor without target type prefix.
  final String name;
}
