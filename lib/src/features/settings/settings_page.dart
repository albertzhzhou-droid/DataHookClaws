import 'package:flutter/material.dart';

import '../../domain/settings_service.dart';
import '../../domain/source_capability_registry.dart';
import '../../models/app_settings.dart';
import '../../models/storage_paths.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.sourceCapabilities,
    required this.storagePathsLoader,
  });

  final SettingsService settingsService;
  final SourceCapabilityRegistry sourceCapabilities;
  final Future<StoragePaths> Function() storagePathsLoader;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ollamaEndpointController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _maxCallsController = TextEditingController();
  final _timeoutController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _exportDirectoryController = TextEditingController();
  final _databaseBudgetController = TextEditingController();
  final _artifactBudgetController = TextEditingController();
  final _exportBudgetController = TextEditingController();
  final _cacheBudgetController = TextEditingController();

  AppSettings? _settings;
  StoragePaths? _storagePaths;
  Map<String, bool> _sourceEnabled = {};
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ollamaEndpointController.dispose();
    _ollamaModelController.dispose();
    _maxCallsController.dispose();
    _timeoutController.dispose();
    _maxTokensController.dispose();
    _exportDirectoryController.dispose();
    _databaseBudgetController.dispose();
    _artifactBudgetController.dispose();
    _exportBudgetController.dispose();
    _cacheBudgetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.settingsService.load();
    final paths = await widget.storagePathsLoader();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _storagePaths = paths;
      _sourceEnabled = Map<String, bool>.from(settings.sourceEnabled);
      _ollamaEndpointController.text = settings.ollamaEndpoint;
      _ollamaModelController.text = settings.ollamaModel;
      _maxCallsController.text = '${settings.modelMaxCallsPerMinute}';
      _timeoutController.text = '${settings.modelTimeoutSeconds}';
      _maxTokensController.text = '${settings.modelMaxTokens}';
      _exportDirectoryController.text = settings.exportDirectory;
      _databaseBudgetController.text = '${settings.databaseBudgetBytes}';
      _artifactBudgetController.text = '${settings.artifactBudgetBytes}';
      _exportBudgetController.text = '${settings.exportBudgetBytes}';
      _cacheBudgetController.text = '${settings.cacheBudgetBytes}';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final current = _settings ?? widget.settingsService.defaultSettings();
    final next = current.copyWith(
      ollamaEndpoint: _ollamaEndpointController.text.trim(),
      ollamaModel: _ollamaModelController.text.trim().isEmpty
          ? 'llama3'
          : _ollamaModelController.text.trim(),
      modelMaxCallsPerMinute: _parseInt(_maxCallsController.text, 6),
      modelTimeoutSeconds: _parseInt(_timeoutController.text, 3),
      modelMaxTokens: _parseInt(_maxTokensController.text, 256),
      exportDirectory: _exportDirectoryController.text.trim(),
      databaseBudgetBytes: _parseInt(
        _databaseBudgetController.text,
        current.databaseBudgetBytes,
      ),
      artifactBudgetBytes: _parseInt(
        _artifactBudgetController.text,
        current.artifactBudgetBytes,
      ),
      exportBudgetBytes: _parseInt(
        _exportBudgetController.text,
        current.exportBudgetBytes,
      ),
      cacheBudgetBytes: _parseInt(
        _cacheBudgetController.text,
        current.cacheBudgetBytes,
      ),
      sourceEnabled: _sourceEnabled,
    );
    await widget.settingsService.save(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = next;
      _message =
          'Settings saved. Runtime routing changes apply on next app start.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_message != null)
                  Card(
                    color: const Color(0xFFF3FBFD),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Settings status'),
                      subtitle: Text(_message!),
                    ),
                  ),
                _sectionTitle(context, 'Ollama'),
                _textField(_ollamaEndpointController, 'Ollama endpoint'),
                _textField(_ollamaModelController, 'Ollama model'),
                _textField(
                  _maxCallsController,
                  'Model max calls per minute',
                  number: true,
                ),
                _textField(
                  _timeoutController,
                  'Model timeout seconds',
                  number: true,
                ),
                _textField(
                  _maxTokensController,
                  'Model max tokens',
                  number: true,
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Storage and export'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Database path'),
                  subtitle: Text(
                    _storagePaths?.databasePath ?? '(unavailable)',
                  ),
                ),
                _textField(
                  _exportDirectoryController,
                  'Export directory (empty uses default exports/)',
                ),
                _textField(
                  _databaseBudgetController,
                  'Database budget bytes',
                  number: true,
                ),
                _textField(
                  _artifactBudgetController,
                  'Artifact budget bytes',
                  number: true,
                ),
                _textField(
                  _exportBudgetController,
                  'Export budget bytes',
                  number: true,
                ),
                _textField(
                  _cacheBudgetController,
                  'Cache budget bytes',
                  number: true,
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Sources'),
                ...widget.sourceCapabilities.all.map(_sourceTile),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save settings'),
                ),
              ],
            ),
    );
  }

  Widget _sourceTile(SourceCapability capability) {
    final blocked = capability.isBlocked;
    final enabled =
        !blocked && (_sourceEnabled[capability.importerId] ?? false);
    return SwitchListTile(
      value: enabled,
      onChanged: blocked
          ? null
          : (value) {
              setState(() {
                _sourceEnabled[capability.importerId] = value;
              });
            },
      title: Text(capability.displayName),
      subtitle: Text(
        blocked
            ? 'Blocked: ${capability.blockedReason}'
            : '${capability.country} / ${capability.supportsAutomaticFetch ? 'automatic eligible' : 'manual-only'}',
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  int _parseInt(String value, int fallback) {
    return int.tryParse(value.trim()) ?? fallback;
  }
}
