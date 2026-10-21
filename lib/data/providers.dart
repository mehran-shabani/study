import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils.dart';
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
  yield await dao.getAll();
});

/// Update today's summary at local midnight without querying SQLite.
final todayProvider = Provider<String>((ref) {
  final now = DateTime.now();
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextDay.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return AppUtils.formatDate(now);
});

/// Shared tab navigation for contextual actions (plans, study, reports).
final mainTabProvider = StateProvider<int>((ref) => 4);

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
  yield await dao.getByWorkspace(workspaceId);
});

/// Notifier for workspace operations
class WorkspaceNotifier extends StateNotifier<AsyncValue<void>> {
  WorkspaceNotifier(this.dao, {this.onChanged})
      : super(const AsyncValue.data(null));

  final WorkspaceDao dao;
  final void Function()? onChanged;

  Future<int?> createWorkspace(Workspace workspace) async {
    state = const AsyncValue.loading();
    try {
      final id = await dao.insert(workspace);
      state = const AsyncValue.data(null);
      onChanged?.call();
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
      onChanged?.call();
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
      onChanged?.call();
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
  return WorkspaceNotifier(ref.watch(workspaceDaoProvider), onChanged: () {
    ref.invalidate(workspacesProvider);
    ref.invalidate(studyEntriesProvider);
  });
});

/// Notifier for study entry operations
class StudyEntryNotifier extends StateNotifier<AsyncValue<void>> {
  StudyEntryNotifier(this.dao, {this.onChanged})
      : super(const AsyncValue.data(null));

  final StudyEntryDao dao;
  final void Function()? onChanged;

  Future<int?> createEntry(StudyEntry entry) async {
    state = const AsyncValue.loading();
    try {
      final id = await dao.insert(entry);
      state = const AsyncValue.data(null);
      onChanged?.call();
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
      onChanged?.call();
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
      onChanged?.call();
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
  return StudyEntryNotifier(ref.watch(studyEntryDaoProvider), onChanged: () {
    ref.invalidate(studyEntriesProvider);
  });
});
