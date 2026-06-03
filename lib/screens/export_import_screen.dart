import 'package:flutter/material.dart';

import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_repository.dart';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({
    super.key,
    required this.repository,
    required this.appLockService,
  });

  final CardRepository repository;
  final AppLockService appLockService;

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  final _backupFileService = BackupFileService();
  final _backupCryptoService = BackupCryptoService();
  BackupFileInfo? _latestBackup;
  String _message = '';
  bool _exporting = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export and import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device backup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Card Box keeps data local. Create a real backup file that includes card data and saved photos. Backups are saved to Downloads when the device exposes that folder, otherwise to the app backup folder. Use encrypted backup when you want password protection for the exported file.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: Text(
                          _exporting
                              ? 'Creating backup...'
                              : 'Create standard backup',
                        ),
                        onPressed: _exporting ? null : _exportPlainBackup,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: Text(
                          _exporting
                              ? 'Creating encrypted backup...'
                              : 'Create encrypted backup',
                        ),
                        onPressed: _exporting ? null : _exportEncryptedBackup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_latestBackup != null) ...[
            const SizedBox(height: 12),
            _BackupSummaryCard(backup: _latestBackup!),
          ],
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import backup file',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a Card Box backup file from the native file picker. Matching card IDs are updated; missing ones are added.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      _importing ? 'Opening picker...' : 'Choose backup file',
                    ),
                    onPressed: _importing ? null : _importBackup,
                  ),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    await _exportBackupFile(
      mode: _BackupExportMode.plain,
      rawJsonLoader: widget.repository.exportPlainJson,
      fileNamePrefix: 'card_box_backup',
    );
  }

  Future<void> _exportPlainBackup() => _exportBackup();

  Future<void> _exportEncryptedBackup() async {
    final password = await _promptForPassword(
      title: 'Create encrypted backup',
      actionLabel: 'Encrypt backup',
      confirmPassword: true,
      helperText:
          'Use at least 8 characters. You will need this password to import the file later.',
    );
    if (password == null) {
      return;
    }
    await _exportBackupFile(
      mode: _BackupExportMode.encrypted,
      rawJsonLoader: () async {
        final plainJson = await widget.repository.exportPlainJson();
        return _backupCryptoService.encryptJson(
          rawJson: plainJson,
          password: password,
        );
      },
      fileNamePrefix: 'card_box_backup_encrypted',
    );
  }

  Future<void> _exportBackupFile({
    required _BackupExportMode mode,
    required Future<String> Function() rawJsonLoader,
    required String fileNamePrefix,
  }) async {
    try {
      setState(() {
        _exporting = true;
        _message = '';
      });
      widget.appLockService.beginTrustedExternalFlow();
      final backup = await _backupFileService.createBackupFile(
        rawJson: await rawJsonLoader(),
        cardCount: widget.repository.cards.length,
        fileNamePrefix: fileNamePrefix,
      );
      if (backup == null) {
        setState(() => _message = 'Backup export canceled.');
        return;
      }
      setState(() {
        _latestBackup = backup;
        _message =
            '${mode == _BackupExportMode.encrypted ? 'Encrypted' : 'Standard'} backup file created: ${backup.fileName}';
      });
    } on UnsupportedError catch (error) {
      setState(() => _message = error.message ?? 'Backup export unavailable.');
    } catch (error) {
      setState(() => _message = 'Backup export failed: $error');
    } finally {
      widget.appLockService.endTrustedExternalFlow();
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      setState(() {
        _importing = true;
        _message = '';
      });
      widget.appLockService.beginTrustedExternalFlow();
      final imported = await _backupFileService.pickBackupFile();
      if (imported == null) {
        setState(() => _message = 'Import canceled.');
        return;
      }
      var rawJson = imported.rawJson;
      var label = imported.fileName;
      if (_backupCryptoService.looksEncrypted(rawJson)) {
        final password = await _promptForPassword(
          title: 'Unlock encrypted backup',
          actionLabel: 'Decrypt backup',
          confirmPassword: false,
          helperText:
              'Enter the password that was used when the encrypted backup file was created.',
        );
        if (password == null) {
          setState(() => _message = 'Encrypted import canceled.');
          return;
        }
        rawJson = await _backupCryptoService.decryptJson(
          encryptedJson: rawJson,
          password: password,
        );
        label = '$label (encrypted)';
      }
      final count = await widget.repository.importPlainJson(rawJson);
      setState(() => _message = 'Imported $count card(s) from $label.');
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    } on UnsupportedError catch (error) {
      setState(() => _message = error.message ?? 'Import unavailable.');
    } catch (error) {
      setState(() => _message = 'Import failed: $error');
    } finally {
      widget.appLockService.endTrustedExternalFlow();
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<String?> _promptForPassword({
    required String title,
    required String actionLabel,
    required bool confirmPassword,
    required String helperText,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _PasswordPromptSheet(
          title: title,
          actionLabel: actionLabel,
          confirmPassword: confirmPassword,
          helperText: helperText,
        ),
      ),
    );
  }
}

enum _BackupExportMode { plain, encrypted }

class _PasswordPromptSheet extends StatefulWidget {
  const _PasswordPromptSheet({
    required this.title,
    required this.actionLabel,
    required this.confirmPassword,
    required this.helperText,
  });

  final String title;
  final String actionLabel;
  final bool confirmPassword;
  final String helperText;

  @override
  State<_PasswordPromptSheet> createState() => _PasswordPromptSheetState();
}

class _PasswordPromptSheetState extends State<_PasswordPromptSheet> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(widget.helperText),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Backup password',
                      ),
                      obscureText: true,
                      textInputAction: widget.confirmPassword
                          ? TextInputAction.next
                          : TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    if (widget.confirmPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(context).pop(_passwordController.text.trim());
                  },
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupSummaryCard extends StatelessWidget {
  const _BackupSummaryCard({required this.backup});

  final BackupFileInfo backup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest backup',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _SummaryRow(label: 'File', value: backup.fileName),
            _SummaryRow(label: 'Cards', value: '${backup.cardCount}'),
            _SummaryRow(
              label: 'Created',
              value: backup.createdAt.toLocal().toString(),
            ),
            _SummaryRow(label: 'Path', value: backup.path),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
