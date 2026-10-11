import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

Future<DateTime?> selectJalaliDate(
  BuildContext context, {
  required DateTime initialDate,
}) async {
  final initial = Jalali.fromDateTime(initialDate);
  final picked = await showPersianDatePicker(
    context: context,
    initialDate: initial,
    firstDate: Jalali(initial.year < 1300 ? initial.year : 1300),
    lastDate: Jalali(initial.year > 1500 ? initial.year : 1500, 12, 29),
  );
  return picked?.toDateTime();
}
