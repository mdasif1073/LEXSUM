import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';
import '../models/lecture.dart';
import '../services/api.dart';
import '../state/app_services.dart';
import '../state/auth_provider.dart';
import '../state/lectures_provider.dart';
import '../state/quizzes_provider.dart';

class LectureScreen extends ConsumerStatefulWidget {
  final Lecture lecture;
  const LectureScreen({super.key, required this.lecture});

  @override
  ConsumerState<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends ConsumerState<LectureScreen> {
  int _tab = 0; // 0 notes, 1 summary, 2 role-specific (quiz or stats)
  int _photosRefreshTick = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final isTeacher = role == Role.teacher;
    final detailAsync = ref.watch(lectureDetailOutProvider(widget.lecture.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: detailAsync.when(
          loading: () => _LectureScaffold(
            title: "Lecture",
            onBack: () => Navigator.pop(context),
            header: _HeaderCard(
              lectureAt: widget.lecture.dateTime,
              subjectName: widget.lecture.subjectName ?? "Subject",
              status: widget.lecture.status,
            ),
            body: const _ProcessingBody(
              title: "Loading…",
              subtitle: "Fetching lecture details",
              showRefresh: false,
            ),
          ),
          error: (e, _) => _LectureScaffold(
            title: "Lecture",
            onBack: () => Navigator.pop(context),
            header: _HeaderCard(
              lectureAt: widget.lecture.dateTime,
              subjectName: widget.lecture.subjectName ?? "Subject",
              status: widget.lecture.status,
            ),
            body: _ErrorBody(message: "Failed to load lecture: $e"),
          ),
          data: (detail) {
            final status = _parseLectureStatus(detail.status);
            final subjectName = widget.lecture.subjectName ?? "Subject";
            final ready = status == LectureStatus.ready;

            if (!ready) {
              return _LectureScaffold(
                title: "Lecture",
                onBack: () => Navigator.pop(context),
                header: _HeaderCard(
                  lectureAt: detail.lectureAt,
                  subjectName: subjectName,
                  status: status,
                ),
                body: _ProcessingBody(
                  title: "Processing…",
                  subtitle: "This lecture is not ready yet.",
                  showRefresh: true,
                  onRefresh: () => ref.invalidate(lectureDetailOutProvider(widget.lecture.id)),
                ),
              );
            }

            return _LectureScaffold(
              title: "Lecture",
              onBack: () => Navigator.pop(context),
              header: _HeaderCard(
                lectureAt: detail.lectureAt,
                subjectName: subjectName,
                status: status,
              ),
              tabs: _SegmentedTabs(
                value: _tab,
                isTeacher: isTeacher,
                onChanged: (v) => setState(() => _tab = v),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                child: _tab == 0
                    ? _NotesTab(
                        lectureId: widget.lecture.id,
                        notesMd: detail.notesMd ?? "",
                        photosRefreshTick: _photosRefreshTick,
                      )
                    : _tab == 1
                        ? _SummaryTab(
                            summaryMd: detail.summaryMd ?? "",
                          )
                        : isTeacher
                            ? _TeacherQuizStatsTab(lectureId: widget.lecture.id)
                            : _QuizTab(lectureId: widget.lecture.id),
              ),
              footer: _tab == 0
                  ? _AddNotesFooter(
                      role: role,
                      subjectId: widget.lecture.subjectId,
                      onUpload: _uploadNotePhoto,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  static LectureStatus _parseLectureStatus(String status) {
    switch (status) {
      case 'uploaded':
        return LectureStatus.uploaded;
      case 'processing':
        return LectureStatus.processing;
      case 'ready':
        return LectureStatus.ready;
      case 'failed':
        return LectureStatus.failed;
      default:
        return LectureStatus.uploaded;
    }
  }

  Future<void> _uploadNotePhoto(String filePath) async {
    final fileName = filePath.split('/').last;
    try {
      await ref.read(apiProvider).addNotePhoto(widget.lecture.id, filePath);
      if (!mounted) return;
      setState(() => _photosRefreshTick++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo "$fileName" uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
      );
    }
  }
}

class _LectureScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget header;
  final Widget body;
  final Widget? tabs;
  final Widget? footer;

  const _LectureScaffold({
    required this.title,
    required this.onBack,
    required this.header,
    required this.body,
    this.tabs,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(title: title, onBack: onBack),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: header),
              if (tabs != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeader(
                    height: 66,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: tabs!,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: body),
            ],
          ),
        ),
        ?footer,
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF121117),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final DateTime lectureAt;
  final String subjectName;
  final LectureStatus status;

  const _HeaderCard({
    required this.lectureAt,
    required this.subjectName,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final dt = lectureAt.toLocal();
    final date = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
    final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F0F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary.withOpacity(0.25), AppTheme.primary.withOpacity(0.06)],
                ),
              ),
              child: Center(
                child: Icon(Icons.memory_rounded, size: 56, color: AppTheme.primary.withOpacity(0.35)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lecture Overview",
                    style: TextStyle(color: Color(0xFF656487), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF121117),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        "$date • $time",
                        style: const TextStyle(color: Color(0xFF656487), fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _StatusChip(status: status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LectureStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final shimmer = status == LectureStatus.processing;

    switch (status) {
      case LectureStatus.ready:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        break;
      case LectureStatus.uploaded:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case LectureStatus.processing:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case LectureStatus.failed:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
    }

    final label = status.name[0].toUpperCase() + status.name.substring(1);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
      ),
    );

    if (!shimmer) return chip;
    return Shimmer.fromColors(
      baseColor: bg,
      highlightColor: Colors.white.withOpacity(0.65),
      child: chip,
    );
  }
}

class _ProcessingBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showRefresh;
  final VoidCallback? onRefresh;

  const _ProcessingBody({
    required this.title,
    required this.subtitle,
    required this.showRefresh,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.white,
            highlightColor: const Color(0xFFF4F4FA),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF0F0F6)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF121117)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600, height: 1.35),
            textAlign: TextAlign.center,
          ),
          if (showRefresh) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Refresh status", style: TextStyle(fontWeight: FontWeight.w900)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Color(0xFFE2E2EC)),
                  foregroundColor: const Color(0xFF121117),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int value;
  final bool isTeacher;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.value,
    required this.isTeacher,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F6)),
      ),
      child: Row(
        children: [
          _SegItem(label: "Notes", selected: value == 0, onTap: () => onChanged(0)),
          _SegItem(label: "Summary", selected: value == 1, onTap: () => onChanged(1)),
          _SegItem(
            label: isTeacher ? "Quiz Stats" : "Quiz",
            selected: value == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primary : const Color(0xFF656487),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesTab extends ConsumerWidget {
  final String lectureId;
  final String notesMd;
  final int photosRefreshTick;

  const _NotesTab({
    required this.lectureId,
    required this.notesMd,
    required this.photosRefreshTick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = notesMd.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextCard(
          title: "Notes",
          body: notes.isEmpty ? "No notes yet." : notes,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Map<String, String>>>(
          key: ValueKey(photosRefreshTick),
          future: ref.read(apiProvider).listNotePhotos(lectureId),
          builder: (context, snap) {
            final items = snap.data ?? const <Map<String, String>>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return Shimmer.fromColors(
                baseColor: Colors.white,
                highlightColor: const Color(0xFFF4F4FA),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0F0F6)),
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF0F0F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Class Photos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text(
                      'No notes photos uploaded yet',
                      style: TextStyle(color: Color(0xFF656487)),
                    )
                  else
                    ...items.map((n) {
                      final url = (n['url'] ?? '').trim();
                      final by = (n['by'] ?? '').trim();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 160,
                                child: InkWell(
                                  onTap: () => _openFullImage(context, url),
                                  child: Hero(
                                    tag: "note-$url",
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    by.isEmpty ? "By: Unknown" : "By: $by",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF656487)),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _downloadAndSaveImage(context, url),
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text(
                                    "Save",
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openFullImage(BuildContext context, String url) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageViewScreen(imageUrl: url),
      ),
    );
  }

  Future<void> _downloadAndSaveImage(BuildContext context, String url) async {
    await _saveImageFromUrl(context, url);
  }
}

class _FullImageViewScreen extends StatelessWidget {
  final String imageUrl;
  const _FullImageViewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Image"),
        actions: [
          IconButton(
            onPressed: () => _saveImageFromUrl(context, imageUrl),
            icon: const Icon(Icons.download_rounded),
            tooltip: "Save to gallery",
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Hero(
            tag: "note-$imageUrl",
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _saveImageFromUrl(BuildContext context, String url) async {
  if (url.isEmpty) return;
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("Download failed (${resp.statusCode})");
    }

    final Uint8List bytes = resp.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception("Downloaded file is empty");
    }

    final permissionOk = await _ensureSavePermission();
    if (!permissionOk && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Media permission denied. Cannot save image.")),
      );
      return;
    }

    final name = "lecture_note_${DateTime.now().millisecondsSinceEpoch}";
    dynamic result = await ImageGallerySaverPlus.saveImage(
      bytes,
      quality: 100,
      name: name,
    );
    var saved = _isSaveSuccess(result);

    // Android fallback: if first save fails, ask permissions explicitly and retry once.
    if (!saved && Platform.isAndroid) {
      await Permission.photos.request();
      await Permission.storage.request();
      result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
      saved = _isSaveSuccess(result);
    }
    if (!saved) throw Exception("Save failed");

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image saved to gallery")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    }
  }
}

bool _isSaveSuccess(dynamic result) {
  if (result is Map) {
    final v1 = result['isSuccess'];
    if (v1 is bool) return v1;
    final v2 = result['is_success'];
    if (v2 is bool) return v2;
    if (result['filePath'] != null || result['file_path'] != null) return true;
  }
  return result != null;
}

Future<bool> _ensureSavePermission() async {
  if (Platform.isAndroid) {
    // On Android 10+ gallery save often works without explicit storage permission,
    // but requesting media permission improves behavior on Android 13+.
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited || photos.isRestricted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted || storage.isLimited || storage.isRestricted;
  }
  if (Platform.isIOS) {
    final photos = await Permission.photos.request();
    return photos.isGranted || photos.isLimited;
  }
  return true;
}

class _SummaryTab extends StatelessWidget {
  final String summaryMd;

  const _SummaryTab({
    required this.summaryMd,
  });

  @override
  Widget build(BuildContext context) {
    final summary = summaryMd.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextCard(
          title: "Summary",
          body: summary.isEmpty ? "No summary yet." : summary,
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  final String title;
  final String body;

  const _TextCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF121117)),
          ),
          const SizedBox(height: 12),
          SelectableText(
            body,
            style: const TextStyle(
              color: Color(0xFF656487),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddNotesFooter extends ConsumerWidget {
  final Role? role;
  final String subjectId;
  final Future<void> Function(String filePath) onUpload;

  const _AddNotesFooter({
    required this.role,
    required this.subjectId,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ref.read(apiProvider).listStudents(subjectId),
      ]),
      builder: (context, snap) {
        var enabled = role == Role.teacher;
        if (!enabled && snap.hasData) {
          final students = snap.data![0] as List;
          final meId = ref.read(authProvider).userId;
          dynamic found;
          for (final s in students) {
            if (s.id == meId) {
              found = s;
              break;
            }
          }
          if (found != null && (found.isRepresentative == true)) enabled = true;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F6))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: enabled ? AppTheme.primary : const Color(0xFFCCCCD6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: enabled
                  ? () async {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (ctx) => _UploadNotesSheet(
                          onPick: (source) async {
                            Navigator.pop(ctx);
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: source);
                            if (file != null && context.mounted) {
                              await onUpload(file.path);
                            }
                          },
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text("Add notes", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        );
      },
    );
  }
}

class _UploadNotesSheet extends StatelessWidget {
  final Future<void> Function(ImageSource source) onPick;
  const _UploadNotesSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFDCDCE5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Class Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF121117),
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
            title: const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => onPick(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => onPick(ImageSource.camera),
          ),
        ],
      ),
    );
  }
}

class _TeacherQuizStatsTab extends ConsumerWidget {
  final String lectureId;
  const _TeacherQuizStatsTab({required this.lectureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(quizTeacherStatsProvider(lectureId));
    return statsAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: Colors.white,
        highlightColor: const Color(0xFFF4F4FA),
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F6)),
          ),
        ),
      ),
      error: (e, _) => _ErrorBody(message: "Failed to load quiz stats: $e"),
      data: (stats) {
        final latestAt = stats.latestAttemptAt?.toLocal();
        final attendancePct = stats.totalStudents == 0
            ? 0
            : ((stats.attemptedStudents * 100) / stats.totalStudents).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TODAY'S QUIZ ATTENDANCE",
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${stats.attemptedStudents} / ${stats.totalStudents} students",
                    style: const TextStyle(
                      color: Color(0xFF121117),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Attendance: $attendancePct%",
                    style: const TextStyle(
                      color: Color(0xFF67608A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TextCard(
              title: "Quiz Stats",
              body: stats.quizId == null
                  ? "No quiz generated yet for this lecture."
                  : [
                      "Attempted students: ${stats.attemptedStudents}",
                      "Not attempted: ${stats.notAttemptedStudents}",
                      "Average score: ${stats.averageScore == null ? '-' : stats.averageScore!.toStringAsFixed(1)} / 100",
                      "Last attempt: ${latestAt == null ? '-' : _fmtDateTime(latestAt)}",
                    ].join("\n"),
            ),
          ],
        );
      },
    );
  }

  String _fmtDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$d-$m-$y $hh:$mm";
  }
}

