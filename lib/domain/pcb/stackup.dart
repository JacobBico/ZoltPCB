import 'dart:convert';

import 'board_layer.dart';

/// What a copper layer is for.
///
/// A plane is a return path as much as a layer: impedance is measured to
/// the nearest one, and a signal layer between two of them is stripline.
enum LayerRole {
  signal('Signal', 'signal'),
  plane('Plane', 'power'),
  mixed('Mixed', 'mixed');

  const LayerRole(this.label, this.kicadType);

  final String label;

  /// The word a `.kicad_pcb` layer table uses.
  final String kicadType;

  static LayerRole byName(String? name) =>
      values.where((r) => r.name == name).firstOrNull ?? signal;
}

/// Copper foil by weight, the way a board house quotes it.
///
/// Ounces per square foot is a strange unit for a thickness, but it is the
/// one on every order form, so it is the one offered.
enum CopperWeight {
  half('½ oz', 0.0175),
  one('1 oz', 0.035),
  two('2 oz', 0.070),
  three('3 oz', 0.105);

  const CopperWeight(this.label, this.thickness);

  final String label;

  /// Foil thickness, in millimetres.
  final double thickness;

  /// The weight whose foil is closest to [thickness].
  static CopperWeight nearest(double thickness) {
    var best = one;
    for (final weight in values) {
      if ((weight.thickness - thickness).abs() <
          (best.thickness - thickness).abs()) {
        best = weight;
      }
    }
    return best;
  }
}

/// A board's stackup: why a dielectric is prepreg or core.
///
/// A core is a rigid laminate that arrives with copper on both sides; a
/// prepreg is the glue-cloth pressed between cores. Electrically they are
/// both just dielectric, but the fab needs to know which is which.
enum DielectricKind {
  core('Core'),
  prepreg('Prepreg');

  const DielectricKind(this.label);

  final String label;

  static DielectricKind byName(String? name) =>
      values.where((k) => k.name == name).firstOrNull ?? core;
}

/// One copper layer in the build.
class StackupCopper {
  const StackupCopper({
    required this.layer,
    this.thickness = 0.035,
    this.role = LayerRole.signal,
  });

  final CopperLayer layer;

  /// Foil thickness, in millimetres.
  final double thickness;
  final LayerRole role;

  CopperWeight get weight => CopperWeight.nearest(thickness);

  StackupCopper copyWith({double? thickness, LayerRole? role}) => StackupCopper(
    layer: layer,
    thickness: thickness ?? this.thickness,
    role: role ?? this.role,
  );

  Map<String, Object?> toJson() => {
    'layer': layer.layer.token,
    'thickness': thickness,
    'role': role.name,
  };

  @override
  bool operator ==(Object other) =>
      other is StackupCopper &&
      other.layer == layer &&
      other.thickness == thickness &&
      other.role == role;

  @override
  int get hashCode => Object.hash(layer, thickness, role);
}

/// The insulation between two copper layers.
class StackupDielectric {
  const StackupDielectric({
    required this.thickness,
    this.kind = DielectricKind.core,
    this.epsilonR = 4.5,
    this.lossTangent = 0.02,
    this.material = 'FR4',
  });

  /// In millimetres.
  final double thickness;
  final DielectricKind kind;

  /// Relative permittivity: how much the material slows a signal and
  /// lowers a track's impedance. FR-4 is 4.2 to 4.7 depending on the glass
  /// weave and the frequency.
  final double epsilonR;
  final double lossTangent;
  final String material;

  StackupDielectric copyWith({
    double? thickness,
    DielectricKind? kind,
    double? epsilonR,
    double? lossTangent,
    String? material,
  }) => StackupDielectric(
    thickness: thickness ?? this.thickness,
    kind: kind ?? this.kind,
    epsilonR: epsilonR ?? this.epsilonR,
    lossTangent: lossTangent ?? this.lossTangent,
    material: material ?? this.material,
  );

  Map<String, Object?> toJson() => {
    'thickness': thickness,
    'kind': kind.name,
    'epsilonR': epsilonR,
    'lossTangent': lossTangent,
    'material': material,
  };

  @override
  bool operator ==(Object other) =>
      other is StackupDielectric &&
      other.thickness == thickness &&
      other.kind == kind &&
      other.epsilonR == epsilonR &&
      other.lossTangent == lossTangent &&
      other.material == material;

  @override
  int get hashCode =>
      Object.hash(thickness, kind, epsilonR, lossTangent, material);
}

/// Where a track's return current flows, seen from one copper layer: the
/// reference copper above and below it, and what lies between.
class LayerGeometry {
  const LayerGeometry({
    required this.layer,
    required this.copperThickness,
    this.heightAbove,
    this.heightBelow,
    required this.epsilonAbove,
    required this.epsilonBelow,
  });

  final CopperLayer layer;
  final double copperThickness;

  /// Dielectric between this layer's copper and the reference above it, in
  /// millimetres. Null for the top layer, which has air above.
  final double? heightAbove;

  /// The same, below. Null for the bottom layer.
  final double? heightBelow;

  /// Thickness-weighted permittivity of what lies in each gap.
  final double epsilonAbove;
  final double epsilonBelow;

