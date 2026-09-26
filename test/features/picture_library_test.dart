import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/repositories/picture_repository.dart';
import 'package:zolt/domain/pcb/pcb.dart';
import 'package:zolt/features/pictures/picture_library.dart';

import '../helpers/pump_app.dart';

void main() {
  testApp('the library keeps pictures, and offers the logo built in', (
    tester,
    db,
  ) async {
    final pictures = PictureRepository(db);
    final saved = await pictures.add(
      name: 'Mascot',
      width: 12,
      columns: 4,
      rows: 2,
      bits: BoardImage.pack([
        true, false, true, false, //
        false, true, false, true,
      ]),
    );
    final read = (await pictures.getAll()).single;
    expect(read.name, 'Mascot');
    expect(read.bits, saved.bits);

    // The built-in pictures are drawn with the real canvas, which needs the
    // real clock.
    await tester.runAsync(PictureLibrary.builtIns);
    await pumpApp(tester, const Scaffold(body: PictureLibrary()), database: db);

    expect(find.text('Zolt logo'), findsOneWidget);
    expect(find.text('Zolt mark'), findsOneWidget);
    expect(find.text('Mascot'), findsOneWidget);
    // The app's own cannot be deleted; an imported one can.
    expect(
      find.byKey(const ValueKey('picture-delete-builtin:logo')),
      findsNothing,
    );
    await tester.tap(find.byKey(ValueKey('picture-delete-${saved.id}')));
    await settleApp(tester);
    expect(find.text('Mascot'), findsNothing);
    expect(await pictures.getAll(), isEmpty);
  });
}
