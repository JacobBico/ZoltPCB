/// The layers HintPCB draws and routes on.
///
/// KiCad defines about thirty; a two-layer board laid out on a phone needs
/// these. Anything else in an imported footprint is parsed and kept as its
/// raw name, then ignored at draw time — better than refusing a file for
/// mentioning a layer we have no use for.
enum BoardLayer {
  frontCopper('F.Cu'),
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

  bool get isCopper =>
      this == BoardLayer.frontCopper || this == BoardLayer.backCopper;

  bool get isFront => token.startsWith('F.');

  /// The same layer on the other side of the board, for flipping a
  /// footprint. Layers with no side, such as the board outline, stay put.
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
    edgeCuts => edgeCuts,
  };
}

/// The two sides a track can run on.
///
/// Kept separate from [BoardLayer] so that everything routing touches is
/// exhaustive over exactly two cases: a two-layer board is a decision, not
/// an accident of which layers happen to be enabled.
enum CopperLayer {
  front(BoardLayer.frontCopper, 'Front'),
  back(BoardLayer.backCopper, 'Back');

  const CopperLayer(this.layer, this.label);

  final BoardLayer layer;
  final String label;

  CopperLayer get other => this == front ? back : front;
}
