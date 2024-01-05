import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:meta/meta_meta.dart';
import 'package:yaroorm/yaroorm.dart';

import '../primitives/where.dart';

const entity = ReflectableEntity();

const String entityCreatedAtColumnName = 'createdAt';
const String entityUpdatedAtColumnName = 'updatedAt';

const String entityFromJsonStaticFuncName = 'fromJson';

@entity
abstract class Entity<PkType, Model> {
  Entity() {
    assert(runtimeType == Model, 'Type Mismatch on Entity<$PkType, $Model>. $runtimeType expected');
    if (PkType == dynamic) {
      throw Exception('Entity Primary Key Data Type is required. Use either `extends Entity<int>` or `Entity<String>`');
    }
  }

  PkType? id;

  DateTime? createdAt;

  DateTime? updatedAt;

  Query<Model> get _query {
    final connName = connection;
    final query = DB.query<Model>(tableName);
    return connName == null ? query : query.driver(DB.driver(connName));
  }

  WhereClause<Model> _whereId(Query<Model> _) => _.whereEqual(primaryKey, id);

  @nonVirtual
  Future<void> delete() => _query.delete(_whereId).exec();

  @nonVirtual
  Future<Model> save() async => await _query.insert(this);

  @nonVirtual
  Future<Model?> update(Map<String, dynamic> values) async {
    await _query.update(where: _whereId, values: values).exec();
    return _query.get();
  }

  bool get enableTimestamps => false;

  String? _tableName;
  String get tableName {
    if (_tableName != null) return _tableName!;
    return _tableName = getTableName(runtimeType);
  }

  /// override this this set the connection for this model
  @JsonKey(includeToJson: false, includeFromJson: false)
  String? connection;

  String get primaryKey => 'id';

  String get createdAtColumn => entityCreatedAtColumnName;

  String get updatedAtColumn => entityUpdatedAtColumnName;

  bool get allowInsertIdAsNull => false;

  Map<String, dynamic> toJson();

  @nonVirtual
  // ignore: non_constant_identifier_names
  Map<String, dynamic> get to_db_data {
    final mapData = toJson();
    if (mapData[primaryKey] == null && !allowInsertIdAsNull) mapData.remove(primaryKey);
    if (!enableTimestamps) {
      mapData
        ..remove(createdAtColumn)
        ..remove(updatedAtColumn);
    }
    return mapData;
  }
}

@Target({TargetKind.classType})
class EntityMeta {
  final String table;
  const EntityMeta({required this.table});
}
