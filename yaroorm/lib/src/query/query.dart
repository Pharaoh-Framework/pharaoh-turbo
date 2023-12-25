import 'package:meta/meta.dart';
import 'package:yaroorm/src/database/entity.dart';

import '../_reflection/entity_helpers.dart';
import '../database/driver/driver.dart';

part 'primitives/where.dart';
part 'primitives/where_impl.dart';
part 'query_impl.dart';

mixin ReadOperation {
  Future<dynamic> get<T extends Entity>([dynamic id]);

  Future<List<dynamic>> all<T extends Entity>();
}

mixin FindOperation {
  Future<dynamic> findOne<T extends Entity>();

  Future<List<dynamic>> findMany<T extends Entity>();
}

mixin InsertOperation {
  Future insert<T extends Entity>(T entity);

  Future insertRaw(Map<String, dynamic> values);

  Future insertRawMany(List<Map<String, dynamic>> values);

  Future insertMany<T extends Entity>(List<T> entities);
}

mixin LimitOperation<ReturnType> {
  ReturnType take<T extends Entity>(int limit);
}

mixin UpdateOperation {
  UpdateQuery update({required WhereClause Function(Query query) where, required Map<String, dynamic> values});
}

mixin DeleteOperation {
  DeleteQuery delete(WhereClause Function(Query query) where);
}

typedef OrderBy = ({String field, OrderByDirection direction});

mixin OrderByOperation<ReturnType> {
  ReturnType orderByAsc(String field);

  ReturnType orderByDesc(String field);
}

abstract interface class QueryBase<Owner> {
  final String tableName;

  DriverAble? _queryDriver;

  DriverAble get queryDriver {
    if (_queryDriver == null) {
      throw StateError('Driver not set for query. Make sure you supply a driver using .driver()');
    }
    return _queryDriver!;
  }

  Owner driver(DriverAble driver) {
    _queryDriver = driver;
    return this as Owner;
  }

  Future<void> exec();

  QueryBase(this.tableName);

  String get statement;
}

abstract class Query extends QueryBase<Query>
    with
        ReadOperation,
        WhereOperation,
        LimitOperation,
        InsertOperation,
        DeleteOperation,
        UpdateOperation,
        OrderByOperation<Query> {
  late final Set<String> fieldSelections;
  late final Set<OrderBy> orderByProps;
  late final List<WhereClause> whereClauses;

  late int? _limit;

  Query(super.tableName)
      : fieldSelections = {},
        orderByProps = {},
        whereClauses = [],
        _limit = null;

  factory Query.table(String tableName) => _QueryImpl(tableName);

  int? get limit => _limit;

  @override
  DeleteQuery delete(WhereClause Function(Query query) where) {
    return DeleteQuery(tableName, whereClause: where(this)).driver(queryDriver);
  }

  @override
  UpdateQuery update({required WhereClause Function(Query query) where, required Map<String, dynamic> values}) {
    return UpdateQuery(tableName, whereClause: where(this), values: values).driver(queryDriver);
  }

  @override
  Future<List<dynamic>> take<T extends Entity>(int limit);

  @override
  String get statement => queryDriver.serializer.acceptReadQuery(this);
}

@protected
class UpdateQuery extends QueryBase<UpdateQuery> {
  final WhereClause whereClause;
  final Map<String, dynamic> values;

  UpdateQuery(super.tableName, {required this.whereClause, required this.values});

  @override
  String get statement => queryDriver.serializer.acceptUpdateQuery(this);

  @override
  Future<void> exec() => queryDriver.update(this);
}

class InsertQuery extends QueryBase<InsertQuery> {
  final Map<String, dynamic> values;

  InsertQuery(super.tableName, {required this.values});

  @override
  Future<dynamic> exec() => queryDriver.insert(this);

  @override
  String get statement => queryDriver.serializer.acceptInsertQuery(this);
}

class InsertManyQuery extends QueryBase<InsertManyQuery> {
  final List<Map<String, dynamic>> values;

  InsertManyQuery(super.tableName, {required this.values});

  @override
  String get statement => queryDriver.serializer.acceptInsertManyQuery(this);

  @override
  Future<dynamic> exec() => queryDriver.insertMany(this);
}

@protected
class DeleteQuery extends QueryBase<DeleteQuery> {
  final WhereClause whereClause;

  DeleteQuery(super.tableName, {required this.whereClause});

  @override
  String get statement => queryDriver.serializer.acceptDeleteQuery(this);

  @override
  Future<void> exec() => queryDriver.delete(this);
}
