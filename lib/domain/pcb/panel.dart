import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'board_outline.dart';
import 'board_scene.dart';
import 'drc.dart' show copperItems;
import 'fab_presets.dart';

/// How the copies of a board are held in the panel until they are broken
/// out.
enum PanelJoin {
  /// Tabs across a milled gap, perforated by a row of small holes.
  mouseBites('Mouse bites'),

  /// Boards butted edge to edge, with a V-groove cut into both faces along
  /// every line between them. Straight lines only, so rectangles only.
  vScore('V-score');

  const PanelJoin(this.label);

  final String label;
}

/// The strips of scrap board round the copies, which an assembly line
/// grips by and which carry the fiducials and tooling holes.
enum PanelRails {
  none('None'),
  topBottom('Top & bottom'),
  frame('Frame');

  const PanelRails(this.label);

  final String label;
}

/// What the user chose for the panel. Stored per project as JSON.
class PanelSettings {
  const PanelSettings({
    this.rows = 2,
    this.columns = 2,
    this.spacing = 2.0,
    this.join = PanelJoin.mouseBites,
    this.rails = PanelRails.topBottom,
    this.railWidth = 5.0,
    this.tabWidth = 5.0,
    this.tabsPerEdge = 0,
    this.fiducials = true,
    this.toolingHoles = true,
    this.toolingDiameter = 2.0,
  });

  static const settingsKey = 'panel';

  /// The perforation: 0.5 mm holes 0.8 mm apart, set a quarter of a
  /// millimetre into the board so the break leaves no nub standing proud.
  static const biteDiameter = 0.5;
  static const bitePitch = 0.8;
  static const biteOffset = 0.25;

  /// A fiducial: bare copper, with a clear ring of no mask round it.
  static const fiducialCopper = 1.0;
  static const fiducialMask = 2.0;

  /// The narrowest gap a router bit mills.
  static const minSpacing = 1.0;

  final int rows;
  final int columns;

  /// The milled gap between copies, and between the copies and the rails,
  /// for mouse bites. V-score has none.
  final double spacing;
  final PanelJoin join;
  final PanelRails rails;
  final double railWidth;
  final double tabWidth;

  /// Tabs along each joined edge; 0 picks by the edge's length.
  final int tabsPerEdge;
  final bool fiducials;
  final bool toolingHoles;
  final double toolingDiameter;

  PanelSettings copyWith({
    int? rows,
    int? columns,
    double? spacing,
    PanelJoin? join,
    PanelRails? rails,
    double? railWidth,
    double? tabWidth,
    int? tabsPerEdge,
    bool? fiducials,
    bool? toolingHoles,
    double? toolingDiameter,
  }) => PanelSettings(
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    spacing: spacing ?? this.spacing,
    join: join ?? this.join,
    rails: rails ?? this.rails,
    railWidth: railWidth ?? this.railWidth,
    tabWidth: tabWidth ?? this.tabWidth,
    tabsPerEdge: tabsPerEdge ?? this.tabsPerEdge,
    fiducials: fiducials ?? this.fiducials,
    toolingHoles: toolingHoles ?? this.toolingHoles,
    toolingDiameter: toolingDiameter ?? this.toolingDiameter,
  );

  String encode() => jsonEncode({
    'rows': rows,
    'columns': columns,
    'spacing': spacing,
    'join': join.name,
    'rails': rails.name,
    'railWidth': railWidth,
    'tabWidth': tabWidth,
    'tabsPerEdge': tabsPerEdge,
    'fiducials': fiducials,
    'toolingHoles': toolingHoles,
    'toolingDiameter': toolingDiameter,
  });

