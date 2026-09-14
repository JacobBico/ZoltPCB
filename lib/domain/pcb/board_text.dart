import 'dart:ui';

import 'board_layer.dart';

/// A piece of text on the silkscreen that belongs to the board rather than
/// to a part: a name, a revision, a note beside a connector.
class BoardText {
  const BoardText({
    required this.id,
    required this.projectId,
    required this.content,
    required this.position,
    this.rotation = 0,
    this.size = 1.0,
    this.back = false,
  });

  final String id;
  final String projectId;
  final String content;

  /// Centre of the text, in board millimetres.
  final Offset position;

  /// Degrees counter-clockwise.
  final double rotation;

  /// Character height, in millimetres.
  final double size;

  /// On the underside. Text there is read through the board, so it is
  /// written mirrored — which KiCad's DRC insists on.
  final bool back;

  BoardLayer get layer => back ? BoardLayer.backSilk : BoardLayer.frontSilk;

  BoardText copyWith({
    String? content,
    Offset? position,
    double? rotation,
    double? size,
    bool? back,
  }) => BoardText(
    id: id,
    projectId: projectId,
    content: content ?? this.content,
    position: position ?? this.position,
    rotation: rotation ?? this.rotation,
    size: size ?? this.size,
    back: back ?? this.back,
  );
}
