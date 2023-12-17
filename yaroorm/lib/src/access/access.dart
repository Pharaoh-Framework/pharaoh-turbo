import '../database/driver/driver.dart';
import '../database/entity.dart';
import '../reflection/entity_helpers.dart';

part 'operations/query.dart';
part 'primitives/where.dart';

mixin FindOperation {
  Future<T?> findOne<T>();

  Future<List<T>> findMany<T>();
}

mixin InsertOperation {
  Future<T> insert<T extends Entity>(T model);
}

mixin LimitOperation<ReturnType> {
  ReturnType take<T>(int limit);
}

mixin UpdateOperation {
  Future<void> _update(WhereClause where, Map<String, dynamic> values);
}

mixin DeleteOperation {
  Future<void> _delete(WhereClause where);
}

typedef OrderBy = ({String field, OrderByDirection direction});

mixin OrderByOperation<ReturnType> {
  ReturnType orderBy(String field, OrderByDirection direction);
}

abstract interface class QueryBase {
  final String tableName;
  final DatabaseDriver driver;

  QueryBase(this.tableName, this.driver);

  String get statement;
}

abstract class Query extends QueryBase
    with
        FindOperation,
        LimitOperation,
        UpdateOperation,
        DeleteOperation,
        InsertOperation,
        OrderByOperation<Query> {
  late final Set<String> fieldSelections;
  late final Set<OrderBy> orderByProps;

  late WhereClause? _whereClause;
  late int? _limit;

  Query(super.tableName, super.driver)
      : fieldSelections = {},
        orderByProps = {},
        _whereClause = null,
        _limit = null;

  factory Query.make(String tableName, DatabaseDriver driver) =>
      _QueryImpl(tableName, driver);

  int? get limit => _limit;

  WhereClause? get whereClause => _whereClause;

  WhereClause where<Value>(String field, String condition, Value value);

  @override
  Future<List<T>> take<T>(int limit);

  @override
  String get statement => driver.serializer.acceptReadQuery(this);
}

class UpdateQuery extends QueryBase {
  final WhereClause whereClause;
  final Map<String, dynamic> values;

  UpdateQuery(
    super.tableName,
    super.driver, {
    required this.whereClause,
    required this.values,
  });

  @override
  String get statement => driver.serializer.acceptUpdateQuery(this);
}

class DeleteQuery extends QueryBase {
  final WhereClause whereClause;

  DeleteQuery(
    super.tableName,
    super.driver, {
    required this.whereClause,
  });

  @override
  String get statement => driver.serializer.acceptDeleteQuery(this);
}
