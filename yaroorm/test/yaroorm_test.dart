import 'package:test/test.dart';
import 'package:yaroorm/src/database/driver/driver.dart';
import 'package:yaroorm/src/database/driver/mysql_driver.dart';
import 'package:yaroorm/src/database/driver/sqlite_driver.dart';
import 'package:yaroorm/src/query/query.dart';

import 'fixtures/connections.dart';

void main() {
  group('DatabaseDriver.init', () {
    group('when sqlite connection', () {
      test('should return SQLite Driver', () {
        final driver = DatabaseDriver.init(sqliteConnection);
        expect(driver, isA<SqliteDriver>());

        expect(driver.type, DatabaseDriverType.sqlite);
      });

      test('should have table blueprint', () {
        final driver = DatabaseDriver.init(sqliteConnection);
        expect(driver, isA<SqliteDriver>());

        expect(driver.blueprint, isA<SqliteTableBlueprint>());
      });

      test('should have primitive serializer', () {
        final driver = DatabaseDriver.init(sqliteConnection);
        expect(driver, isA<SqliteDriver>());

        expect(driver.serializer, isA<SqliteSerializer>());
      });
    });

    group('when mysql connection', () {
      test('should return MySql Driver', () {
        final driver = DatabaseDriver.init(mysqlConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.type, DatabaseDriverType.mysql);
      });

      test('should have table blueprint', () {
        final driver = DatabaseDriver.init(mysqlConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.blueprint, isA<MySqlDriverTableBlueprint>());
      });

      test('should have primitive serializer', () {
        final driver = DatabaseDriver.init(mysqlConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.serializer, isA<MySqlPrimitiveSerializer>());
      });
    });

    group('when mariadb connection', () {
      test('should return MySql Driver', () {
        final driver = DatabaseDriver.init(mariadbConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.type, DatabaseDriverType.mariadb);
      });

      test('should have table blueprint', () {
        final driver = DatabaseDriver.init(mariadbConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.blueprint, isA<MySqlDriverTableBlueprint>());
      });

      test('should have primitive serializer', () {
        final driver = DatabaseDriver.init(mariadbConnection);
        expect(driver, isA<MySqlDriver>());

        expect(driver.serializer, isA<MySqlPrimitiveSerializer>());
      });
    });
  });

  test('should err when Query without driver', () async {
    late Object error;
    try {
      await Query.table('users').all();
    } catch (e) {
      error = e;
    }

    expect(
      error,
      isA<StateError>()
          .having((p0) => p0.message, '', 'Driver not set for query. Make sure you supply a driver using .driver()'),
    );
  });
}
