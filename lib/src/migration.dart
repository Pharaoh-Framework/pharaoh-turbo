library migration;

import 'package:meta/meta.dart';
import 'package:recase/recase.dart';

import 'database/entity/entity.dart';
import 'query/query.dart';
import 'reflection.dart';

abstract class TableBlueprint {
  void id({String name = 'id', String? type, bool autoIncrement = true});

  void foreign(ForeignKey key);

  void string(String name, {bool nullable = false, String? defaultValue});

  void boolean(String name, {bool nullable = false, bool? defaultValue});

  void timestamp(String name, {bool nullable = false, DateTime? defaultValue});

  void datetime(String name, {bool nullable = false, DateTime? defaultValue});

  void date(String name, {bool nullable = false, DateTime? defaultValue});

  void time(String name, {bool nullable = false, DateTime? defaultValue});

  void blob(String name, {bool nullable = false, String? defaultValue});

  void timestamps({
    String createdAt = 'createdAt',
    String updatedAt = 'updatedAt',
  });

  /// NUMBER TYPES
  /// ----------------------------------------------------------------

  void integer(String name, {bool nullable = false, num? defaultValue});

  void double(String name, {bool nullable = false, num? defaultValue, int? precision, int? scale});

  void float(String name, {bool nullable = false, num? defaultValue, int? precision, int? scale});

  void tinyInt(String name, {bool nullable = false, num? defaultValue});

  void smallInteger(String name, {bool nullable = false, num? defaultValue});

  void mediumInteger(String name, {bool nullable = false, num? defaultValue});

  void bigInteger(String name, {bool nullable = false, num? defaultValue});

  void decimal(String name, {bool nullable = false, num? defaultValue, int? precision, int? scale});

  void numeric(String name, {bool nullable = false, num? defaultValue, int? precision, int? scale});

  void bit(String name, {bool nullable = false, int? defaultValue});

  /// STRING TYPES
  /// ----------------------------------------------------------------

  void text(
    String name, {
    int length = 1,
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void char(
    String name, {
    bool nullable = false,
    int length = 1,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void varchar(
    String name, {
    bool nullable = false,
    String? defaultValue,
    int length = 255,
    String? charset,
    String? collate,
  });

  void tinyText(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void mediumText(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void longText(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void binary(
    String name, {
    bool nullable = false,
    int size = 1,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void varbinary(
    String name, {
    bool nullable = false,
    int size = 1,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void enums(
    String name,
    List<String> values, {
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  void set(
    String name,
    List<String> values, {
    bool nullable = false,
    String? defaultValue,
    String? charset,
    String? collate,
  });

  @protected
  String createScript(String tableName);

  @protected
  String dropScript(String tableName);

  @protected
  String renameScript(String fromName, String toName);

  void ensurePresenceOf(String column);
}

typedef TableBluePrintFunc = TableBlueprint Function(TableBlueprint table);

abstract class Schema {
  final String tableName;
  final TableBluePrintFunc? _bluePrintFunc;

  Schema._(this.tableName, this._bluePrintFunc);

  String toScript(TableBlueprint table);

  static CreateSchema fromEntity<T extends Entity<T>>() {
    final entity = Query.getEntity<T>();

    TableBlueprint make(TableBlueprint table, DBEntityField field) {
      return switch (field.type) {
        const (int) => table..integer(field.columnName, nullable: field.nullable),
        const (double) || const (num) => table..double(field.columnName, nullable: field.nullable),
        const (DateTime) => table..datetime(field.columnName, nullable: field.nullable),
        _ => table..string(field.columnName, nullable: field.nullable),
      };
    }

    return CreateSchema<T>._(
      entity.tableName,
      (table) {
        table.id(
          name: entity.primaryKey.columnName,
          autoIncrement: entity.primaryKey.autoIncrement,
        );

        for (final prop in entity.columns.where((e) => !e.isPrimaryKey)) {
          table = make(table, prop);
        }

        for (final prop in entity.referencedFields) {
          final foreignKey = ForeignKey(
            entity.tableName,
            prop.columnName,
            foreignTable: prop.reference.tableName,
            foreignTableColumn: prop.reference.primaryKey.columnName,
            onUpdate: prop.onUpdate,
            onDelete: prop.onDelete,
          );
          table.foreign(foreignKey);
        }

        return table;
      },
    );
  }

  static Schema dropIfExists(CreateSchema value) => _DropSchema(value.tableName);

  static Schema rename(String from, String to) => _RenameSchema(from, to);
}

abstract class Migration {
  final String? connection;

  const Migration({this.connection});

  String get name => runtimeType.toString().snakeCase;

  void up(List<Schema> schemas);

  void down(List<Schema> schemas);
}

final class CreateSchema<T extends Entity<T>> extends Schema {
  CreateSchema._(super.name, super.func) : super._();

  @override
  String toScript(TableBlueprint table) {
    table = _bluePrintFunc!.call(table);
    return table.createScript(tableName);
  }
}

class _DropSchema extends Schema {
  _DropSchema(String name) : super._(name, null);

  @override
  String toScript(TableBlueprint table) => table.dropScript(tableName);
}

class _RenameSchema extends Schema {
  final String newName;

  _RenameSchema(String from, this.newName) : super._(from, null);

  @override
  String toScript(TableBlueprint table) => table.renameScript(tableName, newName);
}

enum ForeignKeyAction { cascade, restrict, setNull, setDefault, noAction }

class ForeignKey {
  final String table;
  final String column;

  final String foreignTable;
  final String foreignTableColumn;

  final bool nullable;

  final ForeignKeyAction? onUpdate;
  final ForeignKeyAction? onDelete;

  final String? constraint;

  const ForeignKey(
    this.table,
    this.column, {
    required this.foreignTable,
    required this.foreignTableColumn,
    this.nullable = false,
    this.onUpdate,
    this.onDelete,
    this.constraint,
  });

  ForeignKey actions({
    ForeignKeyAction? onUpdate,
    ForeignKeyAction? onDelete,
  }) =>
      ForeignKey(
        table,
        column,
        foreignTable: foreignTable,
        foreignTableColumn: foreignTableColumn,
        nullable: nullable,
        constraint: constraint,
        onUpdate: onUpdate ?? this.onUpdate,
        onDelete: onDelete ?? this.onDelete,
      );

  ForeignKey constrained({String? name}) => ForeignKey(
        table,
        column,
        foreignTable: foreignTable,
        foreignTableColumn: foreignTableColumn,
        nullable: nullable,
        onUpdate: onUpdate,
        onDelete: onDelete,
        constraint: name ?? 'fk_${table}_${column}_to_${foreignTable}_$foreignTableColumn',
      );
}
