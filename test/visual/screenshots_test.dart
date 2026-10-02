import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/app/appearance.dart';
import 'package:zolt/core/theme/kicad_palette.dart';
import 'package:zolt/data/repositories/board_repository.dart';
import 'package:zolt/data/repositories/footprint_library_repository.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/domain/symbols/symbols.dart';
import 'package:zolt/features/board/board_panel.dart';
import 'package:zolt/features/project/schematic_panel.dart';
import 'package:zolt/features/settings/settings_panel.dart';
import 'package:zolt/kicad/symbol_library_reader.dart';

import '../helpers/footprint_fixture.dart';
import 'package:zolt/features/home/home_screen.dart';

import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

/// Renders screens to PNG for looking at, not for asserting on.
///
/// A way to check how a theme or a new view actually looks without a phone
/// in hand. Off by default; run with
/// `ZOLT_SCREENSHOTS=<dir> flutter test test/visual`.
void main() {
  final outDir = Platform.environment['ZOLT_SCREENSHOTS'];
  final skip = outDir == null;

  setUpAll(() async {
    if (skip) return;
    // Real fonts, so text reads as text rather than the test font's boxes,
    // from the Flutter SDK whose flutter_tester is running this.
    final exe = Platform.resolvedExecutable;
    final cache = exe.substring(0, exe.indexOf('/bin/cache/') + 11);
    final mono =
        '${cache}dart-sdk/bin/resources/'
        'devtools/assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf';
    final icons = '${cache}artifacts/material_fonts/MaterialIcons-Regular.otf';
    for (final (family, path) in [
      ('monospace', mono),
      ('MaterialIcons', icons),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
        );
      await loader.load();
    }
  });

  tearDown(() => KicadPalette.current = AppPalettes.zolt);

  const key = ValueKey('shot');

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Widget framed(Widget child) => RepaintBoundary(
    key: key,
    child: Scaffold(body: child),
  );

  testAppWithStorage('settings', skip: skip, (tester, db, storage) async {
    await pumpApp(
      tester,
      framed(const SettingsPanel()),
      database: db,
      storage: storage,
    );
    await shoot(tester, 'settings');
  });

  for (final palette in [AppPalettes.zolt, AppPalettes.paper]) {
    testAppWithStorage('home ${palette.id}', skip: skip, (
      tester,
      db,
      storage,
    ) async {
      KicadPalette.current = palette;
      await pumpApp(
        tester,
        RepaintBoundary(key: key, child: const HomeScreen()),
        database: db,
        storage: storage,
      );
      // The logo is read from the asset bundle, which is real I/O.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settleApp(tester);
      await shoot(tester, 'home_${palette.id}');
    });
  }

  for (final palette in [
    AppPalettes.zolt,
    AppPalettes.kicad,
    AppPalettes.banana,
    AppPalettes.halloween,
    AppPalettes.paper,
  ]) {
    testAppWithStorage('schematic ${palette.id}', skip: skip, (
      tester,
      db,
      storage,
    ) async {
      KicadPalette.current = palette;
      await SymbolLibraryRepository(
        db,
        storage,
      ).import(fileName: 'Device.kicad_sym', bytes: libraryBytes());
      final library = SymbolLibraryReader.parseLibrary(
        libraryBytes(),
        nickname: 'Device',
      );
      SymbolDefinition sym(String name) =>
          library.symbols.firstWhere((s) => s.name == name);

      final project = await ProjectRepository(db).create(name: 'Shot');
      final parts = PartRepository(db);
      final nets = NetRepository(db);
      final r1 = await parts.addPart(
        project.id,
        sym('R').toNewPartSpec(value: '4k7'),
      );
      final c1 = await parts.addPart(
        project.id,
        sym('C').toNewPartSpec(value: '100n'),
      );
      final u1 = await parts.addPart(project.id, sym('LM2904').toNewPartSpec());
      await nets.connectPins(r1.pins.last.id, c1.pins.first.id);
      await nets.connectPins(
        c1.pins.last.id,
        u1.pins.firstWhere((p) => p.number == '3').id,
      );

      await pumpApp(
        tester,
        framed(SchematicPanel(project: project)),
        database: db,
        storage: storage,
      );
      if (palette == AppPalettes.halloween) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SchematicPanel)),
        );
        await container
            .read(appearanceProvider.notifier)
            .setResistorStyle(ResistorStyle.ansi);
        await settleApp(tester);
      }
      await shoot(tester, 'schematic_${palette.id}');
    });
  }

  testAppWithStorage('board preview', skip: skip, (tester, db, storage) async {
    final footprintStorage = InMemoryLibraryStorageFor();
    final project = await ProjectRepository(db).create(name: 'Shot');
    final parts = PartRepository(db);
    final boards = BoardRepository(db);
    await FootprintLibraryRepository(
      db,
      footprintStorage,
    ).import(nickname: 'Test', sources: twoPadFootprintSources());

    final placed = <String>[];
    for (var i = 0; i < 4; i++) {
      final part = await parts.addPart(
        project.id,
        SymbolLibraryReader.parseLibrary(
          libraryBytes(),
          nickname: 'Device',
        ).symbols.firstWhere((s) => s.name == 'R').toNewPartSpec(),
      );
      placed.add(part.part.id);
    }
    final board = await boards.ensureBoard(project.id);
    await boards.updateBoard(
      board.withOutline(
        BoardOutline.polygon(const [
          Offset(20, 20),
          Offset(70, 20),
          Offset(80, 35),
          Offset(70, 55),
          Offset(20, 55),
        ]),
      ),
    );
    for (var i = 0; i < placed.length; i++) {
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: placed[i],
        libId: 'Test:TwoPad',
      );
      await boards.updatePlacement(
        ref.copyWith(x: 32.0 + 11 * i, y: 30 + 6.0 * (i % 2), placed: true),
      );
    }
    await boards.addTrack(
      projectId: project.id,
      layer: CopperLayer.front,
      startX: 33,
      startY: 30,
      endX: 42,
      endY: 36,
      width: 0.4,
    );

    await pumpApp(
      tester,
      framed(BoardPanel(project: project)),
      database: db,
      storage: storage,
      footprintStorage: footprintStorage,
    );
    await shoot(tester, 'board_edit');

    await tester.tap(find.text('Preview'));
    await settleApp(tester);
    await shoot(tester, 'board_preview');
  });
}
