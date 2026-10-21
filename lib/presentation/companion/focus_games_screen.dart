import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../domain/focus_games.dart';
import 'companion_catalog.dart';

export '../../domain/focus_games.dart' show FocusGameKind;

/// Bounded practice. The clock stops whenever the app leaves the foreground.
class FocusGamesScreen extends StatefulWidget {
  const FocusGamesScreen({
    super.key,
    this.initialGame,
    this.studyPaused = false,
    this.clock,
  });
  final FocusGameKind? initialGame;
  final bool studyPaused;
  final Stopwatch? clock;
  @override
  State<FocusGamesScreen> createState() => _FocusGamesScreenState();
}

class _FocusGamesScreenState extends State<FocusGamesScreen>
    with WidgetsBindingObserver {
  final _random = Random();
  late final Stopwatch _clock;
  Timer? _ticker;
  FocusGameKind? _kind;
  bool _started = false;
  bool _done = false;
  bool _paused = false;
  bool _foreground = true;
  late NumberTrail _numbers;
  late PatternMemory _pattern;
  int _round = 0;
  int _correct = 0;
  int _mistakes = 0;
  int _phaseAt = 0;
  bool _circle = true;
  bool _answered = false;
  bool _revealing = true;
  int? _feedbackAt;

  @override
  void initState() {
    super.initState();
    _clock = widget.clock ?? Stopwatch();
    _kind = widget.initialGame;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _started && !_done) _pause();
    if (mounted) setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _clock.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_foreground) return;
    setState(() => _paused = false);
    _clock.start();
    _schedule();
  }

  void _schedule() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _start() {
    _ticker?.cancel();
    _clock.reset();
    _clock.start();
    setState(() {
      _started = true;
      _done = false;
      _paused = false;
      _round = 0;
      _correct = 0;
      _mistakes = 0;
      _phaseAt = 0;
      _circle = true;
      _answered = false;
      _revealing = true;
      _feedbackAt = null;
      _numbers = NumberTrail(_random);
      _pattern = PatternMemory(_random, 3);
    });
    _schedule();
  }

  void _finish() {
    _ticker?.cancel();
    _clock.stop();
    _done = true;
  }

  void _tick() {
    if (!mounted || _paused || _done) return;
    final ms = _clock.elapsedMilliseconds;
    setState(() {
      switch (_kind!) {
        case FocusGameKind.numbers:
          if (ms >= 60000) _finish();
        case FocusGameKind.response:
          if (ms - _phaseAt >= 1200) {
            if (!_answered) {
              if (_circle) {
                _mistakes++;
              } else {
                _correct++;
              }
            }
            _round++;
            if (_round >= 20) {
              _finish();
            } else {
              _circle = _random.nextBool();
              _answered = false;
              _phaseAt = ms;
            }
          }
        case FocusGameKind.memory:
          if (_revealing && ms - _phaseAt >= 1800) _revealing = false;
          if (_feedbackAt != null && ms - _feedbackAt! >= 700) {
            _correct += _pattern.correct;
            _mistakes += _pattern.mistakes;
            _round++;
            if (_round >= 3) {
              _finish();
            } else {
              _pattern = PatternMemory(_random, 3 + _round);
              _revealing = true;
              _phaseAt = ms;
              _feedbackAt = null;
            }
          }
          // A practice never becomes an open-ended distraction.
          if (!_done && ms >= 60000) {
            _correct += _pattern.correct;
            _mistakes += _pattern.mistakes;
            _finish();
          }
      }
    });
  }

  String _title(AppLocalizations l, FocusGameKind kind) => switch (kind) {
    FocusGameKind.numbers => l.companionSchulte,
    FocusGameKind.response => l.companionGo,
    FocusGameKind.memory => l.companionMemory,
  };
  String _hint(AppLocalizations l, FocusGameKind kind) => switch (kind) {
    FocusGameKind.numbers => l.companionSchulteHint,
    FocusGameKind.response => l.companionGoHint,
    FocusGameKind.memory => l.companionMemoryHint,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_kind == null ? l.companionWarmup : _title(l, _kind!)),
        actions: [
          if (_started && !_done && !_paused)
            IconButton(
              tooltip: l.pauseTimer,
              onPressed: _pause,
              icon: const Icon(Icons.pause_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.studyPaused) ...[
                    Text(
                      l.companionStudyPaused,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_kind == null) ...[
                    Text(l.companionGamesHint),
                    const SizedBox(height: 24),
                    for (final kind in FocusGameKind.values)
                      Card(
                        child: ListTile(
                          leading: Icon(switch (kind) {
                            FocusGameKind.numbers => Icons.grid_view_rounded,
                            FocusGameKind.response => Icons.touch_app_outlined,
                            FocusGameKind.memory => Icons.pattern_outlined,
                          }),
                          title: Text(_title(l, kind)),
                          subtitle: Text(_hint(l, kind)),
                          onTap: () => setState(() => _kind = kind),
                        ),
                      ),
                  ] else if (!_started) ...[
                    Icon(
                      switch (_kind!) {
                        FocusGameKind.numbers => Icons.grid_view_rounded,
                        FocusGameKind.response => Icons.touch_app_outlined,
                        FocusGameKind.memory => Icons.pattern_outlined,
                      },
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(_hint(l, _kind!), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text(l.companionGamesHint),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('focus-game-start'),
                      onPressed: _start,
                      child: Text(l.companionGameStart),
                    ),
                  ] else if (_done) ...[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l.companionGameDone,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _stat(
                      l.companionGameScore,
                      _kind == FocusGameKind.numbers
                          ? _numbers.next - 1
                          : _correct,
                    ),
                    _stat(
                      l.companionGameMistakes,
                      _kind == FocusGameKind.numbers
                          ? _numbers.mistakes
                          : _mistakes,
                    ),
                    _stat(
                      l.companionGameSeconds,
                      (_clock.elapsedMilliseconds / 1000).round(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.companionGameBack),
                    ),
                    TextButton(
                      onPressed: _start,
                      child: Text(l.companionGameAgain),
                    ),
                  ] else if (_paused) ...[
                    const Icon(Icons.pause_circle_outline, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      l.companionGamePaused,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _foreground ? _resume : null,
                      child: Text(l.companionGameResume),
                    ),
                  ] else ...[
                    Text(_hint(l, _kind!), style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: switch (_kind!) {
                        FocusGameKind.numbers => (_numbers.next - 1) / 16,
                        FocusGameKind.response => _round / 20,
                        FocusGameKind.memory => _round / 3,
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_kind == FocusGameKind.numbers) ...[
                      Text(
                        '${l.companionGameNext}: ${companionNumber(context, _numbers.next)}',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _grid(4, 16, (i) {
                        final number = _numbers.board[i];
                        return OutlinedButton(
                          key: ValueKey('number-$number'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: number < _numbers.next
                              ? null
                              : () => setState(() {
                                  _numbers.tap(number);
                                  if (_numbers.complete) _finish();
                                }),
                          child: Text(
                            companionNumber(context, number),
                            style: theme.textTheme.titleLarge,
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      _stat(l.companionGameMistakes, _numbers.mistakes),
                    ],
                    if (_kind == FocusGameKind.response) ...[
                      Text(
                        '${companionNumber(context, _round + 1)} / ${companionNumber(context, 20)}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: FilledButton(
                          key: const ValueKey('response-target'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _circle
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.secondaryContainer,
                            foregroundColor: _circle
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                          onPressed: _answered
                              ? null
                              : () => setState(() {
                                  _answered = true;
                                  if (_circle) {
                                    _correct++;
                                  } else {
                                    _mistakes++;
                                  }
                                }),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _circle
                                    ? Icons.circle_outlined
                                    : Icons.change_history_rounded,
                                size: 80,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _circle
                                    ? l.companionGameTap
                                    : l.companionGameWait,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_kind == FocusGameKind.memory) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _revealing
                              ? l.companionGameWatch
                              : l.companionGameFind,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _grid(3, 9, (i) {
                        final show = _revealing && _pattern.targets.contains(i);
                        final guessed = _pattern.guesses.contains(i);
                        final correct = guessed && _pattern.targets.contains(i);
                        return Semantics(
                          label: companionNumber(context, i + 1),
                          selected: show || guessed,
                          child: OutlinedButton(
                            key: ValueKey('pattern-$i'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: show || correct
                                  ? theme.colorScheme.primaryContainer
                                  : null,
                            ),
                            onPressed:
                                _revealing || guessed || _feedbackAt != null
                                ? null
                                : () => setState(() {
                                    _pattern.tap(i);
                                    if (_pattern.complete) {
                                      _feedbackAt = _clock.elapsedMilliseconds;
                                    }
                                  }),
                            child: show || correct
                                ? const Icon(Icons.circle, size: 24)
                                : guessed
                                ? const Icon(Icons.close)
                                : Text(companionNumber(context, i + 1)),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, num value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(companionNumber(context, value)),
      ],
    ),
  );
  Widget _grid(int columns, int count, Widget Function(int) builder) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).height - 400).clamp(224.0, 432.0),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (_, i) => builder(i),
      ),
    ),
  );
}
