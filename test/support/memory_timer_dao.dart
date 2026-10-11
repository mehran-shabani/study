import 'package:study/data/models.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_dao.dart';

class MemoryTimerDao extends StudyTimerDao {
  StudyTimerSession? session;
  final entries = <StudyEntry>[];
  int finishes = 0;
  bool failFinish = false;
  bool failUpdate = false;
  bool failDiscard = false;

  @override
  Future<void> discard(StudyTimerSession value) async {
    if (failDiscard) throw StateError('Storage unavailable.');
    session = null;
  }

  @override
  Future<StudyTimerSession?> load() async => session;

  @override
  Future<void> start(StudyTimerSession value) async {
    if (session != null) throw StateError('A timer already exists.');
    session = value;
  }

  @override
  Future<void> update(StudyTimerSession value) async {
    if (failUpdate) throw StateError('Storage unavailable.');
    session = value;
  }

  @override
  Future<void> finish(StudyTimerSession value, String title) async {
    finishes++;
    if (failFinish) throw StateError('Storage unavailable.');
    entries.addAll(value.entriesFor(title));
    session = null;
  }
}