class _QuizTab extends ConsumerStatefulWidget {
  final String lectureId;
  const _QuizTab({required this.lectureId});

  @override
  ConsumerState<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends ConsumerState<_QuizTab> {
  bool _submitting = false;
  bool _useLastAttemptDefaults = true;
  bool _showResults = true;
  final Map<String, TextEditingController> _shortControllers = {};
  Map<String, String> _answers = {};

  @override
  void dispose() {
    for (final c in _shortControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(latestQuizProvider(widget.lectureId));

    return quizAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: Colors.white,
        highlightColor: const Color(0xFFF4F4FA),
        child: Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F6)),
          ),
        ),
      ),
      error: (e, _) => _ErrorBody(message: "Failed to load quiz: $e"),
      data: (quiz) {
        if (quiz == null) {
          return const _TextCard(
            title: "Quiz",
            body: "No quiz generated yet. Please wait a bit and try again.",
          );
        }

        Map<String, dynamic> quizObj;
        try {
          quizObj = jsonDecode(quiz.quizJson) as Map<String, dynamic>;
        } catch (e) {
          return _ErrorBody(message: "Quiz data is invalid: $e");
        }

        final questions = (quizObj['questions'] is List) ? (quizObj['questions'] as List) : const [];
        if (questions.isEmpty) {
          return const _TextCard(title: "Quiz", body: "Quiz has no questions.");
        }

        final attemptsAsync = ref.watch(myQuizAttemptsProvider(quiz.id));
        final attempts = attemptsAsync.value ?? const <QuizAttemptOut>[];
        final latestAttempt = attempts.isEmpty ? null : attempts.first;
        Map<String, dynamic>? latestAnswers;
        if (latestAttempt != null) {
          try {
            latestAnswers = jsonDecode(latestAttempt.answersJson) as Map<String, dynamic>;
          } catch (_) {
            latestAnswers = null;
          }
        }
        final latestAnswersStr = latestAnswers?.map((k, v) => MapEntry(k, (v ?? '').toString()));
        final mergedAnswers =
            (_useLastAttemptDefaults && latestAnswersStr != null) ? {...latestAnswersStr, ..._answers} : _answers;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreBanner(attemptsAsync: attemptsAsync),
            const SizedBox(height: 14),
            ...questions.map((q) {
              if (q is! Map) return const SizedBox.shrink();
              final id = (q['id'] ?? '').toString();
              final type = (q['type'] ?? '').toString();
              final prompt = (q['prompt'] ?? '').toString();

              if (type == 'mcq') {
                final options = (q['options'] is List) ? (q['options'] as List).map((e) => e.toString()).toList() : <String>[];
                final answerIndex = (q['answer_index'] is num) ? (q['answer_index'] as num).toInt() : null;
                final selected = _normalizeMcqAnswer(mergedAnswers[id], options);
                final lastSelected = _normalizeMcqAnswer(latestAnswers?[id], options);
                final showResult = _showResults && latestAttempt != null && lastSelected != null && lastSelected.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _McqCard(
                    question: prompt,
                    options: options,
                    selectedLetter: selected,
                    showResult: showResult,
                    lastSelected: lastSelected,
                    correctIndex: answerIndex,
                    onSelect: (letter) => setState(() {
                      _useLastAttemptDefaults = false;
                      _showResults = false;
                      _answers[id] = letter;
                    }),
                  ),
                );
              }

              if (type == 'short') {
                final ideal = (q['ideal_answer'] ?? '').toString();
                final initial = (mergedAnswers[id] ?? '').toString();
                final controller = _shortControllers.putIfAbsent(id, () => TextEditingController(text: initial));
                if ((_answers[id] == null) && controller.text != initial) {
                  controller.text = initial;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ShortAnswerCard(
                    prompt: prompt,
                    idealAnswer: ideal,
                    controller: controller,
                    showIdeal: _showResults && latestAttempt != null,
                    onChanged: (v) => setState(() {
                      _useLastAttemptDefaults = false;
                      _showResults = false;
                      _answers[id] = v;
                    }),
                  ),
                );
              }

              return const SizedBox.shrink();
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _answers = {};
                              _useLastAttemptDefaults = false;
                              _showResults = false;
                              for (final c in _shortControllers.values) {
                                c.dispose();
                              }
                              _shortControllers.clear();
                            }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFE2E2EC)),
                      foregroundColor: const Color(0xFF121117),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text("Reset", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : () => _submit(quiz.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text("Submit", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(String quizId) async {
    setState(() => _submitting = true);
    try {
      final attempt = await ref.read(apiProvider).submitQuizAttempt(quizId, answers: _answers);
      ref.invalidate(myQuizAttemptsProvider(quizId));
      if (!mounted) return;
      setState(() {
        _useLastAttemptDefaults = true;
        _showResults = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submitted. Score: ${attempt.score}/100")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _normalizeMcqAnswer(dynamic raw, List<String> options) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;
    final upper = s.toUpperCase();
    if (upper == 'A' || upper == 'B' || upper == 'C' || upper == 'D') return upper;
    if (RegExp(r'^[0-3]$').hasMatch(s)) {
      final i = int.parse(s);
      return String.fromCharCode('A'.codeUnitAt(0) + i);
    }
    final idx = options.indexWhere((o) => o.trim() == s);
    if (idx >= 0 && idx <= 3) {
      return String.fromCharCode('A'.codeUnitAt(0) + idx);
    }
    return null;
  }
}

class _ScoreBanner extends StatelessWidget {
  final AsyncValue<List<QuizAttemptOut>> attemptsAsync;
  const _ScoreBanner({required this.attemptsAsync});

  @override
  Widget build(BuildContext context) {
    final score = attemptsAsync.when(
      loading: () => null,
      error: (_, _) => null,
      data: (attempts) => attempts.isEmpty ? null : attempts.first.score,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "YOUR SCORE",
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score == null ? "Not attempted" : "$score / 100",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF121117)),
                ),
              ],
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                score >= 50 ? "PASSED" : "FAILED",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

class _McqCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedLetter;
  final void Function(String letter) onSelect;
  final bool showResult;
  final String? lastSelected;
  final int? correctIndex;

  const _McqCard({
    required this.question,
    required this.options,
    required this.selectedLetter,
    required this.onSelect,
    required this.showResult,
    required this.lastSelected,
    required this.correctIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF121117)),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (i) {
            final letter = String.fromCharCode('A'.codeUnitAt(0) + i);
            final text = options[i];
            final selected = selectedLetter == letter;

            var state = _OptState.normal;
            if (showResult && correctIndex != null) {
              final correctLetter = String.fromCharCode('A'.codeUnitAt(0) + correctIndex!);
              final user = (lastSelected ?? '').trim();
              if (letter == correctLetter) state = _OptState.correct;
              if (user == letter && letter != correctLetter) state = _OptState.wrong;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionTile(
                letter: "$letter.",
                text: text,
                selected: selected,
                state: state,
                onTap: () => onSelect(letter),
              ),
            );
          }),
        ],
      ),
    );
  }
}