  /// Buried between two references: stripline rather than microstrip.
  bool get isStripline => heightAbove != null && heightBelow != null;
}

/// The physical build of a board, top to bottom.
///
/// [copper] has one entry per copper layer and [dielectrics] one fewer —
/// the gap after each copper layer but the last. Solder mask sits outside
/// the copper on both faces.
class Stackup {
  const Stackup({
    required this.copper,
    required this.dielectrics,
    this.maskThickness = 0.01,
    this.maskEpsilonR = 3.8,
  }) : assert(dielectrics.length == copper.length - 1);

  final List<StackupCopper> copper;
  final List<StackupDielectric> dielectrics;
  final double maskThickness;
  final double maskEpsilonR;

  int get layerCount => copper.length;

  List<CopperLayer> get layers => [for (final c in copper) c.layer];

  /// Finished thickness: copper, dielectric and mask.
  double get thickness =>
      copper.fold<double>(0, (sum, c) => sum + c.thickness) +
      dielectrics.fold<double>(0, (sum, d) => sum + d.thickness) +
      2 * maskThickness;

  StackupCopper copperOf(CopperLayer layer) =>
      copper.firstWhere((c) => c.layer == layer);

  /// The prepreg a build of this size uses between a foil and the core
  /// next to it, in millimetres — a common 7628 glass, near enough.
  static const _prepreg = 0.2;

  /// A conventional build for [layerCount] layers pressed to [thickness].
  ///
  /// Foil on the outside, thinner foil inside; prepreg next to the outer
  /// layers and alternating with cores inward, which is how every board
  /// house quotes a standard build. Inner layers alternate between planes
  /// and signals so that every signal layer sits beside a plane — the one
  /// rule that makes a stackup behave: SIG-GND-SIG-PWR-GND-SIG for six.
  static Stackup standard({
    int layerCount = 2,
    double thickness = 1.6,
    CopperWeight outer = CopperWeight.one,
    CopperWeight inner = CopperWeight.half,
  }) {
    final layers = CopperLayer.stack(layerCount);
    final copper = [
      for (var i = 0; i < layers.length; i++)
        StackupCopper(
          layer: layers[i],
          thickness: layers[i].isInner ? inner.thickness : outer.thickness,
          role: _standardRole(layers.length, i),
        ),
    ];
    const mask = 0.01;
    final copperTotal = copper.fold<double>(0, (sum, c) => sum + c.thickness);
    final available = (thickness - copperTotal - 2 * mask).clamp(
      0.05 * (layers.length - 1),
      double.infinity,
    );

    final gaps = layers.length - 1;
    if (gaps == 1) {
      return Stackup(
        copper: copper,
        dielectrics: [StackupDielectric(thickness: _round(available))],
      );
    }
    // Prepreg on the even gaps counting from the outside, cores between.
    final kinds = [
      for (var i = 0; i < gaps; i++)
        i.isEven ? DielectricKind.prepreg : DielectricKind.core,
    ];
    final prepregs = kinds.where((k) => k == DielectricKind.prepreg).length;
    final cores = gaps - prepregs;
    final prepreg = _prepreg.clamp(0.0, available / gaps);
    final core = (available - prepregs * prepreg) / cores;
    return Stackup(
      copper: copper,
      dielectrics: [
        for (final kind in kinds)
          StackupDielectric(
            kind: kind,
            thickness: _round(kind == DielectricKind.prepreg ? prepreg : core),
            epsilonR: kind == DielectricKind.prepreg ? 4.4 : 4.6,
          ),
      ],
    );
  }

  static LayerRole _standardRole(int count, int index) {
    if (index == 0 || index == count - 1) return LayerRole.signal;
    return switch (count) {
      4 => LayerRole.plane,
      6 => const [
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.plane,
        LayerRole.signal,
      ][index],
      8 => const [
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.plane,
        LayerRole.signal,
        LayerRole.plane,
        LayerRole.signal,
      ][index],
      _ => LayerRole.signal,
    };
  }

  static double _round(double mm) => (mm * 10000).roundToDouble() / 10000;

  /// The same build squeezed or stretched to [thickness], keeping every
  /// prepreg and copper as it is and sharing the change among the cores —
  /// the layers a fab actually picks to hit a thickness.
  Stackup withThickness(double thickness) {
    final delta = thickness - this.thickness;
    final cores = [
      for (var i = 0; i < dielectrics.length; i++)
        if (dielectrics[i].kind == DielectricKind.core) i,
    ];
    final targets = cores.isEmpty
        ? List.generate(dielectrics.length, (i) => i)
        : cores;
    final share = delta / targets.length;
    return Stackup(
      copper: copper,
      dielectrics: [
        for (var i = 0; i < dielectrics.length; i++)
          targets.contains(i)
              ? dielectrics[i].copyWith(
                  thickness: _round(
                    (dielectrics[i].thickness + share).clamp(0.05, 10.0),
                  ),
                )
              : dielectrics[i],
      ],
      maskThickness: maskThickness,
      maskEpsilonR: maskEpsilonR,
    );
  }

