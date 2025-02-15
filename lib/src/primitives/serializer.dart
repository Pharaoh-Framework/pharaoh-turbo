import '../migration.dart';
import '../query/aggregates.dart';

import '../query/query.dart';

abstract class PrimitiveSerializer {
  const PrimitiveSerializer();

  String acceptAggregate(AggregateFunction aggregate);

  String acceptReadQuery(ReadQuery query);

  String acceptUpdateQuery(UpdateQuery query);

  String acceptDeleteQuery(DeleteQuery query);

  String acceptInsertQuery(InsertQuery query);

  String acceptInsertManyQuery(InsertManyQuery query);

  String acceptWhereClauseValue(WhereClauseValue clauseValue);

  String acceptSelect(String tableName, List<String> fields);

  String acceptOrderBy(String tableName, List<OrderBy> orderBys);

  String acceptLimit(int limit);

  String acceptOffset(int offset);

  dynamic acceptPrimitiveValue(dynamic value);

  String acceptForeignKey(TableBlueprint blueprint, ForeignKey key);

  String escapeStr(String column);

  String get terminator;
}
