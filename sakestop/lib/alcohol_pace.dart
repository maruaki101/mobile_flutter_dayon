const alcoholPaceWindow = Duration(minutes: 30);
const alcoholPaceThresholdGrams = 40.0;
const alcoholPaceCooldown = Duration(minutes: 30);

class AlcoholIntake {
  final double pureAlcohol;
  final DateTime timestamp;

  const AlcoholIntake({required this.pureAlcohol, required this.timestamp});
}

double calculatePureAlcoholGrams({
  required double volume,
  required double alcoholPercentage,
}) {
  return (volume * alcoholPercentage * 0.8) / 100;
}

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
