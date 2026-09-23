import 'dart:convert';

import '../domain/export/board_document.dart';
import '../domain/pcb/pcb.dart';

/// Writes the `.kicad_pro` that goes beside a `.kicad_pcb`.
///
/// KiCad splits a board across two files, and the split is not where you
/// would guess: the copper is in the board, but the rules the copper has to
/// obey are in the project. Clearance, track width and via size chosen on
/// the phone only mean something on the desktop if they are written here —
/// putting them in the board file instead produces a file KiCad will not
/// open.
///
/// JSON rather than s-expressions, because that is what the format is.
abstract final class BoardProjectWriter {
  /// The schema version of the project file KiCad 9 writes.
  static const projectVersion = 3;

  static String write(BoardDocument document, {required String fileName}) {
    final rules = document.board.rules;
    final teardrops = document.board.teardrops;
    // Only turned on when the board actually has one: KiCad's own rule
    // check refuses a blind via on a board whose project says it may not
    // have any, which would turn our own board into an error the moment it
    // was opened.
    final blind = document.scene.vias.any((v) => v.kind != ViaKind.through);

    final project = <String, Object?>{
      'board': {
        'design_settings': {
          'defaults': {
            'board_outline_line_width': 0.1,
            'copper_line_width': rules.trackWidth,
            'copper_text_size_h': 1.0,
            'copper_text_size_v': 1.0,
            'copper_text_thickness': 0.15,
            'silk_line_width': 0.1,
            'silk_text_size_h': 1.0,
            'silk_text_size_v': 1.0,
            'silk_text_thickness': 0.1,
          },
          // The minimums DRC enforces. Set from the user's own rule rather
          // than from KiCad's defaults, so running DRC on the desktop
          // checks the board the phone thought it was checking.
          'rules': {
            'allow_blind_buried_vias': blind,
            'allow_microvias': false,
            'max_error': 0.005,
            'min_clearance': rules.clearance,
            'min_copper_edge_clearance': 0.05,
            'min_hole_to_hole': 0.25,
            'min_through_hole_diameter': 0.3,
            'min_track_width': rules.trackWidth,
            'min_via_annular_width': (rules.viaDiameter - rules.viaDrill) / 2,
            'min_via_diameter': rules.viaDiameter,
          },
          // So "Edit Teardrops" on the desktop regenerates the same
          // fillets the phone drew and the Gerbers already hold.
          'teardrop_options': [
            {
              'td_onpadsmd': teardrops.enabled && teardrops.onPads,
              'td_onroundshapesonly': false,
              'td_ontrackend': false,
              'td_onviapad': teardrops.enabled && teardrops.onVias,
            },
          ],
          'teardrop_parameters': [
            for (final target in const [
              'td_round_shape',
              'td_rect_shape',
              'td_track_end',
            ])
              {
                'td_allow_use_two_tracks': true,
                'td_curve_segcount': 0,
                'td_height_ratio': teardrops.widthRatio,
                'td_length_ratio': teardrops.lengthRatio,
                'td_maxheight': 2.0,
                'td_maxlen': 1.0,
                'td_on_pad_in_zone': false,
                'td_target_name': target,
                'td_width_to_size_filter_ratio': 0.9,
              },
          ],
          'track_widths': [0.0, rules.trackWidth],
          'via_dimensions': [
            {'diameter': 0.0, 'drill': 0.0},
            {'diameter': rules.viaDiameter, 'drill': rules.viaDrill},
          ],
        },
      },
      'meta': {'filename': fileName, 'version': projectVersion},
      'net_settings': {
        'classes': [
          {
            'bus_width': 12,
            'clearance': rules.clearance,
            'diff_pair_gap': 0.25,
            'diff_pair_via_gap': 0.25,
            'diff_pair_width': 0.2,
            'line_style': 0,
            'microvia_diameter': 0.3,
            'microvia_drill': 0.1,
            'name': 'Default',
            'pcb_color': 'rgba(0, 0, 0, 0.000)',
            'priority': 2147483647,
            'schematic_color': 'rgba(0, 0, 0, 0.000)',
            'track_width': rules.trackWidth,
            'via_diameter': rules.viaDiameter,
            'via_drill': rules.viaDrill,
            'wire_width': 6,
          },
          for (final (index, netClass) in document.scene.netClasses.indexed)
            {
              'bus_width': 12,
              'clearance': netClass.clearance ?? rules.clearance,
              'diff_pair_gap': 0.25,
              'diff_pair_via_gap': 0.25,
              'diff_pair_width': 0.2,
              'line_style': 0,
              'microvia_diameter': 0.3,
              'microvia_drill': 0.1,
              'name': netClass.name,
              'pcb_color': 'rgba(0, 0, 0, 0.000)',
              'priority': index,
              'schematic_color': 'rgba(0, 0, 0, 0.000)',
              'track_width': netClass.trackWidth,
              'via_diameter': rules.viaDiameter,
              'via_drill': rules.viaDrill,
              'wire_width': 6,
            },
        ],
        'meta': {'version': 4},
        'net_colors': null,
        'netclass_assignments': null,
        // Each net named outright, which is how KiCad records a net put in a
        // class by hand rather than by a wildcard.
        'netclass_patterns': [
          for (final net in document.nets)
            if (document.scene.classOf(net.net.id) case final netClass?)
              {'netclass': netClass.name, 'pattern': net.displayName},
        ],
      },
      'sheets': <Object?>[],
      'text_variables': <String, Object?>{},
    };

    return const JsonEncoder.withIndent('  ').convert(project);
  }

  /// The design rules a project file describes, for reading one back.
  static DesignRules? rulesFrom(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final classes = (decoded['net_settings'] as Map?)?['classes'] as List?;
    final first = classes?.firstOrNull;
    if (first is! Map) return null;
    return DesignRules(
      trackWidth: (first['track_width'] as num?)?.toDouble() ?? 0.25,
      clearance: (first['clearance'] as num?)?.toDouble() ?? 0.2,
      viaDiameter: (first['via_diameter'] as num?)?.toDouble() ?? 0.8,
      viaDrill: (first['via_drill'] as num?)?.toDouble() ?? 0.4,
    );
  }
}
