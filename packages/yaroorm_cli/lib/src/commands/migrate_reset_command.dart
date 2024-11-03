import 'dart:async';

import 'package:collection/collection.dart';
import 'package:yaroorm/yaroorm.dart';
import '../misc/utils.dart';

import '../misc/migration.dart';
import 'command.dart';
import 'migrate_rollback_command.dart';

class MigrationResetCommand extends OrmCommand {
  static const String commandName = 'migrate:reset';

  @override
  String get description => 'reset database migrations';

  @override
  String get name => commandName;

  @override
  Future<void> execute(DatabaseDriver driver, {bool writeLogs = true}) async {
    await ensureMigrationsTableReady(driver);

    final migrationsList = await MigrationEntityQuery.driver(driver).findMany(
      orderBy: [OrderMigrationEntityBy.batch(order: OrderDirection.desc)],
    );
    if (migrationsList.isEmpty) {
      print('𐄂 skipped: reason:     no migrations to reset');
      return;
    }

    final rollbacks = migrationDefinitions.reversed.map((e) {
      final entry = migrationsList.firstWhereOrNull((entry) => e.name == entry.migration);
      return entry == null ? null : (entry: entry, schemas: e.down);
    }).nonNulls;

    await processRollbacks(driver, rollbacks, table: migrationLogTable);

    if (writeLogs) {
      logger.write(migrationLogTable.toString());
    }
  }
}
