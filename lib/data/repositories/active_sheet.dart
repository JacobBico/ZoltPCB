/// Which sheet of each project is being drawn on.
///
/// Parts, wires and notes are created from a dozen places — adding from the
/// library, pasting, a starter circuit, a power symbol, every wire tool —
/// and each has to land on the sheet the user is looking at. Rather than
/// thread a sheet through all of them, the schematic says which sheet is
/// open here, and the repositories put anything new on it.
///
/// Kept per project, so an import or another project never inherits it.
abstract final class ActiveSheet {
  static final _byProject = <String, String>{};

  /// The sheet open in [projectId], or null for the top sheet.
  static String? of(String projectId) => _byProject[projectId];

  static void set(String projectId, String? sheetId) {
    if (sheetId == null) {
      _byProject.remove(projectId);
    } else {
      _byProject[projectId] = sheetId;
    }
  }
}
