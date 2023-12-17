import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../access/access.dart';
import '../../access/primitives/serializer.dart';
import '../migration.dart';
import 'driver.dart';

class SqliteDriver implements DatabaseDriver {
  final DatabaseConnection config;

  final _serializer = const _SqliteSerializer();
  Database? _database;

  SqliteDriver(this.config);

  @override
  Future<DatabaseDriver> connect() async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;
    _database = await databaseFactory.openDatabase(config.database,
        options: OpenDatabaseOptions(onOpen: (db) async {
      if (config.dbForeignKeys) {
        await db.execute('PRAGMA foreign_keys = ON;');
      }
    }));
    return this;
  }

  @override
  Future<void> disconnect() async {
    if (!isOpen) return;
    await _database!.close();
    _database = null;
  }

  @override
  bool get isOpen => _database?.isOpen ?? false;

  @override
  DatabaseDriverType get type => DatabaseDriverType.sqlite;

  @override
  TableBlueprint get blueprint => _SqliteTableBlueprint();

  Future<Database> _getDatabase() async {
    final db = _database;
    if (db == null) throw Exception('Database is not open');
    if (!db.isOpen) await connect();
    return _database!;
  }

  @override
  Future<void> execute(String script) async {
    return (await _getDatabase()).execute(script);
  }

  @override
  Future<List<Map<String, dynamic>>> query(Query query) async {
    final sql = _serializer.acceptReadQuery(query);
    return (await _getDatabase()).rawQuery(sql);
  }

  @override
  Future<List<Map<String, dynamic>>> update(UpdateQuery query) async {
    final sql = _serializer.acceptUpdateQuery(query);
    return (await _getDatabase()).rawQuery(sql);
  }

  @override
  Future<List<Map<String, dynamic>>> delete(DeleteQuery query) async {
    final sql = _serializer.acceptDeleteQuery(query);
    return (await _getDatabase()).rawQuery(sql);
  }

  @override
  Future<int> insert(String tableName, Map<String, dynamic> data) async {
    return (await _getDatabase()).insert(tableName, data);
  }

  @override
  PrimitiveSerializer get serializer => _serializer;
}

class _SqliteSerializer implements PrimitiveSerializer {
  const _SqliteSerializer();

  @override
  String acceptReadQuery(Query query) {
    final queryBuilder = StringBuffer();

    /// SELECT
    final selectStatement = acceptSelect(query.fieldSelections.toList());
    queryBuilder.write(selectStatement);
    queryBuilder.write('FROM ${query.tableName}');

    /// WHERE
    final whereClause = query.whereClause;
    if (whereClause != null) {
      queryBuilder.write(' WHERE ${acceptWhereClause(whereClause)}');
    }

    /// ORDER BY
    final orderBys = query.orderByProps;
    if (orderBys.isNotEmpty) {
      queryBuilder.write(' ORDER BY ${acceptOrderBy(orderBys.toList())}');
    }

    /// LIMIT
    final limit = query.limit;
    if (limit != null) {
      queryBuilder.write(' LIMIT ${acceptLimit(limit)}');
    }

    return '${queryBuilder.toString()}$terminator';
  }

  @override
  String acceptUpdateQuery(UpdateQuery query) {
    final queryBuilder = StringBuffer();

    queryBuilder.write('UPDATE ${query.tableName}');

    final values = query.values.entries
        .map((e) => '${e.key} = ${acceptDartValue(e.value)}')
        .join(', ');

    queryBuilder
      ..write(' SET $values')
      ..write(' WHERE ${acceptWhereClause(query.whereClause)}')
      ..write(terminator);

    return queryBuilder.toString();
  }

  @override
  String acceptDeleteQuery(DeleteQuery query) {
    final queryBuilder = StringBuffer();

    queryBuilder
      ..write('DELETE FROM ${query.tableName}')
      ..write(' WHERE ${acceptWhereClause(query.whereClause)}')
      ..write(terminator);

    return queryBuilder.toString();
  }

  @override
  String acceptSelect(List<String> fields) {
    return fields.isEmpty ? 'SELECT * ' : 'SELECT ${fields.join(', ')}';
  }

  @override
  String acceptWhereClause(WhereClause clause) {
    if (clause is CompositeWhereClause) {
      final whereBuilder = StringBuffer();
      whereBuilder.write(_acceptWhereClauseValue(clause.value));
      for (final subpart in clause.subparts) {
        final LogicalOperator operator = subpart.$1;
        final WhereClauseValue value = subpart.$2.value;
        whereBuilder
            .write(' ${operator.name} ${_acceptWhereClauseValue(value)}');
      }
      return whereBuilder.toString();
    }
    return _acceptWhereClauseValue(clause.value);
  }

