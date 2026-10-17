import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/app_settings.dart';
import '../../data/study_timer_provider.dart';
import '../common/backup_actions.dart';
import '../common/study_sound_controls.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<AppSettingsState>(appSettingsProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          !next.loadFailed) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.settingsSaveFailed)));
      }
    });
    final state = ref.watch(appSettingsProvider);
    final settings = state.value;
    final controller = ref.read(appSettingsProvider.notifier);
    final timer = ref.watch(studyTimerProvider);
    final enabled = !state.busy && !state.loadFailed;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('settings-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.busy) const LinearProgressIndicator(),
                    if (state.error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                state.loadFailed
                                    ? l10n.settingsLoadFailed
                                    : l10n.settingsSaveFailed,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              if (state.loadFailed)
                                TextButton.icon(
                                  onPressed: state.busy
                                      ? null
                                      : controller.reload,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.retry),
                                ),
                            ],
                          ),
                        ),
                      ),
                    _Section(
                      title: l10n.settingsAppearance,
                      icon: Icons.palette_outlined,
                      children: [
                        _Choice<String>(
                          id: 'settings-language',
                          label: l10n.settingsLanguage,
                          value: settings.language,
                          options: {
                            'system': l10n.settingsSystem,
                            'fa': 'فارسی',
                            'en': 'English',
                          },
                          onChanged: enabled
                              ? (value) => controller.update(
                                  settings.copyWith(language: value),
                                )
                              : null,
                        ),
                        _Choice<String>(
                          id: 'settings-theme',
                          label: l10n.settingsTheme,
                          value: settings.theme,
                          options: {
                            'system': l10n.settingsSystem,
                            'light': l10n.settingsLight,
                            'dark': l10n.settingsDark,
                          },
                          onChanged: enabled
                              ? (value) => controller.update(
                                  settings.copyWith(theme: value),
                                )
                              : null,
                        ),
                        _Choice<double>(
                          id: 'settings-text-size',
                          label: l10n.settingsTextSize,
                          value: settings.textScale,
                          options: {
                            1: l10n.settingsTextNormal,
                            1.15: l10n.settingsTextLarge,
                            1.3: l10n.settingsTextLargest,
                          },
                          onChanged: enabled
                              ? (value) => controller.update(
                                  settings.copyWith(textScale: value),
                                )
                              : null,
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.settingsStudy,
                      icon: Icons.school_outlined,
                      children: [
                        _Choice<int>(
                          id: 'settings-focus',
                          label: l10n.settingsDefaultFocus,
                          value: settings.focusMinutes,
                          options: {
                            0: l10n.focusFree,
                            15: l10n.focusGentle,
                            25: l10n.focusStandard,
                            50: l10n.focusDeep,
                          },
                          onChanged: enabled
                              ? (value) => controller.update(
                                  settings.copyWith(focusMinutes: value),
                                )
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.settingsDefaultTarget),
                          subtitle: Text(
                            l10n.hoursValue(
                              AppUtils.formatHourValue(
                                settings.dailyTargetHours,
                                locale: l10n.localeName,
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: enabled ? () => _target(context, ref) : null,
                        ),
                        Text(
                          l10n.settingsDefaultsHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          key: const ValueKey('settings-awareness'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.awarenessAlarm),
                          subtitle: Text(l10n.awarenessDescription),
                          value: timer.alarmEnabled,
                          onChanged: timer.busy
                              ? null
                              : ref
                                    .read(studyTimerProvider.notifier)
                                    .setAlarmEnabled,
                        ),
                        TextButton.icon(
                          onPressed: timer.busy
                              ? null
                              : ref
                                    .read(studyTimerProvider.notifier)
                                    .previewAlarm,
                          icon: const Icon(Icons.volume_up_outlined),
                          label: Text(l10n.testAwarenessSound),
                        ),
                        if (timer.alarmError != null)
                          Text(
                            l10n.awarenessFailed,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                    _Section(
                      title: l10n.focusSound,
                      icon: Icons.headphones_outlined,
                      children: const [StudySoundControls()],
                    ),
                    _Section(
                      title: l10n.backupMenu,
                      icon: Icons.backup_outlined,
                      children: [
                        Text(l10n.settingsBackupHint),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.backupMenu),
                          trailing: const BackupActions(),
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.settingsAbout,
                      icon: Icons.info_outline,
                      children: [
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.settingsOfflineHint),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: const ValueKey('settings-reset'),
                          onPressed: enabled
                              ? () => _reset(context, ref)
                              : null,
                          icon: const Icon(Icons.restore),
                          label: Text(l10n.settingsReset),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _target(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _DailyTargetDialog(
        initial: ref.read(appSettingsProvider).value.dailyTargetHours,
      ),
    );
    if (context.mounted && value != null) {
      await ref
          .read(appSettingsProvider.notifier)
          .update(
            ref
                .read(appSettingsProvider)
                .value
                .copyWith(dailyTargetHours: value),
          );
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l10n.settingsReset),
        content: Text(l10n.settingsResetHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsReset),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(appSettingsProvider.notifier).update(const AppSettings());
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String id;
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: onChanged != null),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: ValueKey(id),
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final entry in options.entries)
              DropdownMenuItem<T>(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null) onChanged!(value);
                },
        ),
      ),
    ),
  );
}

class _DailyTargetDialog extends StatefulWidget {
  const _DailyTargetDialog({required this.initial});
  final double initial;
  @override
  State<_DailyTargetDialog> createState() => _DailyTargetDialogState();
}

class _DailyTargetDialogState extends State<_DailyTargetDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _input;
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: AppUtils.formatHourValue(widget.initial),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.settingsDefaultTarget),
      content: Form(
        key: _form,
        child: TextFormField(
          key: const ValueKey('settings-target-input'),
          controller: _input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.dailyTargetHours,
            helperText: l10n.targetRange,
          ),
          validator: (value) =>
              AppUtils.validateHours(value) == null ? null : l10n.targetRange,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                double.parse(AppUtils.normalizeNumber(_input.text)),
              );
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
