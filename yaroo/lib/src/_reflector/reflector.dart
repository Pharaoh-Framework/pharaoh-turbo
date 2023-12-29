import 'package:collection/collection.dart';
import 'package:reflectable/reflectable.dart' as r;

import '../../../http/http.dart';
import '../_container/container.dart';
import '../_router/definition.dart';
import '../_router/utils.dart';

class Injectable extends r.Reflectable {
  const Injectable()
      : super(
          r.invokingCapability,
          r.metadataCapability,
          r.newInstanceCapability,
          r.declarationsCapability,
          r.reflectedTypeCapability,
          r.typeRelationsCapability,
          const r.InstanceInvokeCapability('^[^_]'),
          r.subtypeQuantifyCapability,
        );
}

const unnamedConstructor = '';

const inject = Injectable();

List<X> filteredDeclarationsOf<X extends r.DeclarationMirror>(r.ClassMirror cm, predicate) {
  var result = <X>[];
  cm.declarations.forEach((k, v) {
    if (predicate(v)) result.add(v as X);
  });
  return result;
}

r.ClassMirror reflectType(Type type) {
  try {
    return inject.reflectType(type) as r.ClassMirror;
  } catch (e) {
    throw UnsupportedError('Unable to reflect on $type. Re-run your build command');
  }
}

extension ClassMirrorExtensions on r.ClassMirror {
  List<r.VariableMirror> get variables {
    return filteredDeclarationsOf(this, (v) => v is r.VariableMirror);
  }

  List<r.MethodMirror> get getter {
    return filteredDeclarationsOf(this, (v) => v is r.MethodMirror && v.isGetter);
  }

  List<r.MethodMirror> get setters {
    return filteredDeclarationsOf(this, (v) => v is r.MethodMirror && v.isSetter);
  }

  List<r.MethodMirror> get methods {
    return filteredDeclarationsOf(this, (v) => v is r.MethodMirror && v.isRegularMethod);
  }
}

T createNewInstance<T extends Object>(Type classType) {
  final classMirror = reflectType(classType);
  final constructorMethod =
      classMirror.declarations.entries.firstWhereOrNull((e) => e.key == '$classType')?.value as r.MethodMirror?;
  final constructorParameters = constructorMethod?.parameters ?? [];
  if (constructorParameters.isEmpty) {
    return classMirror.newInstance(unnamedConstructor, const []) as T;
  }

  final namedDeps = constructorParameters
      .where((e) => e.isNamed)
      .map((e) => (name: e.simpleName, instance: instanceFromRegistry(type: e.reflectedType)))
      .fold<Map<Symbol, dynamic>>({}, (prev, e) => prev..[Symbol(e.name)] = e.instance);

  final dependencies =
      constructorParameters.where((e) => !e.isNamed).map((e) => instanceFromRegistry(type: e.reflectedType)).toList();

  return classMirror.newInstance(unnamedConstructor, dependencies, namedDeps) as T;
}

ControllerMethod parseControllerMethod(ControllerMethodDefinition defn) {
  final type = defn.$1;
  final method = defn.$2;

  final ctrlMirror = inject.reflectType(type) as r.ClassMirror;
  if (ctrlMirror.superclass?.reflectedType != HTTPController) {
    throw ArgumentError('$type must extend BaseController');
  }

  final methods = ctrlMirror.instanceMembers.values.whereType<r.MethodMirror>();
  final actualMethod = methods.firstWhereOrNull((e) => e.simpleName == symbolToString(method));
  if (actualMethod == null) {
    throw ArgumentError('$type does not have method  #${symbolToString(method)}');
  }

  if (actualMethod.parameters.isNotEmpty) {
    throw ArgumentError.value('$type.${actualMethod.simpleName}', null, 'Controller methods cannot have parameters');
  }

  return ControllerMethod(defn);
}
