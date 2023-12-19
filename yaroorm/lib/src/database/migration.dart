import 'package:meta/meta.dart';
import 'package:recase/recase.dart';

import 'entity.dart';

abstract interface class TableBlueprint {
  void id();

  void string(String name, {bool nullable = false, String? defaultValue});

  void integer(String name, {bool nullable = false, int? defaultValue});

  void double(String name, {bool nullable = false, num? defaultValue});

  void float(String name, {bool nullable = false, num? defaultValue});

  void boolean(String name, {bool nullable = false, bool? defaultValue});

  void timestamp(String name, {bool nullable = false, DateTime? defaultValue});

  void datetime(String name, {bool nullable = false, DateTime? defaultValue});

  void blob(String name, {bool nullable = false, String? defaultValue});

  void timestamps({
    String createdAt = entityCreatedAtColumnName,
    String updatedAt = entityUpdatedAtColumnName,
  });

  @protected
  String createScript(String tableName);

  @protected
  String dropScript(String tableName);

  @protected
  String renameScript(String fromName, String toName);
}

typedef TableBluePrintFunc = TableBlueprint Function(TableBlueprint $table);

class Schema {
  late final String scriptName;
  final String tableName;
  final TableBluePrintFunc? _bluePrintFunc;

  Schema._(this.tableName, this._bluePrintFunc);

  String toScript(TableBlueprint $table) => _bluePrintFunc!.call($table).createScript(tableName);

  static Schema create(String name, TableBluePrintFunc func) => Schema._(name, func);

  static Schema dropIfExists(String name) => _DropSchema(name);

  static Schema rename(String from, String to) => _RenameSchema(from, to);
}

class _DropSchema extends Schema {
  _DropSchema(String name) : super._(name, null);

  @override
  String toScript(TableBlueprint $table) => $table.dropScript(tableName);
}

class _RenameSchema extends Schema {
  final String newName;

  _RenameSchema(String from, this.newName) : super._(from, null);

  @override
  String toScript(TableBlueprint $table) => $table.renameScript(tableName, newName);
}

abstract class Migration {
  const Migration();

  String get name => runtimeType.toString().snakeCase;

  String get connection => 'default';

  void up(List<Schema> $actions);

  void down(List<Schema> $actions);
}
