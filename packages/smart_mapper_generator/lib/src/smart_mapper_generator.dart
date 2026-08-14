import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:smart_mapper/smart_mapper.dart';
import 'package:source_gen/source_gen.dart';

/// Generates concrete implementations of `@SmartMapper` classes.
class SmartMapperGenerator extends GeneratorForAnnotation<SmartMapper> {
  static const _mapFieldChecker = TypeChecker.typeNamed(
    MapField,
    inPackage: 'smart_mapper',
  );
  static const _mapRelationChecker = TypeChecker.typeNamed(
    MapRelation,
    inPackage: 'smart_mapper',
  );
  static const _mapIgnoreChecker = TypeChecker.typeNamed(
    MapIgnore,
    inPackage: 'smart_mapper',
  );
  static const _mapDefaultChecker = TypeChecker.typeNamed(
    MapDefault,
    inPackage: 'smart_mapper',
  );
  static const _mapConstructorChecker = TypeChecker.typeNamed(
    MapConstructor,
    inPackage: 'smart_mapper',
  );

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@SmartMapper can only annotate a class.',
        element: element,
      );
    }
    if (!element.isAbstract) {
      throw InvalidGenerationSourceError(
        '@SmartMapper class must be abstract.',
        element: element,
      );
    }
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Generic mapper classes are not supported yet.',
        element: element,
      );
    }

    final methods = element.methods
        .where((method) => method.isAbstract)
        .toList();
    if (methods.isEmpty) {
      throw InvalidGenerationSourceError(
        '@SmartMapper class must declare at least one abstract mapping method.',
        element: element,
      );
    }

    final mapperName = element.name!;
    final buffer = StringBuffer()
      ..writeln('class _\$$mapperName implements $mapperName {')
      ..writeln('  const _\$$mapperName();');

    for (final method in methods) {
      _writeMethod(buffer, method, methods);
    }

    buffer
      ..writeln('}')
      ..writeln()
      ..writeln('$mapperName create$mapperName() => const _\$$mapperName();');
    return buffer.toString();
  }

  void _writeMethod(
    StringBuffer buffer,
    MethodElement method,
    List<MethodElement> mappingMethods,
  ) {
    _validateMethod(method);

    final sourceParameter = method.formalParameters.single;
    final sourceType = sourceParameter.type;
    final targetType = method.returnType;
    final sourceElement = _classElement(sourceType);
    final targetElement = _classElement(targetType);
    if (sourceElement == null || targetElement == null) {
      _unsupported(method, 'source and return types must be classes');
    }

    final config = _readConfig(method);
    final constructor = _constructor(targetElement, config, method);
    final constructorParameters = <String, FormalParameterElement>{
      for (final parameter in constructor.formalParameters)
        if (parameter.name != null) parameter.name!: parameter,
    };
    final targetFields = <String, FieldElement>{
      for (final field in targetElement.fields)
        if (field.name != null && !field.isStatic) field.name!: field,
    };
    final targetNames = {...constructorParameters.keys, ...targetFields.keys};
    _validateConfig(
      config,
      targetNames,
      constructorParameters,
      targetFields,
      method,
    );

    final sourceProperties = _properties(sourceElement);
    final arguments = <String>[];
    for (final parameter in constructor.formalParameters) {
      final targetName = parameter.name!;
      if (config.ignores.contains(targetName)) {
        if (parameter.isRequired) {
          throw InvalidGenerationSourceError(
            'Cannot ignore required constructor parameter '
            '${targetElement.name}.$targetName.',
            element: method,
          );
        }
        continue;
      }

      final defaultValue = config.defaults[targetName];
      if (defaultValue != null || config.defaults.containsKey(targetName)) {
        arguments.add(
          _argument(parameter, targetName, _literal(defaultValue!, method)),
        );
        continue;
      }

      final rule = config.fields[targetName] ?? config.relations[targetName];
      final sourceName = rule?.source ?? targetName;
      final sourcePropertyType = sourceProperties[sourceName];
      if (sourcePropertyType == null && parameter.isOptionalNamed) continue;
      if (sourcePropertyType == null) {
        throw InvalidGenerationSourceError(
          'Cannot map ${targetElement.name}.$targetName: '
          '${sourceElement.name} has no readable property `$sourceName`.',
          element: method,
        );
      }

      final value = _mappedValue(
        sourceExpression: '${sourceParameter.name}.$sourceName',
        sourceType: sourcePropertyType,
        targetType: parameter.type,
        using: rule?.using,
        mappingMethods: mappingMethods,
        method: method,
        targetLabel: '${targetElement.name}.$targetName',
      );
      arguments.add(_argument(parameter, targetName, value));
    }

    final postRelations = config.relations.values
        .where((rule) => !constructorParameters.containsKey(rule.target))
        .toList();
    final returnName = targetType.getDisplayString();
    final sourceName = sourceType.getDisplayString();
    final constructorCall = config.constructorName == null
        ? returnName
        : '$returnName.${config.constructorName}';

    buffer
      ..writeln('  @override')
      ..writeln(
        '  $returnName ${method.name}($sourceName ${sourceParameter.name}) {',
      )
      ..writeln(
        postRelations.isEmpty
            ? '    return $constructorCall('
            : '    final target = $constructorCall(',
      );
    for (final argument in arguments) {
      buffer.writeln('      $argument,');
    }
    buffer.writeln('    );');

    for (final rule in postRelations) {
      final field = targetFields[rule.target]!;
      final sourcePropertyType = sourceProperties[rule.source];
      if (sourcePropertyType == null) {
        throw InvalidGenerationSourceError(
          'Cannot map ${targetElement.name}.${rule.target}: '
          '${sourceElement.name} has no readable property `${rule.source}`.',
          element: method,
        );
      }
      final sourceExpression = '${sourceParameter.name}.${rule.source}';
      final relationKind = _relationKind(field.type);
      if (relationKind == _RelationKind.toMany) {
        final value = _mappedCollection(
          sourceExpression: sourceExpression,
          sourceType: sourcePropertyType,
          targetType: field.type,
          using: rule.using,
          mappingMethods: mappingMethods,
          method: method,
          targetLabel: '${targetElement.name}.${rule.target}',
          forAddAll: true,
        );
        buffer.writeln('    target.${rule.target}.addAll($value);');
      } else if (relationKind == _RelationKind.toOne) {
        final value = _mappedToOneTarget(
          sourceExpression: sourceExpression,
          sourceType: sourcePropertyType,
          targetType: field.type,
          using: rule.using,
          mappingMethods: mappingMethods,
          method: method,
          targetLabel: '${targetElement.name}.${rule.target}',
        );
        buffer.writeln('    target.${rule.target}.target = $value;');
      } else {
        throw InvalidGenerationSourceError(
          '@MapRelation target ${targetElement.name}.${rule.target} must be '
          'an ObjectBox ToMany or ToOne field.',
          element: method,
        );
      }
    }

    if (postRelations.isNotEmpty) buffer.writeln('    return target;');
    buffer.writeln('  }');
  }

  String _mappedValue({
    required String sourceExpression,
    required DartType sourceType,
    required DartType targetType,
    required String? using,
    required List<MethodElement> mappingMethods,
    required MethodElement method,
    required String targetLabel,
  }) {
    final sourceCollection = _collectionType(sourceType);
    final targetCollection = _collectionType(targetType);
    if (sourceCollection != null && targetCollection != null) {
      return _mappedCollection(
        sourceExpression: sourceExpression,
        sourceType: sourceType,
        targetType: targetType,
        using: using,
        mappingMethods: mappingMethods,
        method: method,
        targetLabel: targetLabel,
      );
    }

    final sourceToOne = _toOneItemType(sourceType);
    if (sourceToOne != null) {
      if (!_isNullable(targetType)) {
        _typeError(sourceType, targetType, targetLabel, method);
      }
      final targetItem = method.library.typeSystem.promoteToNonNull(targetType);
      final expression = '$sourceExpression.target';
      if (using == null && _assignable(sourceToOne, targetItem, method)) {
        return expression;
      }
      final converter = _resolveConverter(
        sourceType: sourceToOne,
        targetType: targetItem,
        using: using,
        mappingMethods: mappingMethods,
        method: method,
        targetLabel: targetLabel,
      );
      return '$expression == null ? null : ${converter.call}($expression!)';
    }

    if (using != null) {
      final converter = _resolveConverter(
        sourceType: sourceType,
        targetType: targetType,
        using: using,
        mappingMethods: mappingMethods,
        method: method,
        targetLabel: targetLabel,
      );
      return '${converter.call}($sourceExpression)';
    }
    if (_assignable(sourceType, targetType, method)) return sourceExpression;
    _typeError(sourceType, targetType, targetLabel, method);
  }

  String _mappedCollection({
    required String sourceExpression,
    required DartType sourceType,
    required DartType targetType,
    required String? using,
    required List<MethodElement> mappingMethods,
    required MethodElement method,
    required String targetLabel,
    bool forAddAll = false,
  }) {
    final source = _collectionType(sourceType);
    final target = _collectionType(targetType);
    if (source == null || target == null) {
      _typeError(sourceType, targetType, targetLabel, method);
    }
    if (source.isNullable && !target.isNullable && !forAddAll) {
      _typeError(sourceType, targetType, targetLabel, method);
    }

    String itemExpression = 'item';
    String? converterCall;
    var nullGuard = false;
    if (using != null ||
        !_assignable(source.itemType, target.itemType, method)) {
      final converter = _resolveConverter(
        sourceType: source.itemType,
        targetType: target.itemType,
        using: using,
        mappingMethods: mappingMethods,
        method: method,
        targetLabel: targetLabel,
        allowNullGuard: true,
      );
      converterCall = converter.call;
      nullGuard = converter.nullGuard;
    }

    final mappedItem = converterCall == null
        ? itemExpression
        : '$converterCall($itemExpression)';
    final mapper = nullGuard
        ? '(item) => item == null ? null : $mappedItem'
        : converterCall;
    final nullableAccess = source.isNullable ? '?' : '';
    var expression = mapper == null
        ? sourceExpression
        : '$sourceExpression$nullableAccess.map($mapper)';
    if (mapper == null && source.kind != target.kind && !forAddAll) {
      expression = sourceExpression;
    }

    if (!forAddAll) {
      final access = source.isNullable ? '?' : '';
      if (target.kind == _CollectionKind.list) {
        expression = '$expression$access.toList()';
      } else if (target.kind == _CollectionKind.set) {
        expression = '$expression$access.toSet()';
      }
    } else if (source.isNullable) {
      expression = '$expression ?? const []';
    }
    return expression;
  }

  String _mappedToOneTarget({
    required String sourceExpression,
    required DartType sourceType,
    required DartType targetType,
    required String? using,
    required List<MethodElement> mappingMethods,
    required MethodElement method,
    required String targetLabel,
  }) {
    final targetItem = _toOneItemType(targetType)!;
    final sourceRelationItem = _toOneItemType(sourceType);
    final effectiveSourceType =
        sourceRelationItem ??
        method.library.typeSystem.promoteToNonNull(sourceType);
    final expression = sourceRelationItem == null
        ? sourceExpression
        : '$sourceExpression.target';
    final mayBeNull = sourceRelationItem != null || _isNullable(sourceType);

    if (using == null && _assignable(effectiveSourceType, targetItem, method)) {
      return expression;
    }
    final converter = _resolveConverter(
      sourceType: effectiveSourceType,
      targetType: targetItem,
      using: using,
      mappingMethods: mappingMethods,
      method: method,
      targetLabel: targetLabel,
    );
    final converted = '${converter.call}($expression${mayBeNull ? '!' : ''})';
    return mayBeNull ? '$expression == null ? null : $converted' : converted;
  }

  _ResolvedConverter _resolveConverter({
    required DartType sourceType,
    required DartType targetType,
    required String? using,
    required List<MethodElement> mappingMethods,
    required MethodElement method,
    required String targetLabel,
    bool allowNullGuard = false,
  }) {
    final candidates = <_Converter>[];
    for (final candidate in mappingMethods) {
      if (candidate.formalParameters.length != 1) continue;
      if (using != null && candidate.name != using) continue;
      candidates.add(
        _Converter(
          candidate.name!,
          candidate.formalParameters.single.type,
          candidate.returnType,
        ),
      );
    }
    if (using != null) {
      for (final candidate in method.library.topLevelFunctions) {
        if (candidate.name != using || candidate.formalParameters.length != 1) {
          continue;
        }
        candidates.add(
          _Converter(
            candidate.name!,
            candidate.formalParameters.single.type,
            candidate.returnType,
          ),
        );
      }
    }

    final valid = <_ResolvedConverter>[];
    for (final candidate in candidates) {
      if (!_assignable(candidate.outputType, targetType, method)) continue;
      if (_assignable(sourceType, candidate.inputType, method)) {
        valid.add(_ResolvedConverter(candidate.call));
        continue;
      }
      if (allowNullGuard && _isNullable(sourceType)) {
        final nonNull = method.library.typeSystem.promoteToNonNull(sourceType);
        if (_assignable(nonNull, candidate.inputType, method) &&
            _isNullable(targetType)) {
          valid.add(_ResolvedConverter(candidate.call, nullGuard: true));
        }
      }
    }

    if (valid.isEmpty) {
      final requested = using == null ? '' : ' `$using`';
      throw InvalidGenerationSourceError(
        'No converter$requested maps ${sourceType.getDisplayString()} to '
        '${targetType.getDisplayString()} for $targetLabel.',
        element: method,
      );
    }
    if (valid.length > 1) {
      throw InvalidGenerationSourceError(
        'Multiple converters map ${sourceType.getDisplayString()} to '
        '${targetType.getDisplayString()} for $targetLabel. Set `using` '
        'explicitly.',
        element: method,
      );
    }
    return valid.single;
  }

  _MethodConfig _readConfig(MethodElement method) {
    final config = _MethodConfig();
    for (final annotation in _mapFieldChecker.annotationsOf(method)) {
      final reader = ConstantReader(annotation);
      final rule = _Rule(
        target: reader.read('target').stringValue,
        source: reader.read('source').stringValue,
        using: reader.peek('using')?.isNull == false
            ? reader.read('using').stringValue
            : null,
      );
      _addRule(config.fields, rule, '@MapField', method);
    }
    for (final annotation in _mapRelationChecker.annotationsOf(method)) {
      final reader = ConstantReader(annotation);
      final rule = _Rule(
        target: reader.read('target').stringValue,
        source: reader.read('source').stringValue,
        using: reader.peek('using')?.isNull == false
            ? reader.read('using').stringValue
            : null,
      );
      _addRule(config.relations, rule, '@MapRelation', method);
    }
    for (final annotation in _mapIgnoreChecker.annotationsOf(method)) {
      final target = ConstantReader(annotation).read('target').stringValue;
      if (!config.ignores.add(target)) {
        _duplicate('@MapIgnore', target, method);
      }
    }
    for (final annotation in _mapDefaultChecker.annotationsOf(method)) {
      final reader = ConstantReader(annotation);
      final target = reader.read('target').stringValue;
      if (config.defaults.containsKey(target)) {
        _duplicate('@MapDefault', target, method);
      }
      config.defaults[target] = reader.read('value').objectValue;
    }
    final constructors = _mapConstructorChecker.annotationsOf(method).toList();
    if (constructors.length > 1) {
      throw InvalidGenerationSourceError(
        'Only one @MapConstructor is allowed.',
        element: method,
      );
    }
    if (constructors.isNotEmpty) {
      config.constructorName = ConstantReader(
        constructors.single,
      ).read('name').stringValue;
    }
    return config;
  }

  void _validateConfig(
    _MethodConfig config,
    Set<String> targetNames,
    Map<String, FormalParameterElement> constructorParameters,
    Map<String, FieldElement> targetFields,
    MethodElement method,
  ) {
    final configured = <String>{
      ...config.fields.keys,
      ...config.relations.keys,
      ...config.ignores,
      ...config.defaults.keys,
    };
    final unknown = configured.where((target) => !targetNames.contains(target));
    if (unknown.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Unknown target field(s): ${unknown.join(', ')}.',
        element: method,
      );
    }
    for (final target in config.fields.keys) {
      if (config.relations.containsKey(target) ||
          config.ignores.contains(target) ||
          config.defaults.containsKey(target)) {
        throw InvalidGenerationSourceError(
          'Conflicting mapping rules for target `$target`.',
          element: method,
        );
      }
    }
    for (final target in config.relations.keys) {
      if (config.ignores.contains(target) ||
          config.defaults.containsKey(target)) {
        throw InvalidGenerationSourceError(
          'Conflicting mapping rules for target `$target`.',
          element: method,
        );
      }
      if (!constructorParameters.containsKey(target) &&
          !targetFields.containsKey(target)) {
        throw InvalidGenerationSourceError(
          'Unknown relation target `$target`.',
          element: method,
        );
      }
    }
  }

  ConstructorElement _constructor(
    InterfaceElement target,
    _MethodConfig config,
    MethodElement method,
  ) {
    final name = config.constructorName;
    final constructor = name == null
        ? target.unnamedConstructor
        : target.constructors
              .where((candidate) => candidate.name == name)
              .firstOrNull;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        name == null
            ? '${target.name} has no unnamed constructor.'
            : '${target.name} has no constructor named `$name`.',
        element: method,
      );
    }
    if (constructor.isPrivate) {
      _unsupported(method, 'target constructor must be accessible');
    }
    return constructor;
  }

  Map<String, DartType> _properties(InterfaceElement element) {
    final properties = <String, DartType>{};
    void addFrom(InterfaceElement type) {
      for (final parameter
          in type.unnamedConstructor?.formalParameters ??
              const <FormalParameterElement>[]) {
        final name = parameter.name;
        if (name != null) properties.putIfAbsent(name, () => parameter.type);
      }
      for (final field in type.fields.where((field) => !field.isStatic)) {
        final name = field.name;
        if (name != null) properties.putIfAbsent(name, () => field.type);
      }
      for (final getter
          in type.interfaceMembers.values.whereType<GetterElement>().where(
            (getter) => !getter.isStatic,
          )) {
        final name = getter.name;
        if (name != null) properties.putIfAbsent(name, () => getter.returnType);
      }
    }

    addFrom(element);
    for (final supertype in element.allSupertypes) {
      addFrom(supertype.element);
    }
    return properties;
  }

  _CollectionType? _collectionType(DartType type) {
    if (type is! InterfaceType || type.typeArguments.length != 1) return null;
    final name = type.element.name;
    final uri = type.element.library.uri.toString();
    _CollectionKind? kind;
    if (uri == 'dart:core' && name == 'List') {
      kind = _CollectionKind.list;
    } else if (uri == 'dart:core' && name == 'Set') {
      kind = _CollectionKind.set;
    } else if (uri == 'dart:core' && name == 'Iterable') {
      kind = _CollectionKind.iterable;
    } else if (name == 'ToMany') {
      kind = _CollectionKind.toMany;
    }
    if (kind == null) return null;
    return _CollectionType(kind, type.typeArguments.single, _isNullable(type));
  }

  _RelationKind? _relationKind(DartType type) {
    if (type is! InterfaceType || type.typeArguments.length != 1) return null;
    if (type.element.name == 'ToMany') return _RelationKind.toMany;
    if (type.element.name == 'ToOne') return _RelationKind.toOne;
    return null;
  }

  DartType? _toOneItemType(DartType type) =>
      _relationKind(type) == _RelationKind.toOne
      ? (type as InterfaceType).typeArguments.single
      : null;

  String _literal(DartObject object, MethodElement method) {
    final reader = ConstantReader(object);
    if (reader.isNull) return 'null';
    if (reader.isString) return jsonEncode(reader.stringValue);
    if (reader.isBool) return reader.boolValue.toString();
    if (reader.isInt) return reader.intValue.toString();
    if (reader.isDouble) return reader.doubleValue.toString();
    if (reader.isList) {
      return 'const [${reader.listValue.map((value) => _literal(value, method)).join(', ')}]';
    }
    if (reader.isSet) {
      return 'const {${reader.setValue.map((value) => _literal(value, method)).join(', ')}}';
    }
    if (reader.isMap) {
      final entries = reader.mapValue.entries.map(
        (entry) =>
            '${_literal(entry.key!, method)}: ${_literal(entry.value!, method)}',
      );
      return 'const {${entries.join(', ')}}';
    }
    throw InvalidGenerationSourceError(
      '@MapDefault supports null, bool, num, String, List, Set, and Map values.',
      element: method,
    );
  }

  String _argument(
    FormalParameterElement parameter,
    String name,
    String value,
  ) => parameter.isNamed ? '$name: $value' : value;

  bool _assignable(DartType from, DartType to, MethodElement method) =>
      method.library.typeSystem.isAssignableTo(from, to, strictCasts: true);

  bool _isNullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question;

  Never _typeError(
    DartType source,
    DartType target,
    String targetLabel,
    MethodElement method,
  ) {
    throw InvalidGenerationSourceError(
      'Cannot assign ${source.getDisplayString()} to '
      '${target.getDisplayString()} for $targetLabel.',
      element: method,
    );
  }

  void _validateMethod(MethodElement method) {
    if (method.isStatic || method.typeParameters.isNotEmpty) {
      _unsupported(method, 'must be an instance, non-generic method');
    }
    if (method.formalParameters.length != 1 ||
        !method.formalParameters.single.isRequiredPositional) {
      _unsupported(
        method,
        'must have exactly one required positional parameter',
      );
    }
  }

  void _addRule(
    Map<String, _Rule> rules,
    _Rule rule,
    String annotation,
    MethodElement method,
  ) {
    if (rules.containsKey(rule.target)) {
      _duplicate(annotation, rule.target, method);
    }
    rules[rule.target] = rule;
  }

  Never _duplicate(String annotation, String target, MethodElement method) {
    throw InvalidGenerationSourceError(
      'Duplicate $annotation for target `$target`.',
      element: method,
    );
  }

  InterfaceElement? _classElement(DartType type) =>
      type is InterfaceType ? type.element : null;

  Never _unsupported(MethodElement method, String reason) {
    throw InvalidGenerationSourceError(
      'Unsupported mapping method `${method.name}`: $reason.',
      element: method,
    );
  }
}

class _MethodConfig {
  final Map<String, _Rule> fields = {};
  final Map<String, _Rule> relations = {};
  final Set<String> ignores = {};
  final Map<String, DartObject> defaults = {};
  String? constructorName;
}

class _Rule {
  const _Rule({
    required this.target,
    required this.source,
    required this.using,
  });

  final String target;
  final String source;
  final String? using;
}

class _Converter {
  const _Converter(this.call, this.inputType, this.outputType);

  final String call;
  final DartType inputType;
  final DartType outputType;
}

class _ResolvedConverter {
  const _ResolvedConverter(this.call, {this.nullGuard = false});

  final String call;
  final bool nullGuard;
}

enum _CollectionKind { list, set, iterable, toMany }

class _CollectionType {
  const _CollectionType(this.kind, this.itemType, this.isNullable);

  final _CollectionKind kind;
  final DartType itemType;
  final bool isNullable;
}

enum _RelationKind { toMany, toOne }

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
