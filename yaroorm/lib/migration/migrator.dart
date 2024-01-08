import 'package:collection/collection.dart';
import 'package:yaroorm/yaroorm.dart';

import 'cli.dart';
import 'utils.dart';

typedef _Rollback = ({MigrationData entry, MigrationTask? task});

class MigrationData extends Entity<int, MigrationData> {
  final String migration;
  final int batch;

  MigrationData(this.migration, this.batch);

  static MigrationData fromJson(Map<String, dynamic> json) => MigrationData(
        json['migration'] as String,
        json['batch'] as int,
      )..id = json['id'] as int?;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'migration': migration, 'batch': batch};

  @override
  bool get enableTimestamps => false;
}

class Migrator {
  /// config keys for migrations
  static const migrationsTableNameKeyInConfig = 'migrationsTableName';
  static const migrationsKeyInConfig = 'migrations';

  static String tableName = 'migrations';

  static Future<void> runMigrations(DatabaseDriver driver, Iterable<MigrationTask> migrations) async {
    await ensureMigrationsTableReady(driver);

    final lastBatchNumber = await getLastBatchNumber(driver, Migrator.tableName);
    final batchNos = lastBatchNumber + 1;

    print('------- Starting DB migration  📦 -------\n');

    for (final migration in migrations) {
      final fileName = migration.name;

      if (await hasAlreadyMigratedScript(fileName, driver)) {
        print('𐄂 skipped: $fileName     reason: already migrated');
        continue;
      }

      await driver.transaction((txnDriver) async {
        for (final schema in migration.schemas) {
          final sql = schema.toScript(driver.blueprint);
          await txnDriver.execute(sql);
        }

        await MigrationData(fileName, batchNos).withTableName(Migrator.tableName).withDriver(txnDriver).save();

        print('✔ done:   $fileName');
      });
    }

    print('\n------- Completed DB migration 🚀  ------\n');
  }

  static Future<void> resetMigrations(DatabaseDriver driver, Iterable<MigrationTask> allTasks) async {
    await ensureMigrationsTableReady(driver);

    final migrationsList =
        await Query.table<MigrationData>(Migrator.tableName).driver(driver).orderByDesc('batch').all();
    if (migrationsList.isEmpty) {
      print('𐄂 skipped: reason:     no migrations to reset');
      return;
    }

    print('------- Resetting migrations  📦 -------\n');

    final rollbacks = migrationsList.map((e) {
      final found = allTasks.firstWhereOrNull((m) => m.name == e.migration);
      return found == null ? null : (entry: e, task: found);
    }).whereNotNull();

    await _processRollbacks(driver, rollbacks);

    print('\n------- Reset migrations done 🚀 -------\n');
  }

  static Future<void> rollBackMigration(DatabaseDriver driver, Iterable<MigrationTask> allTasks) async {
    final migrationDbData =
        await Query.table<MigrationData>(Migrator.tableName).driver(driver).orderByDesc('batch').get();
    if (migrationDbData == null) {
      print('𐄂 skipped: reason:     no migration to rollback');
      return;
    }

    final rollbacks =
        allTasks.where((e) => e.name == migrationDbData.migration).map((e) => (entry: migrationDbData, task: e));

    print('------- Rolling back ${migrationDbData.migration}  📦 -------\n');

    await _processRollbacks(driver, rollbacks);

    print('\n------- Rollback done 🚀 -------\n');
  }

  static Future<void> _processRollbacks(DatabaseDriver driver, Iterable<_Rollback> rollbacks) async {
    for (final rollback in rollbacks) {
      await driver.transaction((transactor) async {
        final schemas = rollback.task?.schemas ?? [];
        if (schemas.isNotEmpty) {
          for (var e in schemas) {
            await transactor.execute(e.toScript(driver.blueprint));
          }
        }

        await rollback.entry.withTableName(Migrator.tableName).withDriver(transactor).delete();
      });

      print('✔ rolled back: ${rollback.entry.migration}');
    }
  }
}
