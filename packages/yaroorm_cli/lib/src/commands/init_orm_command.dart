import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:mason_logger/mason_logger.dart';

import '../builder/utils.dart';
import '../misc/utils.dart';

import 'package:path/path.dart' as path;

import '../yaroorm_cli_base.dart';

Directory get databaseDir {
  final dir = Directory(path.join(Directory.current.path, 'database'));
  if (!dir.existsSync()) dir.createSync();
  return dir;
}

Directory get migrationsDir {
  final dir = Directory(path.join(databaseDir.path, 'migrations'));
  if (!dir.existsSync()) dir.createSync();
  return dir;
}

final databaseInitFile = File('${path.join(databaseDir.path, 'database')}.dart');

final yaroormDirectory = path.join(Directory.current.path, '.dart_tool', 'yaroorm');
final kernelFile = File(path.join(yaroormDirectory, 'migrator.dill'));
final migratorCheckSumFile = File(path.join(yaroormDirectory, '.migrator_checksum'));

final migratorFile = path.join(yaroormDirectory, 'migrator.dart');

class InitializeOrmCommand extends Command<int> {
  static const String commandName = 'init';

  @override
  String get description => 'Initialize ORM in project';

  @override
  String get name => commandName;

  @override
  FutureOr<int>? run() async {
    final workingDir = Directory.current;
    final progress = logger.progress('Initializing Yaroorm 📦');

    try {
      final result = OrmCLIRunner.resolvedProjectCache;
      if (result.migrations.isEmpty) {
        progress.fail('Yaroorm 📦 not initialized. No migrations found.');
        return ExitCode.software.code;
      }

      await initOrmInProject(workingDir, result.migrations, result.entities, result.dbConfig);

      progress.complete('Yaroorm 📦 initialized 🚀');

      return ExitCode.success.code;
    } on YaroormCliException catch (e) {
      progress.fail('🗙 ORM initialize step failed');
      logger.err(e.toString());
      exit(ExitCode.software.code);
    }
  }
}

Future<void> initOrmInProject(
  Directory workingDir,
  List<Item> migrations,
  List<Item> entities,
  TopLevelVariableElement dbConfig,
) async {
  final entityNames = entities.map((e) => e.elements.map((e) => e.name)).fold(<String>{}, (preV, e) => preV..addAll(e));
  final databaseFile = File(path.join(databaseDir.path, 'database.dart'));

  final fsPath = path.relative(dbConfig.library.identifier.replaceFirst('file://', '').trim());
  final configPath = fsPath.startsWith('package:') ? fsPath : path.relative(fsPath, from: databaseDir.path);

  final migrationFileNameDateMap = migrations
      .map((e) => path.basename(e.path))
      .fold(<String, DateTime>{}, (preV, filename) => preV..[filename] = parseMigrationFileDate(filename));

  final sortedMigrationsList = (migrations
        ..sort((a, b) => migrationFileNameDateMap[path.basename(a.path)]!.compareTo(
              migrationFileNameDateMap[path.basename(b.path)]!,
            )))
      .mapIndexed((index, element) => (index: index, element: element));

  final addMigrationsToDbCode = '''
/// Configure Migrations Order
DB.migrations.addAll([
  ${sortedMigrationsList.map((mig) => mig.element.elements.map((classElement) => '_m${mig.index}.${classElement.name}()').join(', ')).join(', ')},
]);
''';

  final library = Library((p0) => p0
    ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND')
    ..directives.addAll([
      Directive.import('package:yaroorm/yaroorm.dart'),
      ...entities.map((e) => e.path).toSet().map((e) => Directive.import(e)),
      Directive.import(configPath, as: 'config'),
      ...sortedMigrationsList
          .map((e) => Directive.import('migrations/${path.basename(e.element.path)}', as: '_m${e.index}'))
    ])
    ..body.add(Method.returnsVoid((m) => m
      ..name = 'initializeORM'
      ..body = Code('''
/// Add Type Definitions to Query Runner
${entityNames.map((name) => 'Query.addTypeDef<$name>(${getTypeDefName(name)});').join('\n')}

${sortedMigrationsList.isNotEmpty ? addMigrationsToDbCode : ''}

DB.init(config.${dbConfig.name});
'''))));

  final emitter = DartEmitter.scoped(orderDirectives: true, useNullSafetySyntax: true);

  final code = DartFormatter().format([library.accept(emitter)].join('\n\n'));

  await databaseFile.writeAsString(code);
}
