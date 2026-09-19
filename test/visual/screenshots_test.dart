import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/app/appearance.dart';
import 'package:hintpcb/core/theme/kicad_palette.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/symbol_library_repository.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/features/board/board_panel.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/features/settings/settings_panel.dart';
import 'package:hintpcb/kicad/symbol_library_reader.dart';

import '../helpers/footprint_fixture.dart';
import 'package:hintpcb/features/home/home_screen.dart';

import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

/// Renders screens to PNG for looking at, not for asserting on.
///
/// A way to check how a theme or a new view actually looks without a phone
/// in hand. Off by default; run with
/// `HINTPCB_SCREENSHOTS=<dir> flutter test test/visual`.
void main() {
  final outDir = Platform.environment['HINTPCB_SCREENSHOTS'];
  final skip = outDir == null;

  setUpAll(() async {
    if (skip) return;
    // Real fonts, so text reads as text rather than the test font's boxes.
    const mono =
        '/home/jacob/flutter/bin/cache/dart-sdk/bin/resources/'
        'devtools/assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf';
    const icons =
        '/home/jacob/flutter/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf';
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

  tearDown(() => KicadPalette.current = AppPalettes.hintpcb);

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

  for (final palette in [AppPalettes.hintpcb, AppPalettes.paper]) {
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
    AppPalettes.hintpcb,
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
