// screens/notes_screen.dart
// Home screen — lists all notes for the logged-in user.
// AppBar actions: Background Export + Live Stream Export + Logout.

import 'package:fastai_notes_client/core/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../services/export_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/app_text_styles.dart';
import 'login_screen.dart';
import 'note_form_screen.dart';
import 'stream_export_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final ExportService _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().fetchNotes();
    });
  }

  Future<void> _triggerBackgroundExport() async {
    final result = await _exportService.triggerExport();
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        // Handle 202 Accepted: Show message + button to view live stream
        if (data.statusCode == 202) {
          _showSnackbar(
            data.message,
            AppColors.success,
            action: SnackBarAction(
              label: 'View Stream',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StreamExportScreen()),
              ),
            ),
          );
        } else {
          _showSnackbar(data.message, AppColors.success);
        }
      case Failure(:final exception):
        _showSnackbar(exception.message, AppColors.error);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(AppStrings.confirmDelete, style: AppTextStyles.headingMedium),
        content: Text(AppStrings.confirmDeleteBody, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.cancel,
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.delete,
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await context.read<NoteProvider>().deleteNote(note.id);
    if (!mounted) return;
    if (success) {
      _showSnackbar(AppStrings.noteDeleted, AppColors.success);
    } else {
      _showSnackbar(
          context.read<NoteProvider>().errorMessage ?? AppStrings.genericError,
          AppColors.error);
    }
  }

  Future<bool?> _showPinDialog() async {
    String pin = '';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Enter PIN', style: AppTextStyles.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This is a personal note. Enter your PIN to view.',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: AppTextStyles.headingLarge.copyWith(letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '****',
              ),
              onChanged: (val) => pin = val,
              onSubmitted: (val) {
                if (val == '1234') {
                  Navigator.of(ctx).pop(true);
                } else {
                   _showSnackbar('Incorrect PIN', AppColors.error);
                   Navigator.of(ctx).pop(false);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (pin == '1234') {
                Navigator.of(ctx).pop(true);
              } else {
                _showSnackbar('Incorrect PIN', AppColors.error);
                Navigator.of(ctx).pop(false);
              }
            },
            child: Text('Unlock',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: AppTextStyles.bodyMedium),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      action: action,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: _buildAppBar(auth),
      body: SafeArea(child: _buildBody(noteProvider)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NoteFormScreen()),
          );
          if (created == true && mounted) {
            _showSnackbar(AppStrings.noteCreated, AppColors.success);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  AppBar _buildAppBar(AuthProvider auth) {
    return AppBar(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.notes, style: AppTextStyles.headingLarge),
          if (auth.currentUser != null)
            Text(
              auth.currentUser!.email,
              style: AppTextStyles.caption,
            ),
        ],
      ),
      actions: [
        // Background export button
        IconButton(
          onPressed: _triggerBackgroundExport,
          icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.textSecondary),
          tooltip: AppStrings.exportBackground,
        ),
        // SSE stream export button
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StreamExportScreen()),
          ),
          icon: const Icon(Icons.stream_rounded, color: AppColors.accent),
          tooltip: AppStrings.streamExport,
        ),
        // Logout
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          tooltip: AppStrings.logout,
        ),
      ],
    );
  }

  Widget _buildBody(NoteProvider noteProvider) {
    if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (noteProvider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              AppStrings.noNotes,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: () => noteProvider.fetchNotes(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: noteProvider.notes.length,
        itemBuilder: (_, i) => _NoteCard(
          note: noteProvider.notes[i],
          onEdit: () async {
            final note = noteProvider.notes[i];
            
            // If personal, require PIN first
            if (note.personal == true) {
              final authenticated = await _showPinDialog();
              if (authenticated != true) return;
            }

            if (!mounted) return;
            final updated = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => NoteFormScreen(note: note),
              ),
            );
            if (updated == true && mounted) {
              _showSnackbar(AppStrings.noteUpdated, AppColors.success);
            }
          },
          onDelete: () => _deleteNote(noteProvider.notes[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note card widget
// ---------------------------------------------------------------------------
class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(note.title,
                        style: AppTextStyles.headingMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (note.personal == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.personalBadge.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('🔒 Personal',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.personalBadge,
                          )),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.personal == true ? '••••••••' : note.description,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                'Updated ${_formatDate(note.updatedAt)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
