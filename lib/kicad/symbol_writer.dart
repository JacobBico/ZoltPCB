import '../domain/models/models.dart';
import '../domain/symbols/symbols.dart';
import 'sexpr/sexpr.dart';
import 'sexpr/sexpr_writer.dart';

/// Serialises symbols back into KiCad's s-expression form.
///
/// Used for the `lib_symbols` block a schematic carries: KiCad reads symbol
/// geometry from that embedded copy, not from the user's installed
/// libraries, so an exported file has to bring its symbols with it or it
/// opens as a page of question marks.
abstract final class SymbolWriter {
  /// The standard 1.27 mm text size KiCad uses for fields.
  static const defaultTextSize = 1.27;

  /// Writes one symbol as it appears inside `lib_symbols`.
  ///
  /// Derived symbols are written out fully resolved rather than with an
  /// `extends` clause: the parent may not be used anywhere else in the
  /// design, and a dangling `extends` is a file KiCad cannot open.
  static SList libSymbol(SymbolDefinition symbol, {required String libId}) {
    final children = <SExpr>[
      S.list('pin_names', [
        S.of('offset', [symbol.pinNamesOffset]),
        if (symbol.pinNamesHidden) S.flag('hide', true),
      ]),
      if (symbol.pinNumbersHidden)
        S.list('pin_numbers', [S.flag('hide', true)]),
      if (symbol.isPower) S.of('power', const []),
      S.flag('exclude_from_sim', symbol.excludeFromSim),
      S.flag('in_bom', symbol.inBom),
      S.flag('on_board', symbol.onBoard),
      ..._properties(symbol),
      ..._unitDrawings(symbol),
      S.flag('embedded_fonts', false),
    ];

    return SList([SAtom('symbol'), S.text(libId), ...children]);
  }

  static List<SList> _properties(SymbolDefinition symbol) {
    // The four KiCad always expects, in its own order, then anything else
    // the symbol carried.
    const mandatory = ['Reference', 'Value', 'Footprint', 'Datasheet'];
    const hidden = {'Footprint', 'Datasheet', 'Description'};

    final entries = <MapEntry<String, String>>[
      for (final key in mandatory)
        MapEntry(key, symbol.properties[key] ?? _defaultFor(key, symbol)),
      for (final entry in symbol.properties.entries)
        if (!mandatory.contains(entry.key)) entry,
    ];

    return [
      for (final entry in entries)
        property(
          entry.key,
          entry.value,
          x: 0,
          y: 0,
          hide: hidden.contains(entry.key) || entry.key.startsWith('ki_'),
        ),
    ];
  }

  static String _defaultFor(String key, SymbolDefinition symbol) =>
      switch (key) {
        'Reference' => 'U',
        'Value' => symbol.name,
        _ => '',
      };

  static List<SList> _unitDrawings(SymbolDefinition symbol) {
    // Child symbols are named `<symbol>_<unit>_<bodyStyle>` with the plain
    // symbol name, never the library-qualified one.
    final plainName = symbol.name;
    return [
      for (final drawing in symbol.unitDrawings)
        SList([
          SAtom('symbol'),
          S.text('${plainName}_${drawing.unit}_${drawing.bodyStyle}'),
          ...drawing.graphics.map(graphic),
          ...drawing.pins.map(pin),
        ]),
    ];
  }

  static SList property(
    String key,
    String value, {
    required double x,
    required double y,
    double angle = 0,
    bool hide = false,
    double size = defaultTextSize,
  }) {
    return SList([
      SAtom('property'),
      S.text(key),
      S.text(value),
      S.of('at', [x, y, angle]),
      if (hide) S.flag('hide', true),
      S.flag('show_name', false),
      S.flag('do_not_autoplace', false),
      effects(size: size),
    ]);
  }

  static SList effects({
    double size = defaultTextSize,
    bool bold = false,
    bool italic = false,
    bool hide = false,
    String? justify,
  }) {
    return S.list('effects', [
      S.list('font', [
        S.of('size', [size, size]),
        if (bold) S.flag('bold', true),
        if (italic) S.flag('italic', true),
      ]),
      if (justify != null)
        SList([SAtom('justify'), ...justify.split(' ').map(SAtom.new)]),
      if (hide) S.flag('hide', true),
    ]);
  }

