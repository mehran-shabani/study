import 'dart:math';

enum FocusGameKind { numbers, response, memory }

class NumberTrail {
  NumberTrail(Random random) : board = List.generate(16, (i) => i + 1)..shuffle(random);
  final List<int> board;
  int next = 1;
  int mistakes = 0;
  bool get complete => next > 16;
  bool tap(int number) {
    if (complete || number < next) return false;
    if (number == next) { next++; return true; }
    mistakes++;
    return false;
  }
}

class PatternMemory {
  PatternMemory(Random random, int count)
    : targets = (List.generate(9, (i) => i)..shuffle(random)).take(count).toSet();
  final Set<int> targets;
  final Set<int> guesses = {};
  int get correct => guesses.intersection(targets).length;
  int get mistakes => guesses.difference(targets).length;
  bool get complete => guesses.length == targets.length;
  void tap(int index) {
    if (!complete && index >= 0 && index < 9) guesses.add(index);
  }
}
