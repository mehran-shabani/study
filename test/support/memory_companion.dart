import 'package:study/data/study_companion.dart';

class MemoryCompanionRepository extends CompanionRepository {
  final values = <int, CompanionPlan>{};
  bool fail = false;
  @override
  Future<CompanionPlan> load(int workspaceId) async {
    if (fail) throw StateError('Unavailable');
    return values[workspaceId] ?? const CompanionPlan();
  }

  @override
  Future<void> save(int workspaceId, CompanionPlan plan) async {
    if (fail) throw StateError('Storage full');
    values[workspaceId] = plan;
  }
}
