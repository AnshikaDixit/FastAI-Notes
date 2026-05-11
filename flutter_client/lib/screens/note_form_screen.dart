// screens/note_form_screen.dart
// Create or Edit a note. If `note` is null → Create mode. Otherwise → Edit mode.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/note_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/app_text_styles.dart';

class NoteFormScreen extends StatefulWidget {
  final Note? note; // null = create mode

  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  bool _personal = false;

  bool get _isEditMode => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _descCtrl = TextEditingController(text: widget.note?.description ?? '');
    _personal = widget.note?.personal ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final noteProvider = context.read<NoteProvider>();
    bool success;

    if (_isEditMode) {
      final updated = await noteProvider.updateNote(
        widget.note!.id,
        NoteUpdate(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          personal: _personal,
        ),
      );
      success = updated != null;
    } else {
      final created = await noteProvider.createNote(
        NoteCreate(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          personal: _personal,
        ),
      );
      success = created != null;
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true); // signal success to caller
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          noteProvider.errorMessage ?? AppStrings.genericError,
          style: AppTextStyles.bodyMedium,
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<NoteProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          _isEditMode ? AppStrings.editNote : AppStrings.newNote,
          style: AppTextStyles.headingLarge,
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  )
                : Text(
                    AppStrings.save,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.primary),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(
                  controller: _titleCtrl,
                  label: AppStrings.title,
                  icon: Icons.title_rounded,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _descCtrl,
                  label: AppStrings.description,
                  icon: Icons.notes_rounded,
                  maxLines: 8,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Description is required' : null,
                ),
                const SizedBox(height: 20),
                // Personal toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    value: _personal,
                    onChanged: (v) => setState(() => _personal = v),
                    title: Text(AppStrings.personal,
                        style: AppTextStyles.bodyMedium),
                    activeThumbColor: AppColors.primary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodyMedium
            .copyWith(color: AppColors.textSecondary),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.textSecondary, size: 20)
            : null,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1.5)),
      ),
      validator: validator,
    );
  }
}