  @override
  String acceptOrderBy(List<OrderBy> orderBys) {
    direction(OrderByDirection dir) =>
        dir == OrderByDirection.asc ? 'ASC' : 'DESC';
    return orderBys
        .map((e) => '${e.field} ${direction(e.direction)}')
        .join(', ');
  }

  @override
  String acceptLimit(int limit) => '$limit';

  @override
  String get terminator => ';';

  @override
  dynamic acceptDartValue(dartValue) => switch (dartValue.runtimeType) {
        const (int) || const (double) => dartValue,
        const (List<String>) => '(${dartValue.map((e) => "'$e'").join(', ')})',
        const (List<int>) ||
        const (List<num>) ||
        const (List<double>) =>
          '(${dartValue.join(', ')})',
        _ => "'$dartValue'"
      };

  String _acceptWhereClauseValue(WhereClauseValue clauseVal) {
    final field = clauseVal.field;
    final value = clauseVal.comparer.value;
    final valueOperator = clauseVal.comparer.operator;
    final wrapped = acceptDartValue(value);

    if (valueOperator == Operator.BETWEEN) {
      if (value is! List || value.length != 2) {
        throw ArgumentError.value(value, null,
            'BETWEEN operator expects a List Value and must have 2 values');
      }
    }

    return switch (valueOperator) {
      Operator.LESS_THAN => '$field < $wrapped',
      Operator.GREAT_THAN => '$field > $wrapped',
      Operator.LESS_THEN_OR_EQUAL_TO => '$field <= $wrapped',
      Operator.GREATER_THAN_OR_EQUAL_TO => '$field >= $wrapped',
      //
      Operator.EQUAL => '$field = $wrapped',
      Operator.NOT_EQUAL => '$field != $wrapped',
      //
      Operator.IN => '$field IN $wrapped',
      Operator.NOT_IN => '$field NOT IN $wrapped',
      //
      Operator.LIKE => '$field LIKE $wrapped',
      Operator.NOT_LIKE => '$field NOT LIKE $wrapped',
      //
      Operator.NULL => '$field IS NULL',
      Operator.NOT_NULL => '$field IS NOT NULL',
      //
      Operator.BETWEEN =>
        '$field BETWEEN ${acceptDartValue(value[0])} AND ${acceptDartValue(value[1])}',
      Operator.NOT_BETWEEN =>
        '$field NOT BETWEEN ${acceptDartValue(value[0])} AND ${acceptDartValue(value[1])}'
    };
  }
}

class _SqliteTableBlueprint implements TableBlueprint {
  final List<String> _statements = [];

  @override
  void id() {
    _statements.add('id INTEGER PRIMARY KEY');
  }

  @override
  void string(String name) {
    _statements.add('$name TEXT');
  }

  @override
  void double(String name) {
    _statements.add('$name REAL');
  }

  @override
  void float(String name) {
    _statements.add('$name REAL');
  }

  @override
  void integer(String name) {
    _statements.add('$name INTEGER');
  }

  @override
  void blob(String name) {
    _statements.add('$name BLOB');
  }

  @override
  void boolean(String name) {
    _statements.add('$name INTEGER');
  }

  @override
  void datetime(String name) {
    _statements.add('$name DATETIME');
  }

  @override
  void timestamp(String name) {
    _statements.add('$name DATETIME');
  }

  @override
  void timestamps({
    String createdAt = 'created_at',
    String updatedAt = 'updated_at',
  }) {
    _statements.add('$createdAt DATETIME');
    _statements.add('$updatedAt DATETIME');
  }

  @override
  String createScript(String tableName) {
    return 'CREATE TABLE $tableName (${_statements.join(', ')});';
  }

  @override
  String dropScript(String tableName) {
    return 'DROP TABLE IF EXISTS $tableName;';
  }

  @override
  String renameScript(String oldName, String toName) {
    final StringBuffer renameScript = StringBuffer();
    renameScript
      ..writeln(
          'CREATE TABLE temp_info AS SELECT * FROM PRAGMA table_info(\'$oldName\');')
      ..writeln('CREATE TABLE temp_data AS SELECT * FROM $oldName;')
      ..writeln('CREATE TABLE $toName AS SELECT * FROM temp_data WHERE 1 = 0;')
      ..writeln('INSERT INTO $toName SELECT * FROM temp_data;')
      ..writeln('DROP TABLE temp_info; DROP TABLE temp_data;');
    return renameScript.toString();
  }
}
