import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'workspace_dao.dart';
import 'study_entry_dao.dart';

/// Provider for WorkspaceDao
final workspaceDaoProvider = Provider<WorkspaceDao>((ref) {
  return WorkspaceDao();
});

/// Provider for StudyEntryDao
final studyEntryDaoProvider = Provider<StudyEntryDao>((ref) {
  return StudyEntryDao();
});

/// Provider for all workspaces
final workspacesProvider = StreamProvider<List<Workspace>>((ref) async* {
  final dao = ref.watch(workspaceDaoProvider);
  // Initial load
  yield await dao.getAll();
  
  // Since sqflite doesn't provide streams, we'll use a simple polling mechanism
  // In a real app, you might use a more sophisticated approach
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    yield await dao.getAll();
  }
});

/// Provider for currently selected workspace ID
final selectedWorkspaceIdProvider = StateProvider<int?>((ref) => null);

/// Provider for selected workspace details
final selectedWorkspaceProvider = Provider<Workspace?>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  if (workspaceId == null) return null;
  
  final workspacesAsync = ref.watch(workspacesProvider);
  return workspacesAsync.whenData((workspaces) {
    try {
      return workspaces.firstWhere((w) => w.id == workspaceId);
    } catch (e) {
      return null;
    }
  }).value;
});

/// Provider for study entries of selected workspace
final studyEntriesProvider = StreamProvider<List<StudyEntry>>((ref) async* {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  if (workspaceId == null) {
    yield [];
    return;
  }

  final dao = ref.watch(studyEntryDaoProvider);
  // Initial load
  yield await dao.getByWorkspace(workspaceId);
  
  // Polling for updates
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    yield await dao.getByWorkspace(workspaceId);
  }
});

/// Notifier for workspace operations
class WorkspaceNotifier extends StateNotifier<AsyncValue<void>> {
  WorkspaceNotifier(this.dao) : super(const AsyncValue.data(null));

  final WorkspaceDao dao;

  Future<int?> createWorkspace(Workspace workspace) async {
    state = const AsyncValue.loading();
    try {
      final id = await dao.insert(workspace);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> updateWorkspace(Workspace workspace) async {
    state = const AsyncValue.loading();
    try {
      await dao.update(workspace);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteWorkspace(int id) async {
    state = const AsyncValue.loading();
    try {
      await dao.delete(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for workspace operations
final workspaceNotifierProvider =
    StateNotifierProvider<WorkspaceNotifier, AsyncValue<void>>((ref) {
  return WorkspaceNotifier(ref.watch(workspaceDaoProvider));
});

/// Notifier for study entry operations
class StudyEntryNotifier extends StateNotifier<AsyncValue<void>> {
  StudyEntryNotifier(this.dao) : super(const AsyncValue.data(null));

  final StudyEntryDao dao;

  Future<int?> createEntry(StudyEntry entry) async {
    state = const AsyncValue.loading();
    try {
      final id = await dao.insert(entry);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> updateEntry(StudyEntry entry) async {
    state = const AsyncValue.loading();
    try {
      await dao.update(entry);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteEntry(int id) async {
    state = const AsyncValue.loading();
    try {
      await dao.delete(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for study entry operations
final studyEntryNotifierProvider =
    StateNotifierProvider<StudyEntryNotifier, AsyncValue<void>>((ref) {
  return StudyEntryNotifier(ref.watch(studyEntryDaoProvider));
});
