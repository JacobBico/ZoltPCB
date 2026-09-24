import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/features/board/board_shape_editor.dart';

import '../helpers/pump_app.dart';

void main() {
  // Reported: the board edge could only be set by dragging corners, which
  // is slow and never lands on an exact size.
  Future<BoardOutline?> edit(
    WidgetTester tester,
    AppDatabase db,
    BoardOutline start,
    Future<void> Function() interact,
  ) async {
    BoardOutline? result;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showBoardShapeEditor(context, outline: start),
            child: const Text('open'),
          ),
        ),
      ),
      database: db,
    );
    await tester.tap(find.text('open'));
    await settleApp(tester);
    await interact();
    return result;
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testApp('typed width and height give exactly that rectangle', (
    tester,
    db,
  ) async {
    final result = await edit(
      tester,
      db,
      BoardOutline.rectangle(const Rect.fromLTWH(20, 20, 60, 40)),
      () async {
        await tester.enterText(field('Width'), '50.8');
        await tester.enterText(field('Height'), '33.02');
        await settleApp(tester);
        await tester.tap(find.text('APPLY'));
        await settleApp(tester);
      },
    );

    expect(result!.kind, BoardOutlineKind.rectangle);
    expect(result.bounds.width, closeTo(50.8, 1e-9));
    expect(result.bounds.height, closeTo(33.02, 1e-9));
    // Resized in place, not moved.
    expect(result.bounds.topLeft, const Offset(20, 20));
  });

  testApp('a circle is set by its diameter', (tester, db) async {
    final result = await edit(
      tester,
      db,
      BoardOutline.rectangle(const Rect.fromLTWH(20, 20, 60, 40)),
      () async {
        await tester.tap(find.text('Circle'));
        await settleApp(tester);
        await tester.enterText(field('Diameter'), '25');
        await settleApp(tester);
        await tester.tap(find.text('APPLY'));
        await settleApp(tester);
      },
    );

    expect(result!.kind, BoardOutlineKind.circle);
    expect(result.radius * 2, closeTo(25, 1e-9));
  });

  testApp('a preset gives a polygon of the board\'s size', (tester, db) async {
    final result = await edit(
      tester,
      db,
      BoardOutline.rectangle(const Rect.fromLTWH(0, 0, 40, 30)),
      () async {
        await tester.tap(find.text('Polygon'));
        await settleApp(tester);
        await tester.tap(find.text('Triangle'));
        await settleApp(tester);
        await tester.tap(find.text('APPLY'));
        await settleApp(tester);
      },
    );

    expect(result!.kind, BoardOutlineKind.polygon);
    expect(result.points, hasLength(3));
    expect(result.bounds.width, closeTo(40, 1e-9));
    expect(result.bounds.height, closeTo(30, 1e-9));
  });

  testApp('an edge that crosses itself cannot be applied', (tester, db) async {
    // A bow tie: corners in the wrong order, so two edges cross.
    final result = await edit(
      tester,
      db,
      BoardOutline.polygon(const [
        Offset(0, 0),
        Offset(20, 20),
        Offset(20, 0),
        Offset(0, 20),
      ]),
      () async {
        expect(find.textContaining('cross each other'), findsOneWidget);
        final apply = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'APPLY'),
        );
        expect(apply.onPressed, isNull);
      },
    );
    expect(result, isNull);
  });

  testApp('a nonsense size is refused, not applied', (tester, db) async {
    await edit(
      tester,
      db,
      BoardOutline.rectangle(const Rect.fromLTWH(0, 0, 40, 30)),
      () async {
        await tester.enterText(field('Width'), '0');
        await settleApp(tester);
        final apply = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'APPLY'),
        );
        expect(apply.onPressed, isNull);
      },
    );
  });
}
