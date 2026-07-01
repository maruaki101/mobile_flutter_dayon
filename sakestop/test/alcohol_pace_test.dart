import 'package:flutter_test/flutter_test.dart';
import 'package:sakestop/alcohol_pace.dart';

void main() {
  group('calculatePureAlcoholGrams', () {
    test('容量と度数から純アルコール量を計算する', () {
      expect(calculatePureAlcoholGrams(volume: 500, alcoholPercentage: 5), 20);
    });
  });

  group('calculateAlcoholWithin', () {
    test('30分以内の摂取量だけを合計する', () {
      final now = DateTime(2026, 6, 24, 12);
      final intakes = [
        AlcoholIntake(
          pureAlcohol: 12,
          timestamp: now.subtract(const Duration(minutes: 10)),
        ),
        AlcoholIntake(
          pureAlcohol: 8,
          timestamp: now.subtract(const Duration(minutes: 30)),
        ),
        AlcoholIntake(
          pureAlcohol: 30,
          timestamp: now.subtract(const Duration(minutes: 31)),
        ),
      ];

      expect(calculateAlcoholWithin(intakes: intakes, now: now), 20);
    });
  });

  group('shouldNotifyAlcoholPace', () {
    final now = DateTime(2026, 6, 24, 12);
    final thresholdIntakes = [
      AlcoholIntake(
        pureAlcohol: 40,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
    ];

    test('30分以内に40g以上なら通知する', () {
      expect(
        shouldNotifyAlcoholPace(intakes: thresholdIntakes, now: now),
        isTrue,
      );
    });

    test('30分以内で40g未満なら通知しない', () {
      expect(
        shouldNotifyAlcoholPace(
          intakes: [
            AlcoholIntake(
              pureAlcohol: 39.9,
              timestamp: now.subtract(const Duration(minutes: 5)),
            ),
          ],
          now: now,
        ),
        isFalse,
      );
    });

    test('ビール500ml相当の20gだけでは通知しない', () {
      expect(
        shouldNotifyAlcoholPace(
          intakes: [
            AlcoholIntake(
              pureAlcohol: 20,
              timestamp: now.subtract(const Duration(minutes: 5)),
            ),
          ],
          now: now,
        ),
        isFalse,
      );
    });

    test('前回通知から30分未満なら通知しない', () {
      expect(
        shouldNotifyAlcoholPace(
          intakes: thresholdIntakes,
          now: now,
          lastNotificationAt: now.subtract(const Duration(minutes: 29)),
        ),
        isFalse,
      );
    });

    test('前回通知から30分経過していれば再通知する', () {
      expect(
        shouldNotifyAlcoholPace(
          intakes: thresholdIntakes,
          now: now,
          lastNotificationAt: now.subtract(const Duration(minutes: 30)),
        ),
        isTrue,
      );
    });
  });
}