  /// Read back from [encode]; anything missing or unreadable falls back to
  /// the default, so an old or damaged setting never stops the panel.
  factory PanelSettings.decode(String? json) {
    const fallback = PanelSettings();
    if (json == null) return fallback;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      T? read<T>(String key) => map[key] is T ? map[key] as T : null;
      double? number(String key) => (map[key] as num?)?.toDouble();
      return PanelSettings(
        rows: (read<int>('rows') ?? fallback.rows).clamp(1, 20),
        columns: (read<int>('columns') ?? fallback.columns).clamp(1, 20),
        spacing: number('spacing') ?? fallback.spacing,
        join:
            PanelJoin.values.where((j) => j.name == map['join']).firstOrNull ??
            fallback.join,
        rails:
            PanelRails.values
                .where((r) => r.name == map['rails'])
                .firstOrNull ??
            fallback.rails,
        railWidth: number('railWidth') ?? fallback.railWidth,
        tabWidth: number('tabWidth') ?? fallback.tabWidth,
        tabsPerEdge: read<int>('tabsPerEdge') ?? fallback.tabsPerEdge,
        fiducials: read<bool>('fiducials') ?? fallback.fiducials,
        toolingHoles: read<bool>('toolingHoles') ?? fallback.toolingHoles,
        toolingDiameter: number('toolingDiameter') ?? fallback.toolingDiameter,
      );
    } on Object {
      return fallback;
    }
  }
}

/// The panel worked out: where every copy goes, and everything added
/// round them. Coordinates are the panel's own, millimetres, y down, with
/// its top-left corner at the origin.
class PanelLayout {
  const PanelLayout({
    required this.settings,
    required this.join,
    required this.panel,
    required this.copies,
    required this.boardBounds,
    required this.rails,
    required this.tabs,
    required this.biteHoles,
    required this.fiducials,
    required this.toolingHoles,
    required this.toolingDiameter,
    required this.vScores,
    required this.edgeCuts,
    required this.labelAt,
    required this.labelHeight,
    required this.labelRoom,
    required this.warnings,
  });

  final PanelSettings settings;

  /// The join actually used: V-score falls back to mouse bites for a board
  /// that is not a rectangle.
  final PanelJoin join;
  final Rect panel;

  /// Added to a board coordinate to place it in each copy.
  final List<Offset> copies;

  /// Each copy's bounding box, in the panel.
  final List<Rect> boardBounds;
  final List<Rect> rails;
  final List<Rect> tabs;
  final List<Offset> biteHoles;
  final List<Offset> fiducials;
  final List<Offset> toolingHoles;
  final double toolingDiameter;
  final List<(Offset, Offset)> vScores;

  /// The milled edge, as open runs: every copy's outline where no tab
  /// holds it, the tabs' sides, and the rails.
  final List<List<Offset>> edgeCuts;

  /// Where the panel's name goes on the top rail, if there is room.
  final Offset? labelAt;
  final double labelHeight;

  /// How long the name may run there without reaching a fiducial.
  final double labelRoom;
  final List<String> warnings;

