import 'package:app/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    // GeneratedHelper() was generated by drift, the verifier is an api
    // provided by drift_dev.
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema integrity is kept', () {
    const currentVersion = 3;

    // This loop tests all possible schema upgrades. It uses drift APIs to
    // ensure that the schema is in the expected format after an upgrade, but
    // simple tests like these can't ensure that your migration doesn't loose
    // data.
    for (var start = 1; start < currentVersion; start++) {
      group('from v$start', () {
        for (var target = start + 1; target <= currentVersion; target++) {
          test('to v$target', () async {
            // Use startAt() to obtain a database connection with all tables
            // from the old schema set up.
            final connection = await verifier.startAt(start);
            final db = AppDatabase.forTesting(connection);
            addTearDown(db.close);

            // Use this to run a migration and then validate that the database
            // has the expected schema.
            await verifier.migrateAndValidate(db, target);
          });
        }
      });
    }
  });

  // For specific schema upgrades, you can also write manual tests to ensure
  // that running the migration does not loose data.
  test('upgrading from v1 to v2 does not loose data', () async {
    // Use startAt(1) to obtain a usable database
    final connection = await verifier.schemaAt(1);
    connection.rawDatabase.execute(
      'INSERT INTO todo_entries (description) VALUES (?)',
      ['My manually added entry'],
    );

    final db = AppDatabase.forTesting(connection.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    // Make sure that the row is still there after migrating
    expect(
      db.todoEntries.select().get(),
      completion(
        [
          const TodoEntry(
            id: 1,
            description: 'My manually added entry',
          )
        ],
      ),
    );
  });

  test('upgrade from v1 to v2', () async {
    // Use startAt(1) to obtain a database connection with all tables
    // from the v1 schema.
    final connection = await verifier.startAt(1);
    final db = AppDatabase.forTesting(connection);

    // Use this to run a migration to v2 and then validate that the
    // database has the expected schema.
    await verifier.migrateAndValidate(db, 2);
  });

  // For more details on schema migration tests, see
  // https://drift.simonbinder.eu/docs/advanced-features/migrations/#verifying-migrations
}