  static SList graphic(SymbolGraphic item) => switch (item) {
    SymbolPolyline(:final points) => S.list('polyline', [
      _points(points),
      _stroke(item.stroke),
      _fill(item.fill),
    ]),
    SymbolRectangle(:final start, :final end) => S.list('rectangle', [
      S.of('start', [start.x, start.y]),
      S.of('end', [end.x, end.y]),
      _stroke(item.stroke),
      _fill(item.fill),
    ]),
    SymbolCircle(:final center, :final radius) => S.list('circle', [
      S.of('center', [center.x, center.y]),
      S.of('radius', [radius]),
      _stroke(item.stroke),
      _fill(item.fill),
    ]),
    SymbolArc(:final start, :final mid, :final end) => S.list('arc', [
      S.of('start', [start.x, start.y]),
      S.of('mid', [mid.x, mid.y]),
      S.of('end', [end.x, end.y]),
      _stroke(item.stroke),
      _fill(item.fill),
    ]),
    SymbolBezier(:final points) => S.list('bezier', [
      _points(points),
      _stroke(item.stroke),
      _fill(item.fill),
    ]),
    SymbolText(:final text, :final at, :final angle) => SList([
      SAtom('text'),
      S.text(text),
      S.of('at', [at.x, at.y, angle]),
      effects(
        size: item.effects.sizeY,
        bold: item.effects.bold,
        italic: item.effects.italic,
      ),
    ]),
    SymbolTextBox(:final text, :final at, :final size, :final angle) => SList([
      SAtom('text_box'),
      S.text(text),
      S.of('at', [at.x, at.y, angle]),
      S.of('size', [size.x, size.y]),
      _stroke(item.stroke),
      _fill(item.fill),
      effects(size: item.effects.sizeY),
    ]),
  };

  static SList pin(SymbolPin item) {
    return SList([
      SAtom('pin'),
      SAtom(item.electricalType.token),
      SAtom(item.graphicStyle.token),
      S.of('at', [item.at.x, item.at.y, item.angle]),
      S.of('length', [item.length]),
      if (item.hidden) S.flag('hide', true),
      SList([SAtom('name'), S.text(item.name), effects()]),
      SList([SAtom('number'), S.text(item.number), effects()]),
      for (final alternate in item.alternates)
        SList([
          SAtom('alternate'),
          S.text(alternate.name),
          SAtom(alternate.electricalType.token),
          SAtom(alternate.graphicStyle.token),
        ]),
    ]);
  }

  static SList _points(List<SymbolPoint> points) => S.list('pts', [
    for (final point in points) S.of('xy', [point.x, point.y]),
  ]);

  static SList _stroke(StrokeStyle stroke) => S.list('stroke', [
    S.of('width', [stroke.width]),
    S.of('type', [SAtom(stroke.type.token)]),
  ]);

  static SList _fill(FillStyle fill) => S.list('fill', [
    S.of('type', [SAtom(fill.type.token)]),
  ]);

  /// Builds a symbol definition from a placed part's own pin snapshot.
  ///
  /// The fallback for a design whose library has been removed: the pins,
  /// their positions and their electrical types all live in the project, so
  /// the export stays electrically complete even though the body is gone.
  static SymbolDefinition fromPartSnapshot(PartWithDetails part) {
    final byUnit = <(int, int), List<SymbolPin>>{};
    for (final pin in part.pins) {
      final key = (pin.unit, pin.bodyStyle);
      (byUnit[key] ??= []).add(
        SymbolPin(
          number: pin.number,
          name: pin.name,
          electricalType: pin.electricalType,
          graphicStyle: pin.graphicStyle,
          at: SymbolPoint(pin.x, pin.y),
          angle: pin.angle.toDouble(),
          length: pin.length,
          hidden: pin.hidden,
        ),
      );
    }

    final keys = byUnit.keys.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );

    return SymbolDefinition(
      libraryNickname: part.part.libraryNickname,
      name: part.part.symbolName,
      properties: {
        'Reference': part.part.referencePrefix,
        'Value': part.part.value,
        'Footprint': part.part.footprint,
        'Datasheet': part.part.datasheet,
        if (part.part.description.isNotEmpty)
          'Description': part.part.description,
      },
      unitDrawings: [
        for (final key in keys)
          SymbolUnitDrawing(
            unit: key.$1,
            bodyStyle: key.$2,
            pins: byUnit[key]!,
          ),
      ],
      inBom: part.part.inBom,
      onBoard: part.part.onBoard,
    );
  }
}
