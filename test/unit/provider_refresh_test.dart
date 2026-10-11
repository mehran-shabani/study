import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_entry_dao.dart';

class MemoryEntryDao extends StudyEntryDao {
  final entries = <StudyEntry>[];

  @override
  Future<List<StudyEntry>> getByWorkspace(int id) async =>
      entries.where((entry) => entry.workspaceId == id).toList();

  @override
  Future<int> insert(StudyEntry entry) async {
    entries.add(entry.copyWith(id: entries.length + 1));
    return entries.length;
  }

  @override
  Future<int> delete(int id) async {
    entries.removeWhere((entry) => entry.id == id);
    return 1;
  }
}

void main() {
  test('study data immediately refreshes after save and delete without polling',
      () async {
    final dao = MemoryEntryDao();
    final container = ProviderContainer(
        overrides: [studyEntryDaoProvider.overrideWithValue(dao)]);
    addTearDown(container.dispose);
    container.read(selectedWorkspaceIdProvider.notifier).state = 1;
    expect(await container.read(studyEntriesProvider.future), isEmpty);
    final notifier = container.read(studyEntryNotifierProvider.notifier);
    final id = await notifier.createEntry(const StudyEntry(
        workspaceId: 1, entryDate: '2026-10-11', title: 'قلب', hours: 0.5));
    expect(
        (await container.read(studyEntriesProvider.future)).single.hours, 0.5);
    await notifier.deleteEntry(id!);
    expect(await container.read(studyEntriesProvider.future), isEmpty);
  });
}
