import 'package:drift/drift.dart';

/// Web fallback for [createInMemoryQueryExecutor] in
/// `card_database_memory.dart`.
///
/// The card_box web build does not run any unit tests, and there is no
/// production code path that asks for an in-memory database on web, so
/// the safe behaviour on web is to throw loudly. The conditional
/// import in `card_database.dart` routes around this stub on native
/// platforms; on web it is the only one compiled, so any accidental
/// in-memory call is a hard failure rather than a silently broken
/// build.
QueryExecutor createInMemoryQueryExecutor() {
  throw UnsupportedError(
    'In-memory CardDatabase is not supported on web. '
    'This code path should only be hit from tests, which run on the '
    'Dart VM, not on the Flutter web target.',
  );
}
