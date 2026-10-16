import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'study_timer.dart';
import 'study_timer_dao.dart';
import 'study_alarm.dart';

final studyAlarmProvider = Provider<StudyAlarm>((ref) => StudyAlarm());

final studyTimerDaoProvider = Provider<StudyTimerDao>((ref) => StudyTimerDao());
final timerClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final studyTimerProvider =
    StateNotifierProvider<StudyTimerController, StudyTimerState>((ref) {
      return StudyTimerController(
        ref.watch(studyTimerDaoProvider),
        now: ref.watch(timerClockProvider),
        alarm: ref.watch(studyAlarmProvider),
        onSaved: () => ref.invalidate(studyEntriesProvider),
      );
    });

class StudyTimerState {
  const StudyTimerState({
    this.session,
    this.busy = false,
    this.error,
    this.alarmEnabled = true,
    this.alarmError,
  });
  final StudyTimerSession? session;
  final bool busy;
  final Object? error;
  final bool alarmEnabled;
  final Object? alarmError;
}

class TimerTooShortException implements Exception {}

class StudyTimerController extends StateNotifier<StudyTimerState> {
  StudyTimerController(
    this.dao, {
    required this.now,
    this.onSaved,
    StudyAlarm? alarm,
  }) : alarm = alarm ?? StudyAlarm(),
       super(const StudyTimerState(busy: true)) {
    ready = restore();
  }

  final StudyTimerDao dao;
  final StudyAlarm alarm;
  bool _alarmEnabled = true;
  Object? _alarmError;
  Timer? _focusTicker;
  final DateTime Function() now;
  final void Function()? onSaved;
  late final Future<bool> ready;

  Future<bool> restore() async {
    if (state.session != null) return true;
    state = const StudyTimerState(busy: true);
    try {
      var session = await dao.load();
      final settled = session?.settle(now());
      if (settled != session && settled != null) {
        await dao.update(settled);
        session = settled;
      }
      try {
        _alarmEnabled = await alarm.loadEnabled();
      } catch (error) {
        _alarmError = error;
      }
      await _syncAlarm(session);
      if (mounted) state = _state(session);
      _scheduleFocus();
      return true;
    } catch (error) {
      if (mounted) state = _state(null, error: error);
      return false;
    }
  }

  Future<bool> start(
    int workspaceId,
    String workspaceName, {
    int focusMinutes = 0,
    int breakMinutes = 5,
  }) async {
    if (state.busy || state.session != null) return false;
    if (![0, 15, 25, 50].contains(focusMinutes) ||
        breakMinutes < 1 ||
        breakMinutes > 30) {
      return false;
    }
    final session = StudyTimerSession(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      startedAt: now(),
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      focusTargetMs: Duration(minutes: focusMinutes).inMilliseconds,
    );
    return _persist(session, () => dao.start(session));
  }

  Future<bool> stop() async {
    final session = state.session;
    if (state.busy || session == null) return false;
    if (session.isStopped) return true;
    final stopped = session.settle(now()).stop(now());
    if (stopped.elapsedAt(now()) < const Duration(seconds: 1)) {
      state = _state(session, error: TimerTooShortException());
      return false;
    }
    return _persist(stopped, () => dao.update(stopped), pending: stopped);
  }

  Future<bool> save(String title) async {
    final session = state.session;
    if (state.busy ||
        session == null ||
        !session.isStopped ||
        title.trim().isEmpty ||
        title.trim().length > 80) {
      return false;
    }
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
    if (state.busy || session == null || !session.isStopped) return false;
    final pending = session.withSubject(title.trim());
    return _persist(pending, () => dao.update(pending), pending: pending);
  }

  Future<bool> pause() async {
    final session = state.session;
    if (state.busy || session == null || !session.isRunning) return false;
    final paused = session.settle(now()).pause(now());
    return _persist(paused, () => dao.update(paused), pending: paused);
  }

  Future<bool> resume() async {
    final session = state.session;
    if (state.busy || session == null || !session.isPaused) return false;
    final resumed = session.resume(now());
    return _persist(resumed, () => dao.update(resumed));
  }

  Future<bool> discard() async {
    final session = state.session;
    if (state.busy || session == null) return false;
    return _persist(null, () => dao.discard(session));
  }

  Future<bool> takeBreak(int minutes) async {
    final session = state.session;
    if (state.busy ||
        session == null ||
        session.isStopped ||
        minutes < 1 ||
        minutes > 30) {
      return false;
    }
    final paused = session.settle(now()).takeBreak(now(), minutes: minutes);
    return _persist(paused, () => dao.update(paused), pending: paused);
  }

  Future<void> checkFocus() async {
    final session = state.session;
    if (state.busy || session == null) return;
    final settled = session.settle(now());
    if (settled != session) {
      await _persist(settled, () => dao.update(settled), pending: settled);
    }
  }

  void _scheduleFocus() {
    _focusTicker?.cancel();
    _focusTicker = null;
    if (mounted && state.session?.focusDeadline != null) {
      _focusTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => checkFocus(),
      );
    }
  }

  @override
  void dispose() {
    _focusTicker?.cancel();
    super.dispose();
  }

  Future<bool> _persist(
    StudyTimerSession? result,
    Future<void> Function() write, {
    StudyTimerSession? pending,
  }) async {
    final previous = pending ?? state.session;
    state = _state(previous, busy: true);
    try {
      await write();
      await _syncAlarm(result);
      if (mounted) state = _state(result);
      _scheduleFocus();
      return true;
    } catch (error) {
      await _syncAlarm(previous);
      if (mounted) state = _state(previous, error: error);
      _scheduleFocus();
      return false;
    }
  }

  StudyTimerState _state(
    StudyTimerSession? session, {
    bool busy = false,
    Object? error,
  }) => StudyTimerState(
    session: session,
    busy: busy,
    error: error,
    alarmEnabled: _alarmEnabled,
    alarmError: _alarmError,
  );

  Future<void> _syncAlarm(StudyTimerSession? session) async {
    try {
      await alarm.sync(session, now(), enabled: _alarmEnabled);
      _alarmError = null;
    } catch (error) {
      // An Android audio/service failure must never undo a database write.
      _alarmError = error;
    }
  }

  Future<void> setAlarmEnabled(bool enabled) async {
    if (state.busy) return;
    _alarmEnabled = enabled;
    state = _state(state.session, busy: true);
    await _syncAlarm(state.session);
    if (mounted) state = _state(state.session);
  }

  Future<void> previewAlarm() async {
    try {
      await alarm.preview();
      _alarmError = null;
    } catch (error) {
      _alarmError = error;
    }
    if (mounted) state = _state(state.session);
  }
}
