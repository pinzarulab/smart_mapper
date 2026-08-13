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
  const MapField({required this.target, required this.source});

  /// Target constructor parameter name.
  final String target;

  /// Source property name.
  final String source;
}
