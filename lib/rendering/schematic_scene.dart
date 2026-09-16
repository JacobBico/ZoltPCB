import 'dart:math' as math;
import 'dart:ui';

import '../domain/models/models.dart';
import '../domain/symbols/symbols.dart';
import 'renderable_pin.dart';
import 'schematic_geometry.dart';
import '../domain/geometry/net_routing.dart';
import '../domain/geometry/wire_router.dart';
import '../domain/geometry/drawn_wire_geometry.dart';

export '../domain/geometry/net_routing.dart' show RoutedWire;

/// One pin of one placed unit, resolved to a position on the sheet.
class PlacedPin {
  const PlacedPin({
    required this.pin,
    required this.partId,
    required this.reference,
    required this.unitId,
    required this.unitNumber,
    required this.sheetPosition,
    required this.sheetBodyEnd,
    this.netId,
    this.netName,
    this.netIsLabelled = false,
  });

  final RenderablePin pin;
  final String partId;
  final String reference;
  final String unitId;
  final int unitNumber;
  final Offset sheetPosition;

  /// Where the pin's stub meets the symbol body, in sheet space.
  ///
  /// Stored rather than derived from an angle so that routing can take the
  /// direction a wire should leave the pin straight from the geometry,
  /// without re-deriving rotation and mirroring conventions.
  final Offset sheetBodyEnd;

  final String? netId;
  final String? netName;

  /// True when the net carries a label the user chose, as opposed to an
  /// auto-generated name. Only labelled nets are worth drawing on the sheet.
  final bool netIsLabelled;

  String get id => pin.id;
  bool get isConnected => netId != null;

  /// `R1.2` — the way a pin is named in net lists and auto-generated names.
  String get label => '$reference.${pin.number}';

  /// This pin as the router sees it.
  RoutablePin get routable => RoutablePin.fromBodyEnd(
    id: pin.id,
    position: sheetPosition,
    bodyEnd: sheetBodyEnd,
  );

  /// Unit vector pointing away from the body — the direction a wire should
  /// leave this pin. Falls back to pointing right for a zero-length pin.
  Offset get exitDirection => routable.exitDirection;
}

/// One unit of one part, positioned and ready to draw.
class PlacedUnit {
  const PlacedUnit({
    required this.part,
    required this.unit,
    required this.placement,
    required this.pins,
    this.symbol,
  });

  final Part part;
  final PartUnit unit;
  final Placement placement;
  final List<PlacedPin> pins;

  /// The library definition, or null when the library is no longer
  /// installed. Pins still draw either way; only the body is missing.
  final SymbolDefinition? symbol;

  bool get hasSymbol => symbol != null;
}

/// A net's name, drawn once on the sheet rather than against every pin.
///
/// KiCad puts a label on the wire, not on the pins, and so does this. The
/// old drawing repeated the name at every endpoint of the net, which on a
/// filter — two parts, four pins, one net — printed "OUTPUT" four times in
/// the same square centimetre.
class NetLabel {
  const NetLabel({
    required this.netId,
    required this.text,
    required this.position,
    required this.pinned,
  });

  final String netId;
  final String text;

  /// Sheet millimetres. The user's own spot when [pinned], otherwise the
  /// corner of the net's wire.
  final Offset position;

  /// True when the position came from the user dragging the label.
  final bool pinned;
}

/// Everything the canvas needs for one frame, computed once.
///
/// Building this separately from painting keeps hit-testing and drawing
/// working from exactly the same geometry — a pin is tappable precisely
/// where it is drawn.
class SchematicScene {
  const SchematicScene({
    required this.paper,
    required this.units,
    required this.pins,
    required this.nets,
    required this.pinsByNet,
    this.wires = const [],
    this.labels = const [],
  });

