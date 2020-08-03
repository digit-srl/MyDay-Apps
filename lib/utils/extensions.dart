extension ExtensionDateTime on DateTime {
  bool isSameDay(DateTime date) {
    return this.day == date.day &&
        this.month == date.month &&
        this.year == date.year;
  }

  DateTime get midnight => this.isUtc
      ? DateTime.utc(this.year, this.month, this.day)
      : DateTime(this.year, this.month, this.day);

  bool get isToday => this.isSameDay(DateTime.now());

  DateTime copyWith(
      {int day, int month, int year, int hour, int minute, int second}) {
    return DateTime(year ?? this.year, month ?? this.month, day ?? this.day,
        hour ?? this.hour, minute ?? this.minute, second ?? this.second);
  }

  int toMinutes() => this.hour * 60 + this.minute;
  DateTime get yesterday => this.subtract(Duration(days: 1));
}
