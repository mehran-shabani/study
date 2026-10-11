import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'study_timer.dart';
import 'study_timer_dao.dart';

final studyTimerDaoProvider = Provider<StudyTimerDao>((ref) => StudyTimerDao());
final timerClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final studyTimerProvider =
    StateNotifierProvider<StudyTimerController, StudyTimerState>((ref) {
  return StudyTimerController(
    ref.watch(studyTimerDaoProvider),
    now: ref.watch(timerClockProvider),
    onSaved: () => ref.invalidate(studyEntriesProvider),
  );
});

class StudyTimerState {
  const StudyTimerState({this.session, this.busy = false, this.error});
  final StudyTimerSession? session;
  final bool busy;
  final Object? error;
}

class TimerTooShortException implements Exception {}

class StudyTimerController extends StateNotifier<StudyTimerState> {
  StudyTimerController(this.dao, {required this.now, this.onSaved})
      : super(const StudyTimerState(busy: true)) {
    ready = restore();
  }

  final StudyTimerDao dao;
  final DateTime Function() now;
  final void Function()? onSaved;
  late final Future<bool> ready;

  Future<bool> restore() async {
    if (state.session != null) return true;
    state = const StudyTimerState(busy: true);
    try {
      final session = await dao.load();
      if (mounted) state = StudyTimerState(session: session);
      return true;
    } catch (error) {
      if (mounted) state = StudyTimerState(error: error);
      return false;
    }
  }

  Future<bool> start(int workspaceId, String workspaceName) async {
    if (state.busy || state.session != null) return false;
    final session = StudyTimerSession(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        startedAt: now());
    return _persist(session, () => dao.start(session));
  }

  Future<bool> stop() async {
    final session = state.session;
    if (state.busy || session == null) return false;
    if (!session.isRunning) return true;
    final stopped = session.stop(now());
    if (stopped.elapsedAt(now()) < const Duration(seconds: 1)) {
      state =
          StudyTimerState(session: session, error: TimerTooShortException());
      return false;
    }
    return _persist(stopped, () => dao.update(stopped), pending: stopped);
  }

  Future<bool> save(String title) async {
    final session = state.session;
    if (state.busy ||
        session == null ||
        session.isRunning ||
        title.trim().isEmpty ||
        title.trim().length > 80) return false;
    final pending = session.withSubject(title.trim());
    return _persist(null, () async {
      // Persist the subject as well so a failed save can be retried after restart.
      await dao.update(pending);
      await dao.finish(pending, title);
      onSaved?.call();
    }, pending: pending);
  }

  Future<bool> rememberSubject(String title) async {
    final session = state.session;
    if (state.busy || session == null || session.isRunning) return false;
    final pending = session.withSubject(title.trim());
    return _persist(pending, () => dao.update(pending), pending: pending);
  }

  Future<bool> _persist(
      StudyTimerSession? result, Future<void> Function() write,
      {StudyTimerSession? pending}) async {
    final previous = pending ?? state.session;
    state = StudyTimerState(session: previous, busy: true);
    try {
      await write();
      if (mounted) state = StudyTimerState(session: result);
      return true;
    } catch (error) {
      if (mounted) state = StudyTimerState(session: previous, error: error);
      return false;
    }
  }
}