  static SchematicScene build({
    required PaperSize paper,
    required List<PartWithDetails> parts,
    required List<NetWithEndpoints> nets,
    Map<String, List<double>> routeHints = const {},
    required Map<String, SymbolDefinition> symbols,
    List<SchematicWire> drawnWires = const [],
  }) {
    final netByPin = <String, NetWithEndpoints>{
      for (final net in nets)
        for (final endpoint in net.endpoints) endpoint.pin.id: net,
    };

    final units = <PlacedUnit>[];
    final allPins = <PlacedPin>[];

    for (final part in parts) {
      final symbol = symbols[part.part.libId];
      for (final unit in part.units) {
        if (!unit.placed) continue;
        final placement = Placement.ofUnit(unit);

        // Pins carrying unit 0 belong to every unit of the package, so they
        // are drawn on each one — which is how a shared supply pin appears
        // next to whichever gate the user is looking at.
        final unitPins = part.pins.where(
          (p) => p.unit == unit.unitNumber || p.unit == 0,
        );

        final placedPins = [
          for (final pin in unitPins)
            () {
              final renderable = RenderablePin.fromPart(pin);
              final net = netByPin[pin.id];
              return PlacedPin(
                pin: renderable,
                partId: part.part.id,
                reference: part.part.reference,
                unitId: unit.id,
                unitNumber: unit.unitNumber,
                sheetPosition: placement.apply(renderable.x, renderable.y),
                sheetBodyEnd: placement.apply(
                  renderable.bodyEnd.$1,
                  renderable.bodyEnd.$2,
                ),
                netId: net?.net.id,
                netName: net?.displayName,
                netIsLabelled: net?.net.isNamed ?? false,
              );
            }(),
        ];

        units.add(
          PlacedUnit(
            part: part.part,
            unit: unit,
            placement: placement,
            pins: placedPins,
            symbol: symbol,
          ),
        );
        allPins.addAll(placedPins);
      }
    }

    // A pin common to all units is drawn on every placed unit, so the same
    // pin can appear in `allPins` several times. Connectivity must count it
    // once: otherwise a shared supply pin draws a fan of duplicate wires and
    // reads as several connections when it is one.
    final byNet = <String, List<PlacedPin>>{};
    final seenPerNet = <String, Set<String>>{};
    for (final pin in allPins) {
      final netId = pin.netId;
      if (netId == null) continue;
      if (!(seenPerNet[netId] ??= <String>{}).add(pin.pin.id)) continue;
      (byNet[netId] ??= []).add(pin);
    }

    final obstacles = [for (final unit in units) _boundsOf(unit).deflate(0.2)];
    final drawnByNet = <String, List<SchematicWire>>{};
    for (final wire in drawnWires) {
      (drawnByNet[wire.netId] ??= []).add(wire);
    }
    final wires = <RoutedWire>[];
    for (final entry in byNet.entries) {
      wires.addAll(
        _routeNet(
          entry.key,
          entry.value,
          obstacles,
          routeHints,
          drawnByNet[entry.key] ?? const [],
        ),
      );
    }

    return SchematicScene(
      paper: paper,
      units: units,
      pins: allPins,
      nets: nets,
      pinsByNet: byNet,
      wires: wires,
      labels: _labelsFor(nets, byNet, wires),
    );
  }

  /// One label per named net, placed where it can be read.
  ///
  /// Power and ground are left out on purpose. Their symbol already says
  /// GND or +3V3 in letters an inch high; printing the net name beside it
  /// as well is the clutter the user asked to be rid of.
  static List<NetLabel> _labelsFor(
    List<NetWithEndpoints> nets,
    Map<String, List<PlacedPin>> pinsByNet,
    List<RoutedWire> wires,
  ) {
    final labels = <NetLabel>[];
    for (final net in nets) {
      final name = net.net.name;
      if (name == null || name.isEmpty) continue;

      final pins = pinsByNet[net.net.id] ?? const <PlacedPin>[];
      if (pins.isEmpty) continue;
      if (pins.any((pin) => isPowerReference(pin.reference))) continue;

      final stored = net.net.labelAt;
      labels.add(
        NetLabel(
          netId: net.net.id,
          text: name,
          position:
              stored ??
              _defaultLabelSpot([
                for (final wire in wires)
                  if (wire.netId == net.net.id) wire,
              ], pins),
          pinned: stored != null,
        ),
      );
    }
    return labels;
  }

