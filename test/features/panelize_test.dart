import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/board_repository.dart';
import 'package:hintpcb/data/repositories/footprint_library_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/data/repositories/project_settings_repository.dart';
import 'package:hintpcb/domain/pcb/pcb.dart';
import 'package:hintpcb/features/panelize/panelize_panel.dart';
import 'package:hintpcb/features/production/gerber_view.dart';

import '../helpers/fixtures.dart';
import '../helpers/footprint_fixture.dart';
import '../helpers/pump_app.dart';

GerberPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<GerberPainter>()
    .single;

void main() {
  testAppWithStorage(
    'the panel grows a column, joins by V-score, and keeps the choice',
    (tester, db, storage) async {
      final project = await ProjectRepository(db).create(name: 'Panel');
      final footprintStorage = InMemoryLibraryStorageFor();
      await FootprintLibraryRepository(
        db,
        footprintStorage,
      ).import(nickname: 'Test', sources: twoPadFootprintSources());
      final part = await PartRepository(db).addPart(project.id, resistorSpec());
      final boards = BoardRepository(db);
      final ref = await boards.assignFootprint(
        projectId: project.id,
        partId: part.part.id,
        libId: 'Test:TwoPad',
      );
      await boards.updatePlacement(ref.copyWith(x: 30, y: 35, placed: true));

      await pumpApp(
        tester,
        Scaffold(body: PanelizePanel(project: project)),
        database: db,
        footprintStorage: footprintStorage,
      );

      // Two by two to begin with: four copies of the board's copper.
      expect(find.byKey(const ValueKey('panel-size')), findsOneWidget);
      expect(find.textContaining('4 boards'), findsOneWidget);
      int pads() => _painter(tester).layers
          .firstWhere((l) => l.label == 'Top copper')
          .image!
          .shapes
          .whereType<Object>()
          .length;
      final fourCopies = pads();

      await tester.tap(find.byKey(const ValueKey('panel-columns-plus')));
      await settleApp(tester);
      expect(find.textContaining('6 boards'), findsOneWidget);
      expect(pads(), greaterThan(fourCopies));

      // V-score: no milled gap to set, and a file of score lines.
      await tester.tap(find.text('V-score'));
      await settleApp(tester);
      expect(find.byKey(const ValueKey('panel-gap')), findsNothing);
      expect(_painter(tester).layers.map((l) => l.label), contains('V-score'));

      final saved = PanelSettings.decode(
        (await ProjectSettingsRepository(
          db,
        ).getAll(project.id))[PanelSettings.settingsKey],
      );
      expect(saved.columns, 3);
      expect(saved.join, PanelJoin.vScore);
    },
  );
}
