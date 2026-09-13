/// KiCad's footprint filters: which footprints suit a symbol.
///
/// A symbol states them as space-separated globs — a resistor says `R_*`, a
/// diode `D_* *_Diode_* TO-???*`. They are the difference between offering
/// every two-pad footprint on the phone for a resistor (diodes, fuses, LEDs,
/// crystals) and offering resistors.
class FootprintFilter {
  FootprintFilter(String filters)
    : patterns = [
        for (final glob in filters.split(RegExp(r'\s+')))
          if (glob.trim().isNotEmpty) glob.trim(),
      ],
      _expressions = [
        for (final glob in filters.split(RegExp(r'\s+')))
          if (glob.trim().isNotEmpty) _compile(glob.trim()),
      ];

  /// The globs as the symbol wrote them.
  final List<String> patterns;
  final List<RegExp> _expressions;

  bool get isEmpty => patterns.isEmpty;

  /// Whether a footprint suits the symbol.
  ///
  /// Matched against the footprint's own name, and also against the name
  /// after its library prefix: KiCad's filters are written either way round
  /// depending on who made the symbol.
  bool matches(String footprintName) {
    if (_expressions.isEmpty) return true;
    final bare = footprintName.contains(':')
        ? footprintName.split(':').last
        : footprintName;
    return _expressions.any(
      (expression) =>
          expression.hasMatch(bare) || expression.hasMatch(footprintName),
    );
  }

  /// A glob as a whole-string pattern. Everything but `*` and `?` is taken
  /// literally — footprint names are full of `.` and `_`, and treating
  /// either as special would match things it should not.
  static RegExp _compile(String glob) {
    final buffer = StringBuffer('^');
    for (final char in glob.split('')) {
      switch (char) {
        case '*':
          buffer.write('.*');
        case '?':
          buffer.write('.');
        default:
          buffer.write(RegExp.escape(char));
      }
    }
    buffer.write(r'$');
    // KiCad matches case-insensitively; so does anyone typing "r_0805".
    return RegExp(buffer.toString(), caseSensitive: false);
  }
}
