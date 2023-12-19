part of '../access.dart';

enum OrderByDirection { asc, desc }

final class _QueryImpl extends Query {
  _QueryImpl(String tableName, DatabaseDriver driver) : super(tableName, driver);

  @override
  Query orderByAsc(String field) {
    orderByProps.add((field: field, direction: OrderByDirection.asc));
    return this;
  }

  @override
  Query orderByDesc(String field) {
    orderByProps.add((field: field, direction: OrderByDirection.desc));
    return this;
  }

  @override
  Future<T> insert<T extends Entity>(T model) async {
    if (model.enableTimestamps) {
      model.createdAt = model.updatedAt = DateTime.now().toUtc();
    }
    final dataMap = model.toJson()..remove('id');
    final recordId = await driver.insert(tableName, dataMap);
    return model..id = model.id.withKey(recordId);
  }

  @override
  Future<void> _update(WhereClause where, Map<String, dynamic> values) async {
    final query = UpdateQuery(tableName, driver, whereClause: where, values: values);
    await driver.update(query);
  }

  @override
  Future<void> _delete(WhereClause where) async {
    final query = DeleteQuery(tableName, driver, whereClause: where);
    await driver.delete(query);
  }

  @override
  Future<List<T>> all<T>() async {
    final results = await driver.query(this);
    if (results.isEmpty) return <T>[];
    if (T == dynamic) return results as dynamic;
    return results.map(jsonToEntity<T>).toList();
  }

  @override
  Future<List<T>> take<T>(int limit) async {
    _limit = limit;
    final results = await driver.query(this);
    if (results.isEmpty) return <T>[];
    if (T == dynamic) return results as dynamic;
    return results.map(jsonToEntity<T>).toList();
  }

  @override
  Future<T?> get<T>() async {
    final results = await take<T>(1);
    return results.firstOrNull;
  }

  @override
  WhereClause where<Value>(String field, String condition, [Value? value]) {
    final newClause = WhereClauseImpl(this)..clauseValue = WhereClauseValue.from(field, condition, value);
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereIn<Value>(String field, List<Value> values) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.IN, value: values));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereNotIn<Value>(String field, List<Value> values) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.NOT_IN, value: values));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereLike<Value>(String field, String pattern) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.LIKE, value: pattern));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereNotLike<Value>(String field, String pattern) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.NOT_LIKE, value: pattern));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereNull(String field) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.NULL, value: null));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereNotNull(String field) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.NOT_NULL, value: null));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereBetween<Value>(String field, List<Value> args) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.BETWEEN, value: args));
    whereClauses.add(newClause);
    return newClause;
  }

  @override
  WhereClause whereNotBetween<Value>(String field, List<Value> args) {
    final newClause = WhereClauseImpl(this)
      ..clauseValue = WhereClauseValue(field, (operator: Operator.NOT_BETWEEN, value: args));
    whereClauses.add(newClause);
    return newClause;
  }
}
