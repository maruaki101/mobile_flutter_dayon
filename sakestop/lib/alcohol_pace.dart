// 飲酒ペース判定用の定数
// - alcoholPaceWindow: 何分間の飲酒量を計算するか
// - alcoholPaceThresholdGrams: 通知を出す純アルコール量のしきい値
// - alcoholPaceCooldown: 通知後のクールダウン時間
const alcoholPaceWindow = Duration(minutes: 30);
const alcoholPaceThresholdGrams = 60.0;
const alcoholPaceCooldown = Duration(minutes: 30);

// 1回の飲酒記録を表すモデル
class AlcoholIntake {
  final double pureAlcohol;
  final DateTime timestamp;

  const AlcoholIntake({required this.pureAlcohol, required this.timestamp});
}

// ミリリットルと度数から純アルコール量を計算する
// 公式: 容量 × 度数 × 0.8 / 100
double calculatePureAlcoholGrams({
  required double volume,
  required double alcoholPercentage,
}) {
  return (volume * alcoholPercentage * 0.8) / 100;
}

// 指定時間内に摂取した純アルコールの合計を計算する
double calculateAlcoholWithin({
  required Iterable<AlcoholIntake> intakes,
  required DateTime now,
  Duration window = alcoholPaceWindow,
}) {
  final cutoff = now.subtract(window);
  return intakes
      .where(
        (intake) =>
            !intake.timestamp.isBefore(cutoff) &&
            !intake.timestamp.isAfter(now),
      )
      .fold(0.0, (sum, intake) => sum + intake.pureAlcohol);
}

// 飲酒ペース通知が必要か判定する
// - 過去 window 間の純アルコール合計が thresholdGrams を超える
// - 直近の通知から cooldown 以上経過している
bool shouldNotifyAlcoholPace({
  required Iterable<AlcoholIntake> intakes,
  required DateTime now,
  DateTime? lastNotificationAt,
  Duration window = alcoholPaceWindow,
  double thresholdGrams = alcoholPaceThresholdGrams,
  Duration cooldown = alcoholPaceCooldown,
}) {
  final total = calculateAlcoholWithin(
    intakes: intakes,
    now: now,
    window: window,
  );
  if (total < thresholdGrams) return false;

  return lastNotificationAt == null ||
      now.difference(lastNotificationAt) >= cooldown;
}