  Stackup copyWith({
    List<StackupCopper>? copper,
    List<StackupDielectric>? dielectrics,
  }) => Stackup(
    copper: copper ?? this.copper,
    dielectrics: dielectrics ?? this.dielectrics,
    maskThickness: maskThickness,
    maskEpsilonR: maskEpsilonR,
  );

  /// The geometry impedance is worked out from, for a track on [layer].
  ///
  /// The reference above and below is the nearest *plane* on that side,
  /// and failing one, the next copper layer — a two-layer board's bottom is
  /// usually a ground pour, and treating it as the return is what every
  /// calculator does. A signal layer between the track and its plane is
  /// counted as more dielectric: that is the "dual stripline" of a
  /// SIG-GND-SIG-SIG-PWR-SIG build.
  LayerGeometry geometryOf(CopperLayer layer) {
    final index = copper.indexWhere((c) => c.layer == layer);
    if (index < 0) {
      throw ArgumentError('${layer.label} is not in this stackup');
    }

    int? reference(int step) {
      int? nearest;
      for (var i = index + step; i >= 0 && i < copper.length; i += step) {
        nearest ??= i;
        if (copper[i].role == LayerRole.plane) return i;
      }
      return nearest;
    }

    (double, double)? gap(int? to) {
      if (to == null) return null;
      final from = to < index ? to : index;
      final until = to < index ? index : to;
      var height = 0.0;
      var weighted = 0.0;
      for (var i = from; i < until; i++) {
        final d = dielectrics[i];
        height += d.thickness;
        weighted += d.thickness * d.epsilonR;
        // Copper in between, other than the two ends, is part of the gap.
        if (i + 1 < until) height += copper[i + 1].thickness;
      }
      final dielectric = weighted / _dielectricBetween(from, until);
      return (height, dielectric);
    }

    final above = gap(reference(-1));
    final below = gap(reference(1));
    return LayerGeometry(
      layer: layer,
      copperThickness: copper[index].thickness,
      heightAbove: above?.$1,
      heightBelow: below?.$1,
      epsilonAbove: above?.$2 ?? 1,
      epsilonBelow: below?.$2 ?? 1,
    );
  }

  double _dielectricBetween(int from, int until) {
    var total = 0.0;
    for (var i = from; i < until; i++) {
      total += dielectrics[i].thickness;
    }
    return total == 0 ? 1 : total;
  }

  /// Whether the build can be made: something between every pair of
  /// copper layers, and numbers that are physical.
  String? get problem {
    for (final c in copper) {
      if (c.thickness <= 0) return '${c.layer.label} copper has no thickness';
    }
    for (var i = 0; i < dielectrics.length; i++) {
      final d = dielectrics[i];
      if (d.thickness <= 0) return 'Dielectric ${i + 1} has no thickness';
      if (d.epsilonR < 1) {
        return 'Dielectric ${i + 1} has a permittivity below air';
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'copper': [for (final c in copper) c.toJson()],
    'dielectrics': [for (final d in dielectrics) d.toJson()],
    'maskThickness': maskThickness,
    'maskEpsilonR': maskEpsilonR,
  };

  String encode() => jsonEncode(toJson());

  /// Reads a stored build, or null if [encoded] is empty or does not
  /// describe [layerCount] layers — in which case the standard build is
  /// the right answer, not an error.
  static Stackup? decode(String encoded, {required int layerCount}) {
    if (encoded.trim().isEmpty) return null;
    try {
      final json = jsonDecode(encoded) as Map<String, Object?>;
      final copper = [
        for (final raw in json['copper'] as List)
          StackupCopper(
            layer: CopperLayer.fromToken((raw as Map)['layer'] as String)!,
            thickness: (raw['thickness'] as num).toDouble(),
            role: LayerRole.byName(raw['role'] as String?),
          ),
      ];
      final dielectrics = [
        for (final raw in json['dielectrics'] as List)
          StackupDielectric(
            thickness: ((raw as Map)['thickness'] as num).toDouble(),
            kind: DielectricKind.byName(raw['kind'] as String?),
            epsilonR: (raw['epsilonR'] as num?)?.toDouble() ?? 4.5,
            lossTangent: (raw['lossTangent'] as num?)?.toDouble() ?? 0.02,
            material: raw['material'] as String? ?? 'FR4',
          ),
      ];
      if (copper.length != layerCount || dielectrics.length != layerCount - 1) {
        return null;
      }
      if (copper.map((c) => c.layer).toList().toString() !=
          CopperLayer.stack(layerCount).toString()) {
        return null;
      }
      return Stackup(
        copper: copper,
        dielectrics: dielectrics,
        maskThickness: (json['maskThickness'] as num?)?.toDouble() ?? 0.01,
        maskEpsilonR: (json['maskEpsilonR'] as num?)?.toDouble() ?? 3.8,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Stackup &&
      _listEquals(other.copper, copper) &&
      _listEquals(other.dielectrics, dielectrics) &&
      other.maskThickness == maskThickness &&
      other.maskEpsilonR == maskEpsilonR;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(copper),
    Object.hashAll(dielectrics),
    maskThickness,
    maskEpsilonR,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
