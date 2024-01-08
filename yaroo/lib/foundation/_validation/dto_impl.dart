part of 'dto.dart';

abstract interface class _BaseDTOImpl {
  final Map<String, dynamic> _databag = {};

  Map<String, dynamic> get data => UnmodifiableMapView(_databag);

  void make(Request request) {
    _databag.clear();
    final (data, errors) = schema.validateSync(request.body ?? {});
    if (errors.isNotEmpty) throw RequestValidationError.errors(ValidationErrorLocation.body, errors);
    _databag.addAll(Map<String, dynamic>.from(data));
  }

  EzSchema? _schemaCache;

  EzSchema get schema {
    if (_schemaCache != null) return _schemaCache!;

    final mirror = dtoReflector.reflectType(runtimeType) as r.ClassMirror;
    final properties = mirror.getters.where((e) => e.isAbstract);

    final entries = properties.map((prop) {
      final returnType = prop.reflectedReturnType;
      final meta = prop.metadata.whereType<ClassPropertyValidator>().firstOrNull ?? ezRequired(returnType);

      if (meta.propertyType != returnType) {
        throw ArgumentError(
            'Type Mismatch between ${meta.runtimeType}(${meta.propertyType}) & $runtimeType class property ${prop.simpleName}->($returnType)');
      }

      return MapEntry(meta.name ?? prop.simpleName, meta.validator);
    });

    final entriesToMap =
        entries.fold<Map<String, EzValidator<dynamic>>>({}, (prev, curr) => prev..[curr.key] = curr.value);
    return _schemaCache = EzSchema.shape(entriesToMap, fillSchema: false);
  }
}
