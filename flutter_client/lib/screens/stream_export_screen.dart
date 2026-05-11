// screens/stream_export_screen.dart
// ⭐ The SSE live streaming screen — the centerpiece of Day 08.
//
// What the user sees:
//   1. "Start Stream" button → opens SSE connection to GET /stream/export
//   2. Status message updates live: "Preparing..." → "Exporting note 2 of 5..."
//   3. Linear progress bar fills as notes are exported
//   4. Markdown content appears chunk-by-chunk in a scrollable preview
//   5. "✅ Export complete!" banner when done
//   6. "Copy Markdown" button to copy the full export

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/stream_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/app_text_styles.dart';

class StreamExportScreen extends StatefulWidget {
  const StreamExportScreen({super.key});

  @override
  State<StreamExportScreen> createState() => _StreamExportScreenState();
}

class _StreamExportScreenState extends State<StreamExportScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Own NoteStreamProvider instance — reset when screen is opened fresh.
  late final NoteStreamProvider _streamProvider;

  @override
  void initState() {
    super.initState();
    _streamProvider = NoteStreamProvider();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    _streamProvider.cancel();
    _streamProvider.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _copyMarkdown(String markdown) async {
    await Clipboard.setData(ClipboardData(text: markdown));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppStrings.copied, style: AppTextStyles.bodyMedium),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _streamProvider,
      child: Consumer<NoteStreamProvider>(
        builder: (context, stream, _) {
          // Auto-scroll on new chunk
          if (stream.status == NoteStreamStatus.streaming &&
              stream.fullMarkdown.isNotEmpty) {
            _scrollToBottom();
          }

          return Scaffold(
            backgroundColor: AppColors.bgDark,
            appBar: AppBar(
              backgroundColor: AppColors.bgDark,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
              title: Text(AppStrings.streamExport,
                  style: AppTextStyles.headingLarge),
              actions: [
                if (stream.fullMarkdown.isNotEmpty)
                  IconButton(
                    onPressed: () => _copyMarkdown(stream.fullMarkdown),
                    icon:
                        const Icon(Icons.copy_rounded, color: AppColors.accent),
                    tooltip: AppStrings.copyMarkdown,
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // ── Status + Progress panel ──
                  _StatusPanel(
                      stream: stream, pulseAnimation: _pulseAnimation),
                  // ── Markdown preview ──
                  Expanded(
                    child: _MarkdownPreview(
                      stream: stream,
                      scrollController: _scrollController,
                    ),
                  ),
                  // ── Action button ──
                  _ActionButton(stream: stream, provider: _streamProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status + Progress panel
// ---------------------------------------------------------------------------
class _StatusPanel extends StatelessWidget {
  final NoteStreamProvider stream;
  final Animation<double> pulseAnimation;

  const _StatusPanel({required this.stream, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final isComplete = stream.status == NoteStreamStatus.complete;
    final isError = stream.status == NoteStreamStatus.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon + message
          Row(
            children: [
              _statusIcon(isComplete, isError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stream.statusMessage.isEmpty
                      ? 'Tap "Start Stream" to begin.'
                      : stream.statusMessage,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isComplete
                        ? AppColors.success
                        : isError
                            ? AppColors.error
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stream.totalNotes == 0 && stream.isStreaming
                  ? null // indeterminate while connecting
                  : stream.progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                isComplete
                    ? AppColors.streamComplete
                    : AppColors.streamProgress,
              ),
              minHeight: 6,
            ),
          ),
          if (stream.totalNotes > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${stream.currentNote} / ${stream.totalNotes} notes',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(bool isComplete, bool isError) {
    if (isComplete) {
      return const Icon(Icons.check_circle_rounded,
          color: AppColors.success, size: 22);
    }
    if (isError) {
      return const Icon(Icons.error_outline_rounded,
          color: AppColors.error, size: 22);
    }
    if (stream.isStreaming) {
      return FadeTransition(
        opacity: pulseAnimation,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return const Icon(Icons.stream_rounded,
        color: AppColors.textHint, size: 22);
  }
}

// ---------------------------------------------------------------------------
// Markdown preview area
// ---------------------------------------------------------------------------
class _MarkdownPreview extends StatelessWidget {
  final NoteStreamProvider stream;
  final ScrollController scrollController;

  const _MarkdownPreview({
    required this.stream,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (stream.fullMarkdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Your exported notes will appear here\nin real time as they are streamed.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.bgCard,
      child: Markdown(
        controller: scrollController,
        data: stream.fullMarkdown,
        padding: const EdgeInsets.all(20),
        styleSheet: MarkdownStyleSheet(
          h1: AppTextStyles.displayMedium,
          h2: AppTextStyles.headingLarge,
          h3: AppTextStyles.headingMedium,
          p: AppTextStyles.bodyMedium,
          code: AppTextStyles.monospace.copyWith(
            backgroundColor: AppColors.bgSurface,
          ),
          blockquoteDecoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          horizontalRuleDecoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.divider),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button — Start / Cancel / Reset
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  final NoteStreamProvider stream;
  final NoteStreamProvider provider;

  const _ActionButton({required this.stream, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      color: AppColors.bgDark,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (stream.status) {
      case NoteStreamStatus.idle:
      case NoteStreamStatus.error:
        return ElevatedButton.icon(
          onPressed: () => provider.startStream(),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            stream.status == NoteStreamStatus.error ? 'Retry' : 'Start Stream',
            style: AppTextStyles.labelLarge,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        );

      case NoteStreamStatus.connecting:
      case NoteStreamStatus.streaming:
        return OutlinedButton.icon(
          onPressed: () => provider.cancel(),
          icon: const Icon(Icons.stop_rounded, color: AppColors.error),
          label: Text(
            'Cancel Stream',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );

      case NoteStreamStatus.complete:
        return ElevatedButton.icon(
          onPressed: () => provider.reset(),
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Stream Again', style: AppTextStyles.labelLarge),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.bgDark,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        );
    }
  }
}
