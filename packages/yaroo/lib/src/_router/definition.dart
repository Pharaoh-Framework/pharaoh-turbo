part of 'router.dart';

enum RouteDefinitionType { route, group, middleware }

class RouteMapping {
  final List<HTTPMethod> methods;
  final String _path;

  @visibleForTesting
  String get stringVal => '${methods.map((e) => e.name).toList()}: $_path';

  String get path => cleanRoute(_path);

  const RouteMapping(this.methods, this._path);

  RouteMapping prefix(String prefix) => RouteMapping(methods, '$prefix$_path');
}

abstract class RouteDefinition {
  late RouteMapping route;
  final RouteDefinitionType type;

  RouteDefinition(this.type);

  void commit(Spanner spanner);

  RouteDefinition _prefix(String prefix) => this..route = route.prefix(prefix);
}

class UseAliasedMiddleware {
  final String alias;

  UseAliasedMiddleware(this.alias);

  Iterable<HandlerFunc> get mdw => ApplicationFactory.resolveMiddlewareForGroup(alias);

  RouteGroupDefinition group(String name, List<RouteDefinition> routes, {String? prefix}) =>
      RouteGroupDefinition._(name, prefix: prefix, definitions: routes)..middleware(mdw);
}

class _MiddlewareDefinition extends RouteDefinition {
  final HandlerFunc mdw;

  _MiddlewareDefinition(this.mdw, RouteMapping route) : super(RouteDefinitionType.middleware) {
    this.route = route;
  }

  @override
  void commit(Spanner spanner) => spanner.addMiddleware(route.path, mdw);
}

typedef ControllerMethodDefinition = (Type controller, Symbol symbol);

class ControllerMethod {
  final ControllerMethodDefinition method;
  final List<ControllerMethodParam> params;

  String get methodName => symbolToString(method.$2);

  Type get controller => method.$1;

  ControllerMethod(this.method, [this.params = const []]);
}

class ControllerMethodParam {
  final String name;
  final Type type;
  final bool optional;
  final dynamic defaultValue;
  final RequestAnnotation? meta;

  final BaseDTO? dto;

  const ControllerMethodParam(this.name, this.type, {this.meta, this.optional = false, this.defaultValue, this.dto});
}

class ControllerRouteMethodDefinition extends RouteDefinition {
  final ControllerMethod method;

  ControllerRouteMethodDefinition(ControllerMethodDefinition defn, RouteMapping mapping)
      : method = parseControllerMethod(defn),
        super(RouteDefinitionType.route) {
    route = mapping;
  }

  @override
  void commit(Spanner spanner) {
    final handler = ApplicationFactory.buildControllerMethod(method);
    for (final routeMethod in route.methods) {
      spanner.addRoute(routeMethod, route.path, useRequestHandler(handler));
    }
  }
}

class RouteGroupDefinition extends RouteDefinition {
  final String name;
  final List<RouteDefinition> defns = [];

  List<String> get paths => defns.map((e) => e.route.stringVal).toList();

  RouteGroupDefinition._(
    this.name, {
    String? prefix,
    Iterable<RouteDefinition> definitions = const [],
  }) : super(RouteDefinitionType.group) {
    route = RouteMapping([HTTPMethod.ALL], '/${prefix ?? name.toLowerCase()}');
    if (definitions.isEmpty) {
      throw StateError('Route definitions not provided for group');
    }
    _unwrapRoutes(definitions);
  }

  void _unwrapRoutes(Iterable<RouteDefinition> routes) {
    for (final subRoute in routes) {
      if (subRoute is! RouteGroupDefinition) {
        defns.add(subRoute._prefix(route.path));
        continue;
      }

      for (var e in subRoute.defns) {
        defns.add(e._prefix(route.path));
      }
    }
  }

  void middleware(Iterable<HandlerFunc> func) {
    if (func.isEmpty) return;
    final mdwDefn = _MiddlewareDefinition(func.reduce((val, e) => val.chain(e)), route);
    defns.insert(0, mdwDefn);
  }

  @override
  void commit(Spanner spanner) {
    for (final mdw in defns) {
      mdw.commit(spanner);
    }
  }
}

typedef RequestHandlerWithApp = Function(Application app, Request req, Response res);

class FunctionalRouteDefinition extends RouteDefinition {
  final HTTPMethod method;
  final String path;

  final HandlerFunc? _middleware;
  final HandlerFunc? _requestHandler;

  FunctionalRouteDefinition.route(this.method, this.path, RequestHandler handler)
      : _middleware = null,
        _requestHandler = useRequestHandler(handler),
        super(RouteDefinitionType.route) {
    route = RouteMapping([method], path);
  }

  FunctionalRouteDefinition.middleware(this.path, HandlerFunc handler)
      : _requestHandler = null,
        _middleware = handler,
        method = HTTPMethod.ALL,
        super(RouteDefinitionType.middleware) {
    route = RouteMapping([method], path);
  }

  @override
  void commit(Spanner spanner) {
    if (_middleware != null) {
      spanner.addMiddleware<HandlerFunc>(path, _middleware!);
    } else if (_requestHandler != null) {
      spanner.addRoute<HandlerFunc>(method, path, _requestHandler!);
    }
  }
}
