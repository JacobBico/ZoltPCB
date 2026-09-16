import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/models/pin.dart';
import 'package:hintpcb/domain/symbols/symbols.dart';
import 'package:hintpcb/features/pinout/package_diagram.dart';
import 'package:hintpcb/features/pinout/pinout_explorer.dart';

import '../helpers/pump_app.dart';

/// A 48-pin part drawn the way KiCad draws an MCU: almost everything down
/// the two sides, a few supplies top and bottom.
SymbolDefinition _mcu() {
  final pins = <SymbolPin>[];
  var number = 1;
  SymbolPin pin(double x, double y, double angle) => SymbolPin(
    number: '${number++}',
    name: 'P$number',
    electricalType: PinElectricalType.bidirectional,
    at: SymbolPoint(x, y),
    angle: angle,
  );

  for (var i = 0; i < 22; i++) {
    pins.add(pin(-30, 30 - i * 2.54, 0));
  }
  for (var i = 0; i < 22; i++) {
    pins.add(pin(30, 30 - i * 2.54, 180));
  }
  for (var i = 0; i < 2; i++) {
    pins.add(pin(-10 + i * 10, 40, 270));
  }
  for (var i = 0; i < 2; i++) {
    pins.add(pin(-10 + i * 10, -40, 90));
  }

  return SymbolDefinition(
    libraryNickname: 'MCU',
    name: 'BIG48',
    unitDrawings: [SymbolUnitDrawing(unit: 1, bodyStyle: 1, pins: pins)],
  );
}

void main() {
  testApp('the whole package fits the space it is given', (tester, db) async {
    // A landscape phone leaves the diagram about this much room beside the
    // peripheral list. Drawn at a readable pitch a 48-pin part is three
    // times that tall, so it has to be scaled to fit — clipped at both ends
    // is how it shipped the first time, and the shape is the whole point.
    const available = Size(596, 300);

    await pumpApp(
      tester,
      Center(
        child: SizedBox(
          width: available.width,
          height: available.height,
          child: PackageDiagram(
            layout: PackageLayout.of(_mcu()),
            title: 'BIG48',
          ),
        ),
      ),
      database: db,
    );

    final painted = tester.getRect(find.byType(CustomPaint).last);
    expect(painted.width, lessThanOrEqualTo(available.width + 0.5));
    expect(painted.height, lessThanOrEqualTo(available.height + 0.5));
  });

  testApp('tapping a pin reports which one', (tester, db) async {
    PackagePin? tapped;
    await pumpApp(
      tester,
      Center(
        child: SizedBox(
          width: 596,
          height: 300,
          child: PackageDiagram(
            layout: PackageLayout.of(_mcu()),
            title: 'BIG48',
            onPinTap: (pin) => tapped = pin,
          ),
        ),
      ),
      database: db,
    );

    // Down the left edge is a column of pins, whichever one it turns out
    // to be; what matters is that a tap on the drawing finds one at all.
    final box = tester.getRect(find.byType(CustomPaint).last);
    await tester.tapAt(Offset(box.left + box.width * 0.16, box.center.dy));
    await settleApp(tester);

    expect(tapped, isNotNull);
  });

  testApp('the explorer fits the package into a landscape phone', (
    tester,
    db,
  ) async {
    // The same check, through the layout the app actually builds: a header
    // above, the peripheral list beside. The diagram is nested three deep
    // by the time it is drawn, and the fit has to survive that.
    await pumpApp(
      tester,
      Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 44),
            Expanded(child: PinoutExplorer(symbol: _mcu())),
          ],
        ),
      ),
      database: db,
    );

    final painted = tester.getRect(find.byType(CustomPaint).last);
    final screen = tester.getRect(find.byType(Scaffold));
    expect(painted.height, lessThanOrEqualTo(screen.height));
    expect(painted.top, greaterThanOrEqualTo(screen.top - 0.5));
    expect(painted.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
  });
}
