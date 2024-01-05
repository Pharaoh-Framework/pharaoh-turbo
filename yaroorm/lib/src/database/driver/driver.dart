import '../../primitives/serializer.dart';
import '../../query/query.dart';
import '../../../migration.dart';
import 'mysql_driver.dart';
import 'sqlite_driver.dart';

enum DatabaseDriverType { sqlite, pgsql, mysql, mariadb }

String wrapString(String value) => "'$value'";

class DatabaseConnection {
  final String name;
  final String? url;
  final String? host;
  final int? port;
  final String? username;
  final String? password;
  final String database;
  final String? charset, collation;
  final bool dbForeignKeys;
  final DatabaseDriverType driver;
  final bool? secure;

  const DatabaseConnection(
    this.name,
    this.database,
    this.driver, {
    this.charset,
    this.collation,
    this.host,
    this.password,
    this.port,
    this.url,
    this.username,
    this.dbForeignKeys = true,
    this.secure,
  });

  factory DatabaseConnection.from(String name, Map<String, dynamic> connInfo) {
    return DatabaseConnection(
      name,
      connInfo['database'],
      _getDriverType(connInfo),
      host: connInfo['host'],
      port: connInfo['port'],
      charset: connInfo['charset'],
      collation: connInfo['collation'],
      password: connInfo['password'],
      username: connInfo['username'],
      url: connInfo['url'],
      secure: connInfo['secure'],
      dbForeignKeys: connInfo['foreign_key_constraints'] ?? true,
    );
  }
}

DatabaseDriverType _getDriverType(Map<String, dynamic> connInfo) {
  final value = connInfo['driver'];
  return switch (value) {
    'sqlite' => DatabaseDriverType.sqlite,
    'pgsql' => DatabaseDriverType.pgsql,
    'mysql' => DatabaseDriverType.mysql,
    'mariadb' => DatabaseDriverType.mariadb,
    null => throw ArgumentError.notNull('Database Driver'),
    _ => throw ArgumentError.value(value, null, 'Invalid Database Driver provided in configuration')
  };
}

mixin DriverAble {
  /// Perform query on the database
  Future<List<Map<String, dynamic>>> query(Query query);

  /// Perform raw query on the database.
  Future<List<Map<String, dynamic>>> rawQuery(String script);

  /// Execute scripts on the database.
  ///
  /// Execution varies across drivers
  Future<dynamic> execute(String script);

  /// Perform update on the database
  Future<void> update(UpdateQuery query);

  /// Perform delete on the database
  Future<void> delete(DeleteQuery query);

  /// Perform insert on the database
  Future<int> insert(InsertQuery query);

  /// Perform insert on the database
  Future<dynamic> insertMany(InsertManyQuery query);

  PrimitiveSerializer get serializer;
}

abstract class DriverTransactor with DriverAble {}

abstract interface class DatabaseDriver with DriverAble {
  factory DatabaseDriver.init(DatabaseConnection dbConn) {
    final driver = dbConn.driver;
    switch (driver) {
      case DatabaseDriverType.sqlite:
        return SqliteDriver(dbConn);
      case DatabaseDriverType.mariadb:
      case DatabaseDriverType.mysql:
        return MySqlDriver(dbConn, driver);
      default:
        throw ArgumentError.value(driver, null, 'Driver not yet supported');
    }
  }

  /// Check if the database is open for operation
  bool get isOpen;

  /// Schema name used to perform all write queries.
  DatabaseDriverType get type;

  /// Performs connection to the database.
  ///
  /// Depend on driver type it may create a connection pool.
  Future<DatabaseDriver> connect({int? maxConnections, bool? singleConnection});

  /// Performs connection to the database.
  ///
  /// Depend on driver type it may create a connection pool.
  Future<void> disconnect();

  /// check if the table exists in the database
  Future<bool> hasTable(String tableName);

  TableBlueprint get blueprint;

  Future<void> transaction(void Function(DriverTransactor transactor) transaction);
}
