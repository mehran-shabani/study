import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

Future<DateTime?> selectJalaliDate(
  BuildContext context, {
  required DateTime initialDate,
}) async {
  final initial = Jalali.fromDateTime(initialDate);
  final locale = Localizations.localeOf(context).languageCode == 'fa'
      ? const Locale('fa', 'IR')
      : const Locale('en', 'US');
  final picked = await showPersianDatePicker(
    context: context,
    initialDate: initial,
    firstDate: Jalali(initial.year < 1300 ? initial.year : 1300),
    lastDate: Jalali(initial.year > 1500 ? initial.year : 1500, 12, 29),
    builder: (context, child) => Localizations.override(
      context: context,
      locale: locale,
      delegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
        DefaultPersianMaterialLocalizations.delegate,
        DefaultPersianCupertinoLocalizations.delegate,
      ],
      child: child!,
    ),
  );
  return picked?.toDateTime();
}
