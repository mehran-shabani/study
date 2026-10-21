import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/study_companion.dart';

Map<String, String> medicalCatalog(AppLocalizations l) => {
  'anatomy': l.courseAnatomy,
  'physiology': l.coursePhysiology,
  'biochemistry': l.courseBiochemistry,
  'histology': l.courseHistology,
  'embryology': l.courseEmbryology,
  'microbiology': l.courseMicrobiology,
  'immunology': l.courseImmunology,
  'pathology': l.coursePathology,
  'pharmacology': l.coursePharmacology,
  'internal': l.courseInternal,
  'surgery': l.courseSurgery,
  'pediatrics': l.coursePediatrics,
  'obgyn': l.courseObgyn,
  'psychiatry': l.coursePsychiatry,
  'neurology': l.courseNeurology,
  'publicHealth': l.coursePublicHealth,
};
String courseLabel(MedicalCourse course, AppLocalizations l) =>
    medicalCatalog(l)[course.id] ?? course.name;
String methodLabel(String method, AppLocalizations l) => switch (method) {
  'recall' => l.companionRecall,
  'questions' => l.companionQuestions,
  'case' => l.companionCase,
  _ => l.companionRead,
};
String methodPrompt(String method, AppLocalizations l) => switch (method) {
  'recall' => l.companionRecallPrompt,
  'questions' => l.companionQuestionsPrompt,
  'case' => l.companionCasePrompt,
  _ => l.companionReadPrompt,
};
IconData methodIcon(String method) => switch (method) {
  'recall' => Icons.psychology_outlined,
  'questions' => Icons.quiz_outlined,
  'case' => Icons.medical_information_outlined,
  _ => Icons.menu_book_outlined,
};
int energyMinutes(int energy) => switch (energy) {
  1 => 15,
  3 => 50,
  _ => 25,
};
String companionNumber(BuildContext context, num value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(value);
