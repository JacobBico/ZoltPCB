import 'package:drift/drift.dart';

import 'database.dart';

extension AggregateWatchers on AppDatabase {
  /// A stream that emits once on listen and again whenever any row in
  /// [tables] changes, re-running [load] each time.
  ///
  /// Aggregates like "a part with its units and pins" span several tables,
  /// which no single drift query stream covers. Driving them off a trivial
  /// query registered against those tables reuses drift's own change
  /// tracking — which correctly defers notifications until a transaction has
  /// committed. Reloading through [tableUpdates] instead can deadlock: the
  /// reload issues a read while the writing transaction still holds the
  /// executor.
  ///
  /// Designs on a phone are small, so a full reload per change is cheaper
  /// than keeping several joined streams in sync.
  Stream<T> watchAggregate<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) {
    // The watched table names go into the query as a bound variable, and
    // that is load-bearing rather than decorative. Drift caches query
    // streams by SQL plus variables and ignores `readsFrom`, so two
    // aggregates both triggering off a bare `SELECT 1` would share one
    // cached stream — and the second would silently inherit the first's
    // set of tables, updating only when those changed.
    final watched = (tables.map((t) => t.entityName).toList()..sort()).join(
      ',',
    );
    return customSelect(
      'SELECT ? AS watched_tables',
      variables: [Variable<String>(watched)],
      readsFrom: tables,
    ).watch().asyncMap((_) => load());
  }
}