  /// Where a label goes when the user has not placed it: on the corner of
  /// the net's wire, which is the one spot on a right-angled run that no
  /// other wire is about to pass through.
  static Offset _defaultLabelSpot(
    List<RoutedWire> netWires,
    List<PlacedPin> pins,
  ) {
    for (final wire in netWires) {
      // An interior vertex is a corner; the two endpoints are pins. The
      // middle one keeps the label off the parts at either end.
      if (wire.points.length > 2) {
        return wire.points[wire.points.length ~/ 2] + _labelLift;
      }
    }
    // A straight run has no corner; the middle of it reads just as well.
    for (final wire in netWires) {
      if (wire.points.length >= 2) {
        final a = wire.points.first;
        final b = wire.points.last;
        return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2) + _labelLift;
      }
    }
    return pins.first.sheetPosition + _labelLift;
  }

  /// How far above the wire a label floats by default, in millimetres —
  /// clear of the copper it names, close enough to belong to it.
  static const _labelLift = Offset(0, -2.2);

  /// KiCad marks power and ground symbols with a `#PWR` designator.
  static bool isPowerReference(String reference) =>
      reference.startsWith('#PWR') || reference.startsWith('#FLG');

  final PaperSize paper;
  final List<PlacedUnit> units;
  final List<PlacedPin> pins;
  final List<NetWithEndpoints> nets;
  final Map<String, List<PlacedPin>> pinsByNet;

  /// Every net's connections, routed as orthogonal paths ready to draw and
  /// to hit-test. Computed here rather than in the painter so that a wire is
  /// touchable exactly where it is drawn.
  final List<RoutedWire> wires;

  /// Each named net's label, one apiece, ready to draw and to drag.
  final List<NetLabel> labels;

  /// The same scene with one label somewhere else, for showing a drag in
  /// progress before it is written down.
  SchematicScene withLabelMoved(String netId, Offset at) => SchematicScene(
    paper: paper,
    units: units,
    pins: pins,
    nets: nets,
    pinsByNet: pinsByNet,
    wires: wires,
    labels: [
      for (final label in labels)
        if (label.netId == netId)
          NetLabel(
            netId: label.netId,
            text: label.text,
            position: at,
            pinned: true,
          )
        else
          label,
    ],
  );

  /// The label whose text box contains [sheetPoint], if any.
  ///
  /// [halfWidthMm] and [halfHeightMm] describe the drawn box at the current
  /// zoom, so the target is exactly the text the user can see.
  NetLabel? labelNear(
    Offset sheetPoint, {
    required double halfHeightMm,
    required double Function(NetLabel label) halfWidthMm,
  }) {
    for (final label in labels.reversed) {
      final box = Rect.fromCenter(
        center: label.position,
        width: halfWidthMm(label) * 2,
        height: halfHeightMm * 2,
      );
      if (box.contains(sheetPoint)) return label;
    }
    return null;
  }

  Rect get pageRect => Rect.fromLTWH(0, 0, paper.widthMm, paper.heightMm);

  bool get isEmpty => units.isEmpty;

  /// Pins within [toleranceMm] of [sheetPoint], nearest first.
  ///
  /// Nearest-within-tolerance rather than exact hit: pins are 0.4 mm dots
  /// and fingers are not precise, so the target has to be far larger than
  /// the mark. That makes ambiguity unavoidable on a dense part, which is
  /// why the whole ranked list is returned — the caller can ask rather than
  /// guess when two pins are equally plausible.
  ///
  /// A pin shared by several units appears once, at its nearest instance.
  List<PlacedPin> pinsNear(Offset sheetPoint, double toleranceMm) {
    final candidates = <({PlacedPin pin, double distance})>[];
    final seen = <String>{};

    for (final pin in pins) {
      if (pin.pin.hidden) continue;
      final distance = (pin.sheetPosition - sheetPoint).distance;
      if (distance > toleranceMm) continue;
      candidates.add((pin: pin, distance: distance));
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));

    return [
      for (final candidate in candidates)
        if (seen.add(candidate.pin.pin.id)) candidate.pin,
    ];
  }

  /// The single pin nearest [sheetPoint], or null if none is close enough.
  PlacedPin? pinNear(Offset sheetPoint, double toleranceMm) =>
      pinsNear(sheetPoint, toleranceMm).firstOrNull;

  /// Decides what a tap at [sheetPoint] means.
  ///
  /// [toleranceMm] is how far a tap may land from a pin and still count.
  /// [ambiguityMarginMm] is how much closer the nearest pin must be than
  /// the next before the tap is taken at face value; within that margin the
  /// tap is reported as ambiguous so the caller can ask rather than guess.
  /// Guessing here is what silently mis-wires a schematic.
  PinTapResult resolveTap(
    Offset sheetPoint, {
    required double toleranceMm,
    required double ambiguityMarginMm,
  }) {
    final candidates = pinsNear(sheetPoint, toleranceMm);
    if (candidates.isEmpty) return const PinTapMissed();
    if (candidates.length == 1) return PinTapHit(candidates.first);

    final first = (candidates[0].sheetPosition - sheetPoint).distance;
    final second = (candidates[1].sheetPosition - sheetPoint).distance;
    if ((second - first) >= ambiguityMarginMm) {
      return PinTapHit(candidates.first);
    }
    return PinTapAmbiguous(candidates);
  }

  /// The wire nearest [sheetPoint], within [toleranceMm].
  RoutedWire? wireNear(Offset sheetPoint, double toleranceMm) {
    RoutedWire? best;
    var bestDistance = double.infinity;
    for (final wire in wires) {
      final distance = wire.distanceTo(sheetPoint);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = wire;
      }
    }
    return bestDistance <= toleranceMm ? best : null;
  }

  /// The run to move when the user takes hold of a wire near [sheetPoint].
  ///
  /// The wire is found first, then the best run within it. Matching runs
  /// directly would mean only the short middle of a wire responded: the
  /// long stretches either end have to stay attached to their pins, so they
  /// are not movable themselves — but they are most of what there is to
  /// touch. Grabbing anywhere on a wire and pushing the nearest corner is
  /// what makes the whole thing feel like one object.
  WireHandleHit? wireHandleNear(Offset sheetPoint, double toleranceMm) {
    RoutedWire? nearestWire;
    var nearestDistance = double.infinity;
    for (final wire in wires) {
      if (wire.handles.isEmpty) continue;
      final distance = wire.distanceTo(sheetPoint);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestWire = wire;
      }
    }
    if (nearestWire == null || nearestDistance > toleranceMm) return null;

    WireHandle? best;
    var bestDistance = double.infinity;
    for (final handle in nearestWire.handles) {
      final distance = handle.distanceTo(sheetPoint);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = handle;
      }
    }
    if (best == null) return null;
    return WireHandleHit(wire: nearestWire, handle: best);
  }

  /// Chooses which pins to join and routes each connection.
  ///
  /// Routed once per net and then reused until something that net's route
  /// depends on changes: its pins, its drawn wires, its hints, or a part
  /// standing near it. Dragging one part used to re-route every wire on the
  /// sheet each frame; now it re-routes the few that touch it.
  static List<RoutedWire> _routeNet(
    String netId,
    List<PlacedPin> pins,
    List<Rect> obstacles,
    Map<String, List<double>> routeHints,
    List<SchematicWire> drawn,
  ) {
    final routable = [for (final pin in pins) pin.routable];

    var reach = Rect.fromPoints(
      routable.first.position,
      routable.first.position,
    );
    for (final pin in routable) {
      reach = reach.expandToInclude(
        Rect.fromLTWH(pin.position.dx, pin.position.dy, 0, 0),
      );
    }
    for (final wire in drawn) {
      for (final p in wire.points) {
        reach = reach.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
      }
    }
    // Routes detour round parts, but never by more than a few grid squares.
    reach = reach.inflate(12.7);
    final nearby = [
      for (final o in obstacles)
        if (o.overlaps(reach)) o,
    ];

    final signature = StringBuffer();
    for (final pin in routable) {
      signature
        ..write(pin.id)
        ..write(pin.position.dx.toStringAsFixed(3))
        ..write(',')
        ..write(pin.position.dy.toStringAsFixed(3))
        ..write(pin.exitDirection.dx.toStringAsFixed(2))
        ..write(pin.exitDirection.dy.toStringAsFixed(2))
        ..write(';');
    }
    for (final o in nearby) {
      signature.write(
        'o${o.left.toStringAsFixed(3)},${o.top.toStringAsFixed(3)},${o.right.toStringAsFixed(3)},${o.bottom.toStringAsFixed(3)}',
      );
    }
    for (final wire in drawn) {
      signature.write('w${wire.id}${SchematicWire.encode(wire.points)}');
    }
    for (final a in routable) {
      for (final b in routable) {
        final hint = routeHints[NetRouting.routeKey(a.id, b.id)];
        if (hint != null && a.id.compareTo(b.id) < 0) signature.write('h$hint');
      }
    }
    final key = signature.toString();

    final cached = _routeCache[netId];
    if (cached != null && cached.$1 == key) return cached.$2;

    final routed = NetRouting.routeNetWithDrawn(
      netId,
      routable,
      drawn: drawn,
      obstacles: nearby,
      hints: routeHints,
    );
    if (_routeCache.length > 4000) _routeCache.clear();
    _routeCache[netId] = (key, routed);
    return routed;
  }

  static final _routeCache = <String, (String, List<RoutedWire>)>{};

  /// The wire and run of it nearest [sheetPoint], any wire at all.
  WireRunHit? wireRunNear(Offset sheetPoint, double toleranceMm) {
    WireRunHit? best;
    var bestDistance = double.infinity;
    for (final wire in wires) {
      final (run, distance) = DrawnWireGeometry.nearestRun(
        wire.points,
        sheetPoint,
      );
      if (run >= 0 && distance < bestDistance) {
        bestDistance = distance;
        best = WireRunHit(wire: wire, run: run);
      }
    }
    return bestDistance <= toleranceMm ? best : null;
  }

  /// The same scene with one wire drawn along [points], for a slide being
  /// dragged.
  SchematicScene withWirePoints(String key, List<Offset> points) =>
      SchematicScene(
        paper: paper,
        units: units,
        pins: pins,
        nets: nets,
        pinsByNet: pinsByNet,
        wires: [
          for (final wire in wires)
            if (wire.key == key)
              RoutedWire(
                netId: wire.netId,
                pinAId: wire.pinAId,
                pinBId: wire.pinBId,
                points: points,
                drawnId: wire.drawnId,
              )
            else
              wire,
        ],
        labels: labels,
      );

  /// The unit whose body contains [sheetPoint], for dragging.
  PlacedUnit? unitAt(Offset sheetPoint, {double paddingMm = 1.27}) {
    // Reverse order so the unit drawn last — visually on top — wins.
    for (final unit in units.reversed) {
      if (boundsOf(unit).inflate(paddingMm).contains(sheetPoint)) return unit;
    }
    return null;
  }

  /// How far [sheetPoint] is from a unit's drawn body, or 0 inside it.
  ///
  /// Measured against the body alone, not [boundsOf], which stretches out to
  /// the tip of every pin. That difference decides whether a tap belongs to
  /// a symbol or to a wire beside it: wires are routed to clear the body,
  /// and they land squarely inside the pin-inclusive box.
  double distanceToBody(PlacedUnit unit, Offset sheetPoint) {
    final body = bodyBoundsOf(unit);
    final dx = math.max(
      math.max(body.left - sheetPoint.dx, 0.0),
      sheetPoint.dx - body.right,
    );
    final dy = math.max(
      math.max(body.top - sheetPoint.dy, 0.0),
      sheetPoint.dy - body.bottom,
    );
    return math.sqrt(dx * dx + dy * dy);
  }

  /// The unit's drawn body, without the pins that stick out of it.
  ///
  /// Falls back to the full extent for a unit whose library is missing:
  /// with no graphics there is no body to speak of, and the pins are all
  /// there is to aim at.
  Rect bodyBoundsOf(PlacedUnit unit) {
    final symbol = unit.symbol;
    if (symbol == null) return boundsOf(unit);

    final local = symbolBounds(
      symbol,
      unit.unit.unitNumber,
      bodyStyle: unit.unit.bodyStyle,
      includePins: false,
    );
    if (local == Rect.zero) return boundsOf(unit);

    var rect = Rect.fromPoints(
      unit.placement.apply(local.left, local.top),
      unit.placement.apply(local.right, local.top),
    );
    for (final corner in [
      unit.placement.apply(local.right, local.bottom),
      unit.placement.apply(local.left, local.bottom),
    ]) {
      rect = rect.expandToInclude(Rect.fromLTWH(corner.dx, corner.dy, 0, 0));
    }
    return rect;
  }

  /// The unit's extent on the sheet.
  Rect boundsOf(PlacedUnit unit) => _boundsOf(unit);

  static Rect _boundsOf(PlacedUnit unit) => unitBoundsOnSheet(
    symbol: unit.symbol,
    unitNumber: unit.unit.unitNumber,
    bodyStyle: unit.unit.bodyStyle,
    placement: unit.placement,
    sheetPoints: [
      for (final pin in unit.pins) ...[
        pin.sheetPosition,
        unit.placement.apply(pin.pin.bodyEnd.$1, pin.pin.bodyEnd.$2),
      ],
    ],
    minimumExtentMm: minimumExtentMm,
  );

  /// Smallest box a unit is given on the sheet, in millimetres — two grid
  /// squares, which is a comfortable finger target at normal zoom.
  static const minimumExtentMm = 2.54;

  /// The extent of everything placed, used to frame the view.
  Rect get contentBounds {
    if (units.isEmpty) return pageRect;
    var rect = boundsOf(units.first);
    for (final unit in units.skip(1)) {
      rect = rect.expandToInclude(boundsOf(unit));
    }
    return rect.inflate(6.35);
  }
}

/// What a tap on the canvas resolved to.
sealed class PinTapResult {
  const PinTapResult();
}

/// The tap landed away from every pin.
class PinTapMissed extends PinTapResult {
  const PinTapMissed();
}

/// The tap clearly picked one pin.
class PinTapHit extends PinTapResult {
  const PinTapHit(this.pin);

  final PlacedPin pin;
}

/// Two or more pins are equally plausible, nearest first.
class PinTapAmbiguous extends PinTapResult {
  const PinTapAmbiguous(this.candidates);

  final List<PlacedPin> candidates;
}

/// A specific movable run of a specific wire.
class WireHandleHit {
  const WireHandleHit({required this.wire, required this.handle});

  final RoutedWire wire;
  final WireHandle handle;
}

/// A run of a wire the user has hold of.
class WireRunHit {
  const WireRunHit({required this.wire, required this.run});

  final RoutedWire wire;

  /// Index of the run: between corners run and run + 1.
  final int run;
}
