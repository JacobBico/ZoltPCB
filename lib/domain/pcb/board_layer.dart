/// The layers HintPCB draws and routes on.
///
/// KiCad defines about sixty; a board laid out on a phone needs these.
/// Anything else in an imported footprint is parsed and kept as its raw
/// name, then ignored at draw time — better than refusing a file for
/// mentioning a layer we have no use for.
enum BoardLayer {
  frontCopper('F.Cu'),
  inner1Copper('In1.Cu'),
  inner2Copper('In2.Cu'),
  inner3Copper('In3.Cu'),
  inner4Copper('In4.Cu'),
  inner5Copper('In5.Cu'),
  inner6Copper('In6.Cu'),
  backCopper('B.Cu'),
  frontSilk('F.SilkS'),
  backSilk('B.SilkS'),
  frontMask('F.Mask'),
  backMask('B.Mask'),
  frontPaste('F.Paste'),
  backPaste('B.Paste'),
  frontCourtyard('F.CrtYd'),
  backCourtyard('B.CrtYd'),
  frontFab('F.Fab'),
  backFab('B.Fab'),
  edgeCuts('Edge.Cuts');

  const BoardLayer(this.token);

  /// The name KiCad writes in files.
  final String token;

  static BoardLayer? fromToken(String token) {
    for (final layer in values) {
      if (layer.token == token) return layer;
    }
    return null;
  }

  bool get isCopper => token.endsWith('.Cu');

  /// Copper buried inside the board, reachable only through a hole.
  bool get isInnerCopper => token.startsWith('In');

  bool get isFront => token.startsWith('F.');

  /// The same layer on the other side of the board, for flipping a
  /// footprint. Layers with no side — the board outline, and the inner
  /// copper, which a flipped part's holes pass through all the same — stay
  /// put.
  BoardLayer get flipped => switch (this) {
    frontCopper => backCopper,
    backCopper => frontCopper,
    frontSilk => backSilk,
    backSilk => frontSilk,
    frontMask => backMask,
    backMask => frontMask,
    frontPaste => backPaste,
    backPaste => frontPaste,
    frontCourtyard => backCourtyard,
    backCourtyard => frontCourtyard,
    frontFab => backFab,
    backFab => frontFab,
    _ => this,
  };
}

/// A copper layer a track can run on.
///
/// Kept separate from [BoardLayer] so everything routing touches ranges
/// over copper alone. Front and back are always there; how many of the
/// inner layers exist is the board's to say — see [stack].
enum CopperLayer {
  front(BoardLayer.frontCopper, 'Front', 'F'),
  inner1(BoardLayer.inner1Copper, 'Inner 1', 'In1'),
  inner2(BoardLayer.inner2Copper, 'Inner 2', 'In2'),
  inner3(BoardLayer.inner3Copper, 'Inner 3', 'In3'),
  inner4(BoardLayer.inner4Copper, 'Inner 4', 'In4'),
  inner5(BoardLayer.inner5Copper, 'Inner 5', 'In5'),
  inner6(BoardLayer.inner6Copper, 'Inner 6', 'In6'),
  back(BoardLayer.backCopper, 'Back', 'B');

  const CopperLayer(this.layer, this.label, this.shortLabel);

  final BoardLayer layer;
  final String label;

  /// `F`, `In1`, `B` — for a chip with no room for a word.
  final String shortLabel;

  /// The copper counts a board can be built with. Odd counts exist but no
  /// board house wants one: the build is pressed symmetrically.
  static const layerCounts = [2, 4, 6, 8];

  /// The copper of a board with [count] layers, top to bottom.
  static List<CopperLayer> stack(int count) {
    final inner = (count - 2).clamp(0, 6);
    return [front, for (var i = 0; i < inner; i++) values[1 + i], back];
  }

  static CopperLayer? fromToken(String token) {
    for (final layer in values) {
      if (layer.layer.token == token) return layer;
    }
    return null;
  }

  bool get isInner => this != front && this != back;

  /// The outer layer on the other side — where a two-layer board's toggle
  /// goes. An inner layer answers front, the side a part is usually on.
  CopperLayer get other => switch (this) {
    front => back,
    back => front,
    _ => front,
  };

  /// KiCad's fixed number for the layer: F.Cu 0, B.Cu 2, In1.Cu 4, In2.Cu 6
  /// and so on. Its own files, not a choice of ours; inventing them puts
  /// copper on the wrong layer.
  int get kicadIndex => switch (this) {
    front => 0,
    back => 2,
    _ => 2 * index + 2,
  };

  /// The Gerber file function: `Copper,L1,Top` … `Copper,L4,Bot`.
  String fileFunction(int layerCount) {
    final position = stack(layerCount).indexOf(this) + 1;
    final side = switch (this) {
      front => 'Top',
      back => 'Bot',
      _ => 'Inr',
    };
    return 'Copper,L$position,$side';
  }
}