  static PanelLayout of(
    BoardScene scene,
    PanelSettings settings, {
    FabPreset? fab,
  }) {
    final warnings = <String>[];
    final outline = scene.outline;
    final bounds = outline.bounds;
    final w = bounds.width;
    final h = bounds.height;
    final rows = settings.rows.clamp(1, 20);
    final columns = settings.columns.clamp(1, 20);

    if (!outline.isDrawn) {
      warnings.add(
        'The board has no outline yet, so each copy is its working area. '
        'Draw the outline with the Edge cut tool first',
      );
    }

    var join = settings.join;
    if (join == PanelJoin.vScore &&
        outline.isDrawn &&
        outline.kind != BoardOutlineKind.rectangle) {
      warnings.add(
        'V-score cuts only straight lines through the whole panel, so a '
        '${outline.kind.label.toLowerCase()} board is joined by mouse bites',
      );
      join = PanelJoin.mouseBites;
    }
    final bites = join == PanelJoin.mouseBites;
    final gap = bites
        ? math.max(settings.spacing, PanelSettings.minSpacing)
        : 0.0;
    final topBottom = settings.rails != PanelRails.none;
    final sides = settings.rails == PanelRails.frame;
    final rail = settings.railWidth.clamp(2.0, 30.0);

    final x0 = sides ? rail + gap : 0.0;
    final y0 = topBottom ? rail + gap : 0.0;
    final boardsWidth = columns * w + (columns - 1) * gap;
    final boardsHeight = rows * h + (rows - 1) * gap;
    final panel = Rect.fromLTWH(
      0,
      0,
      boardsWidth + (sides ? 2 * (rail + gap) : 0),
      boardsHeight + (topBottom ? 2 * (rail + gap) : 0),
    );

    Rect boxAt(int r, int c) =>
        Rect.fromLTWH(x0 + c * (w + gap), y0 + r * (h + gap), w, h);
    final copies = <Offset>[];
    final boxes = <Rect>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final box = boxAt(r, c);
        boxes.add(box);
        copies.add(box.topLeft - bounds.topLeft);
      }
    }

    final rails = <Rect>[
      if (topBottom) ...[
        Rect.fromLTWH(0, 0, panel.width, rail),
        Rect.fromLTWH(0, panel.height - rail, panel.width, rail),
      ],
      if (sides) ...[
        Rect.fromLTWH(0, rail, rail, panel.height - 2 * rail),
        Rect.fromLTWH(panel.width - rail, rail, rail, panel.height - 2 * rail),
      ],
    ];

    // --- joins ---------------------------------------------------------
    final tabs = <Rect>[];
    final biteHoles = <Offset>[];
    final vScores = <(Offset, Offset)>[];
    final edgeCuts = <List<Offset>>[];
    final polygon = outlinePolygon(outline);

    if (bites) {
      final shapes = [
        for (final copy in copies) [for (final p in polygon) p + copy],
      ];
      var unreached = false;

      // One edge of one copy joined across the gap to whatever is on the
      // other side: another copy (its own index) or a rail (null).
      void hold(int a, Offset direction, int? b) {
        final box = boxes[a];
        final alongX = direction.dy != 0;
        final length = alongX ? box.width : box.height;
        final count = settings.tabsPerEdge > 0
            ? settings.tabsPerEdge
            : math.max(1, (length / 40).round());
        final width = math.min(settings.tabWidth, length / count * 0.8);
        final faceA = _face(box, direction);
        final faceB = faceA + gap;
        for (var k = 0; k < count; k++) {
          final centre =
              (alongX ? box.left : box.top) + length * (k + 0.5) / count;
          final depthA = _depth(shapes[a], box, direction, centre, width);
          final depthB = b == null
              ? 0.0
              : _depth(shapes[b], boxes[b], -direction, centre, width);
          if (depthA == null || depthB == null) {
            unreached = true;
            continue;
          }
          // Along the join, from just inside one side to just inside the
          // other, so the tab overlaps both.
          final from = faceA - depthA - 0.05;
          final to = faceB + depthB + 0.05;
          tabs.add(_tab(direction, from, to, centre, width));
          biteHoles.addAll(_bites(shapes[a], box, direction, centre, width));
          if (b != null) {
            biteHoles.addAll(
              _bites(shapes[b], boxes[b], -direction, centre, width),
            );
          }
        }
      }

      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < columns; c++) {
          final i = r * columns + c;
          if (c < columns - 1) hold(i, const Offset(1, 0), i + 1);
          if (r < rows - 1) hold(i, const Offset(0, 1), i + columns);
          if (topBottom && r == 0) hold(i, const Offset(0, -1), null);
          if (topBottom && r == rows - 1) hold(i, const Offset(0, 1), null);
          if (sides && c == 0) hold(i, const Offset(-1, 0), null);
          if (sides && c == columns - 1) hold(i, const Offset(1, 0), null);
        }
      }
      if (unreached) {
        warnings.add(
          'Some tabs were left out: the board\'s edge does not reach far '
          'enough across them. Fewer or narrower tabs may fit',
        );
      }
      if (rows * columns > 1 || topBottom) {
        if (tabs.isEmpty) {
          warnings.add('Nothing holds the copies together: add tabs');
        }
      }

      // What stays after milling, piece by piece. The milled edge is the
      // edge of each piece wherever it is not inside another.
      final pieces = <_Piece>[
        for (final shape in shapes) _Piece.polygon(shape),
        for (final tab in tabs) _Piece.rect(tab),
        if (sides)
          _Piece.frame(panel, panel.deflate(rail))
        else
          for (final r in rails) _Piece.rect(r),
      ];
      edgeCuts.addAll(_boundary(pieces));

      // Copper the perforation would drill through.
      final items = copperItems(scene);
      final hit = <String>{};
      for (final hole in biteHoles) {
        final copy = copies[_nearestBox(boxes, hole)];
        final at = hole - copy;
        for (final item in items) {
          final reach = item.width / 2 + PanelSettings.biteDiameter / 2 + 0.2;
          if (distanceToSegment(at, item.a, item.b) < reach) {
            hit.add(item.what);
          }
        }
      }
      if (hit.isNotEmpty) {
        final names = hit.take(4).join(', ');
        warnings.add(
          'Mouse bites come within 0.2 mm of $names'
          '${hit.length > 4 ? ' and ${hit.length - 4} more' : ''}: move '
          'the copper back from the edge or the tabs along it',
        );
      }
    } else {
      // V-score: the whole panel is one sheet, grooved edge to edge along
      // every line where two pieces meet.
      edgeCuts.add([
        panel.topLeft,
        panel.topRight,
        panel.bottomRight,
        panel.bottomLeft,
        panel.topLeft,
      ]);
      final ys = <double>{
        for (var r = 0; r <= rows; r++) y0 + r * h,
      }.where((y) => y > 1e-6 && y < panel.height - 1e-6);
      final xs = <double>{
        for (var c = 0; c <= columns; c++) x0 + c * w,
      }.where((x) => x > 1e-6 && x < panel.width - 1e-6);
      vScores
        ..addAll([for (final y in ys) (Offset(0, y), Offset(panel.width, y))])
        ..addAll([for (final x in xs) (Offset(x, 0), Offset(x, panel.height))]);
    }

    // --- rails: fiducials, tooling holes, name ------------------------
    final fiducials = <Offset>[];
    final toolingHoles = <Offset>[];
    Offset? labelAt;
    var labelRoom = 0.0;
    final tooling = settings.toolingDiameter.clamp(0.5, rail - 1.0);
    final labelHeight = math.min(1.5, rail * 0.4);
    if (topBottom) {
      final top = rail / 2;
      final bottom = panel.height - rail / 2;
      final holeInset = math.max(5.0, tooling);
      final fiducialInset = holeInset + 5;
      if (settings.toolingHoles) {
        toolingHoles.addAll([
          Offset(holeInset, top),
          Offset(panel.width - holeInset, top),
          Offset(holeInset, bottom),
          Offset(panel.width - holeInset, bottom),
        ]);
      }
      if (settings.fiducials) {
        if (panel.width < fiducialInset * 2 + 5) {
          warnings.add('The panel is too narrow for fiducials on its rails');
        } else {
          // Three, not four, and not symmetric: a machine can tell which
          // way round the panel is.
          fiducials.addAll([
            Offset(fiducialInset, top),
            Offset(panel.width - fiducialInset, top),
            Offset(fiducialInset, bottom),
          ]);
        }
      }
      labelRoom = panel.width - 2 * (fiducialInset + 3);
      if (rail >= 3 && labelRoom > 5) labelAt = Offset(panel.width / 2, top);
    } else if (settings.fiducials || settings.toolingHoles) {
      warnings.add(
        'Fiducials and tooling holes go on the rails, and this panel has '
        'none',
      );
    }

    if (fab != null) {
      final max = fab.maxSize;
      final fits =
          (panel.width <= max.width && panel.height <= max.height) ||
          (panel.width <= max.height && panel.height <= max.width);
      if (!fits) {
        warnings.add(
          'At ${panel.width.toStringAsFixed(1)} × '
          '${panel.height.toStringAsFixed(1)} mm the panel is larger than '
          '${fab.name} makes (${max.width.toStringAsFixed(0)} × '
          '${max.height.toStringAsFixed(0)} mm)',
        );
      }
    }

    return PanelLayout(
      settings: settings,
      join: join,
      panel: panel,
      copies: copies,
      boardBounds: boxes,
      rails: rails,
      tabs: tabs,
      biteHoles: biteHoles,
      fiducials: fiducials,
      toolingHoles: toolingHoles,
      toolingDiameter: tooling,
      vScores: vScores,
      edgeCuts: edgeCuts,
      labelAt: labelAt,
      labelHeight: labelHeight,
      labelRoom: labelRoom,
      warnings: warnings,
    );
  }

  /// The board outline as a closed run of points; a circle finely enough
  /// that no flat is worth milling differently. A board with no outline
  /// yet is its working area.
  static List<Offset> outlinePolygon(BoardOutline outline) => !outline.isDrawn
      ? BoardOutline.rectangle(outline.rect).path
      : outline.kind == BoardOutlineKind.circle
      ? [
          for (var i = 0; i < 256; i++)
            outline.center +
                Offset(
                  outline.radius * math.cos(i * math.pi * 2 / 256),
                  outline.radius * math.sin(i * math.pi * 2 / 256),
                ),
        ]
      : outline.path;

  // --- tabs --------------------------------------------------------------

  /// The coordinate of [box]'s side facing [direction], along it.
  static double _face(Rect box, Offset direction) => switch (direction) {
    Offset(dx: > 0) => box.right,
    Offset(dx: < 0) => -box.left,
    Offset(dy: > 0) => box.bottom,
    _ => -box.top,
  };

  /// A point at [along] (in [direction]'s own sense) and [across].
  static Offset _point(Offset direction, double along, double across) =>
      switch (direction) {
        Offset(dx: > 0) => Offset(along, across),
        Offset(dx: < 0) => Offset(-along, across),
        Offset(dy: > 0) => Offset(across, along),
        _ => Offset(across, -along),
      };

  static Rect _tab(
    Offset direction,
    double from,
    double to,
    double centre,
    double width,
  ) => Rect.fromPoints(
    _point(direction, from, centre - width / 2),
    _point(direction, to, centre + width / 2),
  );

  /// How far in from the box's face the outline lies, at its deepest,
  /// across a tab [width] wide at [centre]. Null if somewhere across it the
  /// board does not reach at all.
  static double? _depth(
    List<Offset> shape,
    Rect box,
    Offset direction,
    double centre,
    double width,
  ) {
    var deepest = 0.0;
    const samples = 9;
    for (var i = 0; i < samples; i++) {
      final across = centre - width / 2 + width * i / (samples - 1);
      final depth = _reach(shape, box, direction, across);
      if (depth == null) return null;
      deepest = math.max(deepest, depth);
    }
    return deepest;
  }

  /// From [box]'s face, back into the board against [direction] at
  /// [across]: the distance to the outline, or null if it is never met.
  static double? _reach(
    List<Offset> shape,
    Rect box,
    Offset direction,
    double across,
  ) {
    final face = _face(box, direction);
    final start = _point(direction, face, across);
    final span = direction.dx != 0 ? box.width : box.height;
    final end = start - direction * span;
    double? best;
    for (var i = 0; i < shape.length; i++) {
      final t = _cross(start, end, shape[i], shape[(i + 1) % shape.length]);
      if (t != null && (best == null || t < best)) best = t;
    }
    return best == null ? null : best * span;
  }

  /// The row of holes across a tab where it meets a board, each set in by
  /// [PanelSettings.biteOffset] from where the outline actually is.
  static List<Offset> _bites(
    List<Offset> shape,
    Rect box,
    Offset direction,
    double centre,
    double width,
  ) {
    final face = _face(box, direction);
    const d = PanelSettings.biteDiameter;
    const pitch = PanelSettings.bitePitch;
    final count = math.max(1, ((width - d) / pitch).floor() + 1);
    final span = (count - 1) * pitch;
    return [
      for (var i = 0; i < count; i++)
        if (_reach(shape, box, direction, centre - span / 2 + i * pitch)
            case final depth?)
          _point(
            direction,
            face - depth - PanelSettings.biteOffset,
            centre - span / 2 + i * pitch,
          ),
    ];
  }

  static int _nearestBox(List<Rect> boxes, Offset point) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < boxes.length; i++) {
      final distance = (boxes[i].center - point).distance;
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  // --- the milled edge ---------------------------------------------------

  /// Every piece's edge, cut wherever it runs inside another piece, as
  /// open runs joined end to end where they meet.
  static List<List<Offset>> _boundary(List<_Piece> pieces) {
    final runs = <List<Offset>>[];
    for (var p = 0; p < pieces.length; p++) {
      final piece = pieces[p];
      final others = [
        for (var q = 0; q < pieces.length; q++)
          if (q != p && pieces[q].box.overlaps(piece.box.inflate(0.01)))
            pieces[q],
      ];
      for (final loop in piece.loops) {
        final kept = <List<Offset>>[];
        for (var i = 0; i < loop.length; i++) {
          final a = loop[i];
          final b = loop[(i + 1) % loop.length];
          final segment = Rect.fromPoints(a, b).inflate(0.01);
          final cuts = <double>[0, 1];
          for (final other in others) {
            if (!other.box.overlaps(segment)) continue;
            for (final edge in other.loops) {
              for (var j = 0; j < edge.length; j++) {
                final t = _cross(a, b, edge[j], edge[(j + 1) % edge.length]);
                if (t != null) cuts.add(t);
              }
            }
          }
          cuts.sort();
          for (var k = 0; k + 1 < cuts.length; k++) {
            if (cuts[k + 1] - cuts[k] < 1e-9) continue;
            final from = Offset.lerp(a, b, cuts[k])!;
            final to = Offset.lerp(a, b, cuts[k + 1])!;
            final mid = (from + to) / 2;
            if (others.any((o) => o.contains(mid))) continue;
            if (kept.isNotEmpty && (kept.last.last - from).distance < 1e-6) {
              kept.last.add(to);
            } else {
              kept.add([from, to]);
            }
          }
        }
        // The loop's last run and first run meet where it started.
        if (kept.length > 1 &&
            (kept.last.last - kept.first.first).distance < 1e-6) {
          kept.first.insertAll(0, kept.removeLast()..removeLast());
        }
        runs.addAll(kept);
      }
    }
    return runs;
  }

  /// Where segment a–b crosses c–d, as a fraction along a–b, or null.
  static double? _cross(Offset a, Offset b, Offset c, Offset d) {
    final r = b - a;
    final s = d - c;
    final denominator = r.dx * s.dy - r.dy * s.dx;
    if (denominator.abs() < 1e-12) return null;
    final q = c - a;
    final t = (q.dx * s.dy - q.dy * s.dx) / denominator;
    final u = (q.dx * r.dy - q.dy * r.dx) / denominator;
    if (t < -1e-9 || t > 1 + 1e-9 || u < -1e-9 || u > 1 + 1e-9) return null;
    return t.clamp(0.0, 1.0);
  }
}

