import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

import 'tables.dart';
// Manually generated by `drift_dev schema steps` - this file makes writing
// migrations easier. See this for details:
// https://drift.simonbinder.eu/docs/advanced-features/migrations/#step-by-step
import 'schema_versions.dart';

// Generated by drift_dev when running `build_runner build`
part 'database.g.dart';

@DriftDatabase(tables: [TodoEntries, Categories], include: {'sql.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'todo-app',
            web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
                onResult: (result) {
                  if (result.missingFeatures.isNotEmpty) {
                    debugPrint(
                        'Using ${result.chosenImplementation} due to unsupported '
                        'browser features: ${result.missingFeatures}');
                  }
                }),
          ),
        );

  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 3;

  Future<List<TodoEntryWithCategory>> search(String query) {
    return _search(query).map((row) {
      return TodoEntryWithCategory(entry: row.todos, category: row.cat);
    }).get();
  }

  Stream<List<CategoryWithCount>> categoriesWithCount() {
    // the _categoriesWithCount method has been generated automatically based
    // on the query declared in the @DriftDatabase annotation
    return _categoriesWithCount().map((row) {
      final hasId = row.id != null;
      final category = hasId
          ? Category(id: row.id!, name: row.name!, color: row.color!)
          : null;

      return CategoryWithCount(category, row.amount);
    }).watch();
  }

  /// Returns an auto-updating stream of all todo entries in a given category
  /// id.
  Stream<List<TodoEntryWithCategory>> entriesInCategory(int? categoryId) {
    final query = select(todoEntries).join([
      leftOuterJoin(categories, categories.id.equalsExp(todoEntries.category))
    ]);

    if (categoryId != null) {
      query.where(categories.id.equals(categoryId));
    } else {
      query.where(categories.id.isNull());
    }

    return query.map((row) {
      return TodoEntryWithCategory(
        entry: row.readTable(todoEntries),
        category: row.readTableOrNull(categories),
      );
    }).watch();
  }

  Future<void> deleteCategory(Category category) {
    return transaction(() async {
      // First, move todo entries that might remain into the default category
      await (todoEntries.update()
            ..where((todo) => todo.category.equals(category.id)))
          .write(const TodoEntriesCompanion(category: Value(null)));

      // Then, delete the category
      await categories.deleteOne(category);
    });
  }

  static final StateProvider<AppDatabase> provider = StateProvider((ref) {
    final database = AppDatabase();
    ref.onDispose(database.close);

    return database;
  });
}

class TodoEntryWithCategory {
  final TodoEntry entry;
  final Category? category;

  TodoEntryWithCategory({required this.entry, this.category});
}

class CategoryWithCount {
  // can be null, in which case we count how many entries don't have a category
  final Category? category;
  final int count; // amount of entries in this category

  CategoryWithCount(this.category, this.count);
}