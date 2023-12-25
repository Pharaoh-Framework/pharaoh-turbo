import 'package:test/test.dart';
import 'package:yaroorm/src/database/driver/driver.dart';
import 'package:yaroorm/src/database/migration.dart';
import 'package:yaroorm/src/query/query.dart';

import '../fixtures/migrations.dart';
import '../fixtures/test_data.dart';

void runIntegrationTest(DatabaseDriver driver) {
  return group('Integration Test with ${driver.type.name} driver', () {
    test('driver should be connected', () => expect(driver.isOpen, isTrue));

    test('should have no tables', () async {
      final result = await Future.wait([
        driver.hasTable('users'),
        driver.hasTable('tasks'),
      ]);

      expect(result.every((e) => e), isFalse);
    });

    test('should execute migration', () async {
      final schemas = <Schema>[];
      AddUsersTable().up(schemas);

      final createTableScripts = schemas.map((schema) => schema.toScript(driver.blueprint));

      await driver.transaction((transactor) async {
        for (final script in createTableScripts) {
          await transactor.execute(script);
        }

        if (driver.type == DatabaseDriverType.sqlite) {
          await transactor.commit();
        }
      });

      final result = await Future.wait([
        driver.hasTable('users'),
        driver.hasTable('tasks'),
      ]);

      expect(result.every((e) => e), isTrue);
    });

    test('should insert single user', () async {
      final result = await Query.table<User>('users').driver(driver).insert<User>(usersTestData.first);
      expect(result, isA<User>().having((p0) => p0.id.value, 'has primary key', 1));

      final users = await Query.table<User>('users').driver(driver).all();
      expect(users.length, 1);
    });

    test('should insert many users', () async {
      await Query.table('users').driver(driver).insertMany(usersTestData.sublist(1));
      final users = await Query.table<User>('users').driver(driver).all();

      expect(users.length, usersTestData.length);
    });

    test('should update user', () async {
      var user = await Query.table<User>('users').driver(driver).get();
      expect(user, isNotNull);
      final userId = user?.id.value;
      expect(userId, 1);

      await Query.table('users')
          .driver(driver)
          .update(where: (where) => where.whereEqual('id', userId), values: {'firstname': 'Red Oil'}).exec();

      user = await Query.table<User>('users').driver(driver).get(userId);
      expect(user, isNotNull);

      user as User;
      expect(user.firstname, 'Red Oil');
      expect(user.id.value, 1);
    });

    test('should update many users', () async {
      final age50Users = Query.table<User>('users').driver(driver).whereEqual('age', 50);
      final usersWithAge50 = await age50Users.findMany();
      expect(usersWithAge50.length, 4);
      expect(usersWithAge50.every((e) => e.age == 50), isTrue);

      final updateQuery = Query.table<User>('users')
          .driver(driver)
          .update(where: (query) => query.whereEqual('age', 50), values: {'home_address': 'Keta Lagoon'});

      await updateQuery.exec();

      final updatedResult = await age50Users.findMany();
      expect(updatedResult.length, 4);
      expect(updatedResult.every((e) => e.age == 50), isTrue);
      expect(updatedResult.every((e) => e.homeAddress == 'Keta Lagoon'), isTrue);
    });

    test('should fetch only 23 users in Lagos Nigeria', () async {
      final age50Users = await Query.table<User>('users')
          .driver(driver)
          .whereIn('home_address', ['Lagos, Nigeria'])
          .orderByDesc('age')
          .take(23);

      expect(age50Users.length, 23);
      expect(age50Users.every((e) => e.homeAddress == 'Lagos, Nigeria'), isTrue);
    });

    test('should get all users between age 35 and 50', () async {
      final age50Users =
          await Query.table<User>('users').driver(driver).whereBetween('age', [35, 50]).orderByDesc('age').findMany();
      expect(age50Users.length, 19);
      expect(age50Users.first.age, 50);
      expect(age50Users.last.age, 35);
    });

    test('should get all users in somewhere in Nigeria', () async {
      final users = await Query.table<User>('users')
          .driver(driver)
          .whereLike('home_address', '%, Nigeria')
          .orderByAsc('home_address')
          .findMany();

      expect(users.length, 33);
      expect(users.first.homeAddress, 'Abuja, Nigeria');
      expect(users.last.homeAddress, 'Owerri, Nigeria');
    });

    test('should get all users where age is 30 or 52', () async {
      final users =
          await Query.table<User>('users').driver(driver).whereEqual('age', 30).orWhere('age', '=', 52).findMany();
      expect(users.every((e) => [30, 52].contains(e.age)), isTrue);
    });

    test('should delete user', () async {
      final query = Query.table<User>('users').driver(driver);

      final userOne = await query.get();
      expect(userOne, isNotNull);

      await query.delete((builder) => builder.where('id', '=', userOne!.id.value)).exec();

      final usersAfterDelete = await query.all();
      expect(usersAfterDelete.any((e) => e.id.value == userOne!.id.value), isFalse);
    });

    test('should delete many users', () async {
      final query = Query.table<User>('users').driver(driver).whereIn('home_address', ['Lagos, Nigeria']);

      final users = await query.findMany();
      expect(users, isNotEmpty);

      await query.delete();

      final usersAfterDelete = await query.findMany();
      expect(usersAfterDelete, isEmpty);
    });

    test('should drop tables', () async {
      final schemas = <Schema>[];
      AddUsersTable().down(schemas);

      final dropTableScripts = schemas.map((schema) => schema.toScript(driver.blueprint)).join('\n');

      await driver.execute(dropTableScripts);

      final hasUsersTable = await driver.hasTable('users');
      expect(hasUsersTable, isFalse);

      final hasTodosTable = await driver.hasTable('tasks');
      expect(hasTodosTable, isFalse);
    });

    test('should disconnect', () async {
      expect(driver.isOpen, isTrue);

      await driver.disconnect();

      expect(driver.isOpen, isFalse);
    });
  });
}
