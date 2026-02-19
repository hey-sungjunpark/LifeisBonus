class AgeGateService {
  AgeGateService._();

  static const int minAllowedAge = 14;

  static DateTime? parseBirthDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int calculateAge(DateTime birthDate, DateTime today) {
    int age = today.year - birthDate.year;
    final hasBirthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasBirthdayPassed) {
      age -= 1;
    }
    return age;
  }

  static bool isAllowed(DateTime birthDate, {DateTime? today}) {
    final now = today ?? DateTime.now();
    return calculateAge(birthDate, now) >= minAllowedAge;
  }
}
