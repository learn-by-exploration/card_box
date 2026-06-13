import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Returns a [QueryExecutor] backed by an in-memory SQLite database.
///
/// This lives in its own file so the `package:drift/native.dart` import
/// (which transitively pulls in `dart:ffi`) stays out of the web build
/// graph. The web entry point in `card_database_memory_stub.dart` makes
/// the same surface available without touching `dart:ffi`, which is
/// unavailable on the dart2js / dart2wasm targets.
QueryExecutor createInMemoryQueryExecutor() {
  return NativeDatabase.memory();
}
