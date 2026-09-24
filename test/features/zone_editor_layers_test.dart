import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/features/board/zone_editor.dart';

void main() {
  // "Pour properties: Please implement a fix" — a pour drawn on an inner
  // layer opened a dialog that could only say front or back, and any tap
  // moved the pour to one of them.
  testWidgets('a pour on an inner layer keeps its layer', (tester) async {
    final zone = BoardZone(
      id: 'z',
      projectId: 'p',
      layer: BoardLayer.inner2Copper,
      points: const [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
      netName: '',
    );
    ZoneResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showZoneEditor(
              context,
              outline: BoardOutline.rectangle(
                const Rect.fromLTWH(0, 0, 40, 30),
              ),
              nets: const [],
              defaultClearance: 0.2,
              layers: [
                for (final layer in CopperLayer.stack(6)) layer.layer,
              ],
              zone: zone,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Every layer the board has is offered, by its short name.
    expect(find.text('In2'), findsOneWidget);
    expect(find.text('F.Cu'), findsNothing, reason: 'named, not tokenised');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(result, isA<ZoneSaved>());
    expect((result! as ZoneSaved).layer, BoardLayer.inner2Copper);
  });
}
