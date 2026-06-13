import 'package:flutter/material.dart';

import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_storage_codec.dart';
import 'package:card_box/services/file_share_service.dart';
import 'package:card_box/theme.dart';

class ExportImportScreen extends StatefulWidget {
  ExportImportScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    this.backupFileService = const BackupFileService(),
    BackupCryptoService? backupCryptoService,
    this.fileShareService = const FileShareService(),
  }) : backupCryptoService = backupCryptoService ?? BackupCryptoService();

  final CardRepository repository;
  final AppLockService appLockService;
  final BackupFileService backupFileService;
  final BackupCryptoService backupCryptoService;
  final FileShareService fileShareService;

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  BackupFileInfo? _latestBackup;
  String _message = '';
  bool _exporting = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export and import')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceLarge,
          tokens.spaceSmall,
          tokens.spaceLarge,
          tokens.spaceXLarge + tokens.spaceMedium,
        ),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device backup',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  const Text(
                    'Card Box keeps data local. Create a real backup file that includes card data and saved photos. On mobile, Card Box also opens the system share sheet so you can save or send the backup right away. Use encrypted backup when you want password protection for the exported file.',
                  ),
                  SizedBox(height: tokens.spaceMedium),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: Text(
                          _exporting
                              ? 'Creating backup...'
                              : 'Create and share standard backup',
                        ),
                        onPressed: _exporting ? null : _exportPlainBackup,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: Text(
                          _exporting
                              ? 'Creating encrypted backup...'
                              : 'Create and share encrypted backup',
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
            SizedBox(height: tokens.spaceMedium),
            _BackupSummaryCard(backup: _latestBackup!),
          ],
          SizedBox(height: tokens.spaceLarge + 2),
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import backup file',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  const Text(
                    'Choose a Card Box backup file from the native file picker. Matching card IDs are updated; missing ones are added.',
                  ),
                  SizedBox(height: tokens.spaceMedium),
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
            SizedBox(height: tokens.spaceMedium),
            Text(
              _message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
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
        final summary = await widget.repository.exportPlainJson();
        final encrypted = await widget.backupCryptoService.encryptJson(
          rawJson: summary.rawJson,
          password: password,
        );
        return CardExportSummary(
          rawJson: encrypted,
          missingImages: summary.missingImages,
        );
      },
      fileNamePrefix: 'card_box_backup_encrypted',
    );
  }

  Future<void> _exportBackupFile({
    required _BackupExportMode mode,
    required Future<CardExportSummary> Function() rawJsonLoader,
    required String fileNamePrefix,
  }) async {
    try {
      setState(() {
        _exporting = true;
        _message = '';
      });
      widget.appLockService.beginTrustedExternalFlow();
      final summary = await rawJsonLoader();
      final backup = await widget.backupFileService.createBackupFile(
        rawJson: summary.rawJson,
        cardCount: widget.repository.cards.length,
        fileNamePrefix: fileNamePrefix,
      );
      if (backup == null) {
        setState(() => _message = 'Backup export canceled.');
        return;
      }
      final shared = await widget.fileShareService.shareFile(
        path: backup.path,
        subject: backup.fileName,
        text: 'Card Box backup file',
      );
      final missingSuffix = summary.missingImages.isEmpty
          ? ''
          : ' ${summary.missingImages.length} image(s) could not be '
              'included because the file was missing — re-importing '
              'this backup on the original device will restore them.';
      setState(() {
        _latestBackup = backup;
        _message =
            '${mode == _BackupExportMode.encrypted ? 'Encrypted' : 'Standard'} backup file created: ${backup.fileName}'
            '${shared ? ' and opened in the share sheet.' : '.'}'
            '$missingSuffix';
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
      final imported = await widget.backupFileService.pickBackupFile();
      if (imported == null) {
        setState(() => _message = 'Import canceled.');
        return;
      }
      var rawJson = imported.rawJson;
      var label = imported.fileName;
      if (widget.backupCryptoService.looksEncrypted(rawJson)) {
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
        rawJson = await widget.backupCryptoService.decryptJson(
          encryptedJson: rawJson,
          password: password,
        );
        label = '$label (encrypted)';
      }
      final result = await widget.repository.importPlainJsonProtected(rawJson);
      final message = StringBuffer(
        'Imported ${result.importedCount} card(s) from $label.',
      );
      if (result.addedCount > 0 || result.updatedCount > 0) {
        message.write(
          ' Added ${result.addedCount}, updated ${result.updatedCount}.',
        );
      }
      if (result.skippedOlderCount > 0) {
        message.write(
          ' Kept ${result.skippedOlderCount} newer card(s) already on this device.',
        );
      }
      setState(() => _message = message.toString());
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
    final tokens = CardBoxThemeTokens.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        left: tokens.spaceLarge,
        right: tokens.spaceLarge,
        top: tokens.spaceSmall,
        bottom: MediaQuery.viewInsetsOf(context).bottom + tokens.spaceLarge,
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
                    SizedBox(height: tokens.spaceSmall),
                    Text(widget.helperText),
                    SizedBox(height: tokens.spaceLarge),
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
                      SizedBox(height: tokens.spaceMedium),
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
          SizedBox(height: tokens.spaceLarge),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              SizedBox(width: tokens.spaceMedium),
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
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest backup',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceMedium - 2),
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
    final tokens = CardBoxThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: tokens.spaceXSmall / 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
