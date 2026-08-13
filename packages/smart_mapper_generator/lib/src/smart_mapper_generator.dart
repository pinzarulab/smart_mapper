import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
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

    final methods =
        element.methods.where((method) => method.isAbstract).toList();
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
      ..writeln(
        '$mapperName create$mapperName() => const _\$$mapperName();',
      );

    return buffer.toString();
  }

  void _writeMethod(
    StringBuffer buffer,
    MethodElement method,
    List<MethodElement> mappingMethods,
  ) {
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

    final sourceParameter = method.formalParameters.single;
    final sourceType = sourceParameter.type;
    final targetType = method.returnType;
    final sourceElement = _classElement(sourceType);
    final targetElement = _classElement(targetType);
    if (sourceElement == null || targetElement == null) {
      _unsupported(method, 'source and return types must be classes');
    }

    final constructor = targetElement.unnamedConstructor;
    if (constructor == null) {
      _unsupported(
        method,
        'return type must have an unnamed constructor',
      );
    }
    if (constructor.isPrivate) {
      _unsupported(
        method,
        'return type unnamed constructor must be accessible',
      );
    }

    final renames = _readRenames(method);
    final relations = _toManyFields(targetElement);
    final targetNames = <String>{
      ...constructor.formalParameters
          .map((parameter) => parameter.name)
          .whereType<String>(),
      ...relations.map((field) => field.name).whereType<String>(),
    };
    final unknownTargets = renames.keys.where(
      (name) => !targetNames.contains(name),
    );
    if (unknownTargets.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Unknown target field(s) on ${targetElement.name}: '
        '${unknownTargets.join(', ')}.',
        element: method,
      );
    }

    final sourceProperties = _properties(sourceElement);
    final arguments = <String>[];
    for (final parameter in constructor.formalParameters) {
      final parameterName = parameter.name!;
      final sourceName = renames[parameterName] ?? parameterName;
      final sourcePropertyType = sourceProperties[sourceName];
      if (sourcePropertyType == null && parameter.isOptionalNamed) {
        continue;
      }
      if (sourcePropertyType == null) {
        throw InvalidGenerationSourceError(
          'Cannot map ${targetElement.name}.$parameterName: '
          '${sourceElement.name} has no readable property `$sourceName`. '
          'Add @MapField(target: \'$parameterName\', source: \'...\') '
          'to ${method.name}.',
          element: method,
        );
      }
      final value = _mappedValue(
        sourceExpression: '${sourceParameter.name}.$sourceName',
        sourceType: sourcePropertyType,
        targetType: parameter.type,
        mappingMethods: mappingMethods,
        method: method,
      );
      if (parameter.isNamed) {
        arguments.add('$parameterName: $value');
      } else {
        arguments.add(value);
      }
    }

    final returnName = targetType.getDisplayString();
    final sourceName = sourceType.getDisplayString();
    buffer
      ..writeln('  @override')
      ..writeln(
        '  $returnName ${method.name}($sourceName ${sourceParameter.name}) {',
      );
    if (relations.isEmpty) {
      buffer.writeln('    return $returnName(');
    } else {
      buffer.writeln('    final target = $returnName(');
    }
    for (final argument in arguments) {
      buffer.writeln('      $argument,');
    }
    buffer.writeln('    );');

    for (final relation in relations) {
      final relationName = relation.name!;
      final sourcePropertyName = renames[relationName] ?? relationName;
      final sourcePropertyType = sourceProperties[sourcePropertyName];
      if (sourcePropertyType == null) {
        throw InvalidGenerationSourceError(
          'Cannot map ${targetElement.name}.$relationName: '
          '${sourceElement.name} has no readable property '
          '`$sourcePropertyName`.',
          element: method,
        );
      }
      final value = _mappedValue(
        sourceExpression: '${sourceParameter.name}.$sourcePropertyName',
        sourceType: sourcePropertyType,
        targetType: relation.type,
        mappingMethods: mappingMethods,
        method: method,
        forAddAll: true,
      );
      buffer.writeln('    target.$relationName.addAll($value);');
    }

    if (relations.isNotEmpty) {
      buffer.writeln('    return target;');
    }
    buffer.writeln('  }');
  }

  String _mappedValue({
    required String sourceExpression,
    required DartType sourceType,
    required DartType targetType,
    required List<MethodElement> mappingMethods,
    required MethodElement method,
    bool forAddAll = false,
  }) {
    if (_sameType(sourceType, targetType)) return sourceExpression;

    final sourceItemType = _collectionItemType(sourceType);
    final targetItemType = _collectionItemType(targetType);
    if (sourceItemType == null || targetItemType == null) {
      return sourceExpression;
    }

    if (_sameType(sourceItemType, targetItemType)) {
      return forAddAll ? sourceExpression : '$sourceExpression.toList()';
    }

    final converters = mappingMethods.where((candidate) {
      if (candidate.formalParameters.length != 1) return false;
      return _sameType(
              candidate.formalParameters.single.type, sourceItemType) &&
          _sameType(candidate.returnType, targetItemType);
    }).toList();
    if (converters.isEmpty) {
      throw InvalidGenerationSourceError(
        'Cannot map collection item ${sourceItemType.getDisplayString()} to '
        '${targetItemType.getDisplayString()}. Add a mapper method with that '
        'source and return type.',
        element: method,
      );
    }
    if (converters.length > 1) {
      throw InvalidGenerationSourceError(
        'Multiple mapper methods convert '
        '${sourceItemType.getDisplayString()} to '
        '${targetItemType.getDisplayString()}: '
        '${converters.map((candidate) => candidate.name).join(', ')}.',
        element: method,
      );
    }

    final mapped = '$sourceExpression.map(${converters.single.name})';
    return forAddAll ? mapped : '$mapped.toList()';
  }

  Map<String, String> _readRenames(MethodElement method) {
    final result = <String, String>{};
    for (final annotation in _mapFieldChecker.annotationsOf(method)) {
      final reader = ConstantReader(annotation);
      final target = reader.read('target').stringValue;
      final source = reader.read('source').stringValue;
      if (result.containsKey(target)) {
        throw InvalidGenerationSourceError(
          'Duplicate @MapField for target `$target`.',
          element: method,
        );
      }
      result[target] = source;
    }
    return result;
  }

  Map<String, DartType> _properties(InterfaceElement element) {
    final properties = <String, DartType>{};
    void addFrom(InterfaceElement type) {
      for (final parameter in type.unnamedConstructor?.formalParameters ??
          const <FormalParameterElement>[]) {
        final name = parameter.name;
        if (name != null) properties.putIfAbsent(name, () => parameter.type);
      }
      for (final field in type.fields.where((field) => !field.isStatic)) {
        final name = field.name;
        if (name != null) properties.putIfAbsent(name, () => field.type);
      }
      for (final getter in type.getters.where((getter) => !getter.isStatic)) {
        final name = getter.name;
        if (name != null) properties.putIfAbsent(name, () => getter.returnType);
      }
      for (final getter in type.interfaceMembers.values
          .whereType<GetterElement>()
          .where((getter) => !getter.isStatic)) {
        final name = getter.name;
        if (name != null) properties.putIfAbsent(name, () => getter.returnType);
      }
    }

    addFrom(element);
    for (final supertype in element.allSupertypes) {
      final superElement = supertype.element;
      addFrom(superElement);
    }
    return properties;
  }

  List<FieldElement> _toManyFields(InterfaceElement element) => element.fields
      .where(
        (field) =>
            !field.isStatic &&
            !field.isPrivate &&
            field.type is InterfaceType &&
            (field.type as InterfaceType).element.name == 'ToMany',
      )
      .toList();

  DartType? _collectionItemType(DartType type) {
    if (type is! InterfaceType || type.typeArguments.length != 1) return null;
    final name = type.element.name;
    if (name != 'List' && name != 'Iterable' && name != 'ToMany') return null;
    return type.typeArguments.single;
  }

  bool _sameType(DartType left, DartType right) {
    if (left is InterfaceType && right is InterfaceType) {
      if (left.element != right.element ||
          left.typeArguments.length != right.typeArguments.length) {
        return false;
      }
      for (var index = 0; index < left.typeArguments.length; index++) {
        if (!_sameType(left.typeArguments[index], right.typeArguments[index])) {
          return false;
        }
      }
      return left.nullabilitySuffix == right.nullabilitySuffix;
    }
    return left.getDisplayString() == right.getDisplayString();
  }

  InterfaceElement? _classElement(DartType type) {
    if (type is InterfaceType) return type.element;
    return null;
  }

  Never _unsupported(MethodElement method, String reason) {
    throw InvalidGenerationSourceError(
      'Unsupported mapping method `${method.name}`: $reason.',
      element: method,
    );
  }
}