enum _OptState { normal, wrong, correct }

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final _OptState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = selected ? AppTheme.primary.withOpacity(0.45) : const Color(0xFFE6E6F0);
    Color bg = selected ? AppTheme.primary.withOpacity(0.06) : AppTheme.backgroundLight;
    Color fg = const Color(0xFF121117);
    IconData? icon;
    Color? iconColor;

    if (state == _OptState.wrong) {
      border = const Color(0xFFFECACA);
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      iconColor = fg;
    } else if (state == _OptState.correct) {
      border = const Color(0xFFBBF7D0);
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      iconColor = fg;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Text(letter, style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
            if (icon != null) Icon(icon, size: 18, color: iconColor),
          ],
        ),
      ),
    );
  }
}

class _ShortAnswerCard extends StatelessWidget {
  final String prompt;
  final String idealAnswer;
  final TextEditingController controller;
  final bool showIdeal;
  final ValueChanged<String> onChanged;

  const _ShortAnswerCard({
    required this.prompt,
    required this.idealAnswer,
    required this.controller,
    required this.showIdeal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Short Answer",
            style: TextStyle(
              color: Color(0xFF656487),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF121117), height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: "Type your answer…",
              filled: true,
              fillColor: AppTheme.backgroundLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE6E6F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE6E6F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.6))),
            ),
            controller: controller,
            onChanged: onChanged,
          ),
          if (showIdeal && idealAnswer.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text(
                        "IDEAL ANSWER",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    idealAnswer.trim(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF121117), height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeader({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
