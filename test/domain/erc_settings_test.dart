import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/domain/erc/erc.dart';

void main() {
  const loose = ErcViolation(
    rule: ErcRule.unconnectedPin,
    severity: ErcSeverity.warning,
    message: 'U1: 3 pins are unconnected',
  );
  const clash = ErcViolation(
    rule: ErcRule.outputsTogether,
    severity: ErcSeverity.error,
    message: 'U1.1 and U2.1 both drive OUT',
  );

  test('the defaults change nothing', () {
    expect(ErcSettings.defaults.apply([loose, clash]).map((v) => v.severity), [
      ErcSeverity.error,
      ErcSeverity.warning,
    ]);
  });

  test('a rule switched off is not reported', () {
    final settings = ErcSettings.defaults.withLevel(
      ErcRule.unconnectedPin,
      ErcLevel.ignore,
    );
    expect(settings.apply([loose, clash]), [clash]);
  });

  test('a warning can be made an error, and sorts with the errors', () {
    final settings = ErcSettings.defaults.withLevel(
      ErcRule.unconnectedPin,
      ErcLevel.error,
    );
    final result = settings.apply([clash, loose]);
    expect(result.every((v) => v.isError), isTrue);
  });

  test('setting a rule back to its default forgets it', () {
    final settings = ErcSettings.defaults
        .withLevel(ErcRule.unconnectedPin, ErcLevel.ignore)
        .withLevel(ErcRule.unconnectedPin, ErcLevel.warning);
    expect(settings.isDefault, isTrue);
  });

  test('settings survive storage', () {
    final settings = ErcSettings.defaults
        .withLevel(ErcRule.lonelyNet, ErcLevel.ignore)
        .withLevel(ErcRule.missingFootprint, ErcLevel.error);
    expect(ErcSettings.fromSettings(settings.toSettings()), settings);
    expect(ErcSettings.fromSettings(const {}), ErcSettings.defaults);
    // Anything else in the project's settings is not ours to read.
    expect(
      ErcSettings.fromSettings(const {'erc.lonelyNet': 'nonsense', 'x': 'y'}),
      ErcSettings.defaults,
    );
  });
}
