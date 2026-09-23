/// Which sheet of each project is being drawn on.
///
/// Parts, wires and notes are created from a dozen places — adding from the
/// library, pasting, a starter circuit, a power symbol, every wire tool —
/// and each has to land on the sheet the user is looking at. Rather than
/// thread a sheet through all of them, the schematic says which sheet is
/// open here, and the repositories put anything new on it. Anything that
/// knows its sheet — an undo step, say — passes it instead.
///
/// Kept per database and per project, so an import, another project or
/// another test's database never inherits it.
abstract final class ActiveSheet {
  static final _byDatabase = Expando<Map<String, String>>();

  /// The sheet open in [projectId], or null for the top sheet.
  static String? of(Object database, String projectId) =>
      _byDatabase[database]?[projectId];

  static void set(Object database, String projectId, String? sheetId) {
    final open = _byDatabase[database] ??= {};
    if (sheetId == null) {
      open.remove(projectId);
    } else {
      open[projectId] = sheetId;
    }
  }
}
