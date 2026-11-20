import 'package:flutter/material.dart';

/// The app displays HH:mm everywhere, independently of Android's clock setting.
Future<TimeOfDay?> pickAppTime(
  BuildContext context,
  TimeOfDay initial, {
  TimePickerEntryMode entryMode = TimePickerEntryMode.dial,
}) => showTimePicker(
  context: context,
  initialTime: initial,
  initialEntryMode: entryMode,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
);