/// One piece of what stays after milling: a copy, a tab, or a rail.
class _Piece {
  _Piece(this.loops, this.box, this.contains);

  factory _Piece.polygon(List<Offset> points) {
    var box = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      box = box.expandToInclude(Rect.fromPoints(p, p));
    }
    return _Piece([points], box, (point) => _inPolygon(points, point));
  }

  factory _Piece.rect(Rect rect) => _Piece(
    [_corners(rect)],
    rect,
    (p) =>
        p.dx > rect.left + 1e-9 &&
        p.dx < rect.right - 1e-9 &&
        p.dy > rect.top + 1e-9 &&
        p.dy < rect.bottom - 1e-9,
  );

  /// A rectangle with a rectangular hole: rails all round.
  factory _Piece.frame(Rect outer, Rect inner) => _Piece(
    [_corners(outer), _corners(inner)],
    outer,
    (p) =>
        _Piece.rect(outer).contains(p) &&
        !(p.dx >= inner.left - 1e-9 &&
            p.dx <= inner.right + 1e-9 &&
            p.dy >= inner.top - 1e-9 &&
            p.dy <= inner.bottom + 1e-9),
  );

  final List<List<Offset>> loops;
  final Rect box;
  final bool Function(Offset) contains;

  static List<Offset> _corners(Rect r) => [
    r.topLeft,
    r.topRight,
    r.bottomRight,
    r.bottomLeft,
  ];

  static bool _inPolygon(List<Offset> polygon, Offset point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}
