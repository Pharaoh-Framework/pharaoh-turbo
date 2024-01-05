import 'package:meta/meta.dart';

import '../database/driver/driver.dart';
import '../database/entity.dart';
import '../primitives/where.dart';
import '../reflection/util.dart';

part 'query_impl.dart';

mixin ReadOperation<Result> {
  Future<Result?> get([dynamic id]);

  Future<List<Result>> all();
}

mixin FindOperation<Result> {
  Future<Result?> findOne();

  Future<List<Result>> findMany();
}

mixin InsertOperation {
  Future insert<T extends Entity>(T entity);

  Future insertMany<T extends Entity>(List<T> entities);
}

mixin LimitOperation<ReturnType> {
  Future<List<ReturnType>> take(int limit);
}

mixin UpdateOperation<Result> {
  UpdateQuery update({required WhereClause<Result> Function(Query query) where, required Map<String, dynamic> values});
}

mixin DeleteOperation<Result> {
  DeleteQuery delete(WhereClause<Result> Function(Query query) where);
}

typedef OrderBy = ({String field, OrderByDirection direction});

mixin OrderByOperation<ReturnType> {
  ReturnType orderByAsc(String field);

  ReturnType orderByDesc(String field);
}

abstract interface class QueryBase<Owner> {
  final String tableName;

  String? database;

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

abstract interface class Query<EntityType> extends QueryBase<Query<EntityType>>
    with
        ReadOperation<EntityType>,
        WhereOperation<EntityType>,
        LimitOperation<EntityType>,
        OrderByOperation<Query<EntityType>>,
        InsertOperation,
        DeleteOperation<EntityType>,
        UpdateOperation<EntityType> {
  late final Set<String> fieldSelections;
  late final Set<OrderBy> orderByProps;
  late final List<WhereClause<EntityType>> whereClauses;

  late int? _limit;

  Query(super.tableName)
      : fieldSelections = {},
        orderByProps = {},
        whereClauses = [],
        _limit = null;

  static Query<Model> table<Model>([String? tableName]) {
    if (Model != Entity && Model != dynamic) {
      reflectEntity<Model>(); // test type to be sure it's a subtype of Entity
      tableName ??= typeToTableName(Model);
    }
    assert(tableName != null, 'Either provide Entity Type or tableName');
    return QueryImpl<Model>(tableName!);
  }

  int? get limit => _limit;

  @override
  DeleteQuery delete(WhereClause<EntityType> Function(Query<EntityType> query) where) {
    return DeleteQuery(tableName, whereClause: where(this)).driver(queryDriver);
  }

  @override
  UpdateQuery update(
      {required WhereClause<EntityType> Function(Query<EntityType> query) where,
      required Map<String, dynamic> values}) {
    return UpdateQuery(tableName, whereClause: where(this), values: values).driver(queryDriver);
  }
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
