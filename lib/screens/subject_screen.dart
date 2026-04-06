import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../widgets/lectures_skeleton.dart';

import '../core/theme.dart';
import '../models/lecture.dart';
import '../models/subject.dart';
import '../models/student.dart';
import '../state/app_services.dart';
import '../state/auth_provider.dart';
import '../state/lectures_provider.dart';
import 'lecture_screen.dart';
import 'record_lecture_screen.dart';

class SubjectScreen extends ConsumerStatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _pollTimer;
  ProviderSubscription<AsyncValue<List<Lecture>>>? _lecturesSub;

  @override
  void initState() {
    super.initState();
    // Poll lectures while any lecture is processing so the UI flips to Ready automatically.
    _lecturesSub = ref.listenManual<AsyncValue<List<Lecture>>>(
      lecturesProvider(widget.subject.id),
      (prev, next) {
        final lectures = next.valueOrNull;
        final hasProcessing = lectures != null && lectures.any((l) => l.status == LectureStatus.processing);
        if (hasProcessing) {
          _pollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted) ref.invalidate(lecturesProvider(widget.subject.id));
          });
        } else {
          _pollTimer?.cancel();
          _pollTimer = null;
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _lecturesSub?.close();
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
                    final lecturesAsync = ref.watch(lecturesProvider(widget.subject.id));
                    final canRecord = role == Role.teacher && widget.subject.isOwner;
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                _TopBar(subjectName: widget.subject.name),
                // students list
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: FutureBuilder<List<Student>>(
                      future: ref.read(apiProvider).listStudents(widget.subject.id),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final students = snap.data!;
                        if (students.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Students", style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: students.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (ctx, i) {
                                  final s = students[i];
                                  return SizedBox(
                                    width: 80,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: AppTheme.primary.withOpacity(0.12),
                                              child: Text(s.name.isEmpty ? "?" : s.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
                                            ),
                                            if (s.isRepresentative)
                                              Positioned(
                                                right: -2,
                                                bottom: -2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFEF3C7)),
                                                  child: const Icon(Icons.star, size: 12, color: Color(0xFFB45309)),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Text(
                                            s.name,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            // teacher controls: appoint representative
                            if (ref.read(authProvider).role == Role.teacher)
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final pick = await showDialog<String?>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: Colors.white,
                                          title: const Text('Manage Representatives', style: TextStyle(fontWeight: FontWeight.w900)),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: students.length,
                                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                                              itemBuilder: (ctx, i) {
                                                final st = students[i];
                                                return Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(color: const Color(0xFFE0E0E8)),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: InkWell(
                                                    onTap: () => Navigator.pop(ctx, st.id),
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 20,
                                                          backgroundColor: AppTheme.primary.withOpacity(0.12),
                                                          child: Text(
                                                            st.name.isEmpty ? '?' : st.name[0].toUpperCase(),
                                                            style: const TextStyle(
                                                              color: AppTheme.primary,
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                st.name,
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Color(0xFF121117),
                                                                ),
                                                              ),
                                                              if (st.isRepresentative)
                                                                const Text(
                                                                  'Representative',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Color(0xFFB45309),
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (st.isRepresentative)
                                                          const Icon(Icons.star, color: Color(0xFFB45309), size: 18),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (pick != null) {
                                        await ref.read(apiProvider).toggleRepresentative(widget.subject.id, pick);
                                        setState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.manage_accounts_rounded),
                                    label: const Text('Manage reps'),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 6),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeaderDelegate(
                    minHeight: 64,
                    maxHeight: 64,
                    child: _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 10)),

                lecturesAsync.when(
                  loading: () => const SliverToBoxAdapter(child: _LecturesSkeletonWrapper()),
                  error: (e, _) {
                    String errorMsg = "Something went wrong";
                    if (e.toString().contains("404") || e.toString().contains("Not Found")) {
                      errorMsg = "Lectures feature is not available yet";
                    } else if (e.toString().contains("Network error")) {
                      errorMsg = "Network error - check your connection";
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          errorMsg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                  data: (lectures) {
                    final filtered = query.isEmpty
                        ? lectures
                        : lectures.where((l) {
                            final hay = "${l.summaryPreview} ${l.title ?? ""} ${l.dateTime}";
                            return hay.toLowerCase().contains(query);
                          }).toList();

                    if (lectures.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyLectures(role: role, canRecord: canRecord),
                      );
                    }

                    if (filtered.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(18, 30, 18, 110),
                          child: Center(
                            child: Text(
                              "No matching lectures found.",
                              style: TextStyle(
                                color: Color(0xFF67608A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _LectureCard(
                          lecture: filtered[i],
                          onTap: () {
                            final lec = filtered[i];
                            if (lec.status != LectureStatus.ready) {
                              final msg = lec.status == LectureStatus.failed
                                  ? "Lecture failed. Please try recording/uploading again."
                                  : "Lecture is still processing. Please wait until it's Ready.";
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                              return;
                            }

                            final lectureWithSubject = Lecture(
                              id: lec.id,
                              subjectId: lec.subjectId,
                              dateTime: lec.dateTime,
                              status: lec.status,
                              englishSummaryPreview: lec.englishSummaryPreview,
                              title: lec.title,
                              subjectName: widget.subject.name,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LectureScreen(lecture: lectureWithSubject)),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Teacher FAB (Record)
            if (canRecord)
              Positioned(
                right: 18,
                bottom: 22,
                child: _RecordFab(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecordLectureScreen(subject: widget.subject)),
                    );
                    ref.invalidate(lecturesProvider(widget.subject.id));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sticky top bar with blur-like effect (approx)
class _TopBar extends StatelessWidget {
  final String subjectName;
  const _TopBar({required this.subjectName});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.backgroundLight.withOpacity(0.92),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subjectName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF121117),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundLight,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded, color: Color(0xFF656487)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: "Search topics (e.g., deadlock, scheduling)",
                  hintStyle: TextStyle(color: Color(0xFF656487), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: controller.text.isEmpty ? null : onClear,
              icon: const Icon(Icons.cancel_rounded, size: 18),
              color: const Color(0xFF656487),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final Lecture lecture;
  final VoidCallback onTap;

  const _LectureCard({
    required this.lecture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dt = lecture.dateTime.toLocal();
    final date = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
    final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F0F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "$date • $time",
                  style: const TextStyle(
                    color: Color(0xFF121117),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _StatusChip(status: lecture.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lecture.summaryPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF656487),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
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
    final isShimmer = status == LectureStatus.processing;

    switch (status) {
      case LectureStatus.ready:
        bg = const Color(0xFFD1FAE5); // green-100
        fg = const Color(0xFF047857); // green-700
        break;
      case LectureStatus.uploaded:
        bg = const Color(0xFFDBEAFE); // blue-100
        fg = const Color(0xFF1D4ED8); // blue-700
        break;
      case LectureStatus.processing:
        bg = const Color(0xFFFEF3C7); // amber-100
        fg = const Color(0xFFB45309); // amber-700
        break;
      case LectureStatus.failed:
        bg = const Color(0xFFFEE2E2); // red-100
        fg = const Color(0xFFB91C1C); // red-700
        break;
    }

    final label = status.name[0].toUpperCase() + status.name.substring(1);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (!isShimmer) return chip;

    return Shimmer.fromColors(
      baseColor: bg,
      highlightColor: Colors.white.withOpacity(0.65),
      child: chip,
    );
  }
}

class _RecordFab extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      shadowColor: AppTheme.primary.withOpacity(0.30),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mic_rounded, color: Colors.white, size: 30),
              SizedBox(height: 3),
              Text(
                "RECORD",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLectures extends StatelessWidget {
  final Role? role;
  final bool canRecord;
  const _EmptyLectures({required this.role, required this.canRecord});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 50, 22, 110),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary.withOpacity(0.10),
                    AppTheme.primary.withOpacity(0.30),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(Icons.mic_rounded, size: 120, color: AppTheme.primary.withOpacity(0.40)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No lectures recorded",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF121117)),
            ),
            const SizedBox(height: 10),
            const Text(
              "This subject doesn't have any lectures yet. Start recording to share content with your students.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 18),

            if (canRecord) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Tap Record button to start recording")),
                    );
                  },
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text("Start first recording", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Your teacher will record lectures here.",
                  style: TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small wrapper to avoid importing in sliver file
class _LecturesSkeletonWrapper extends StatelessWidget {
  const _LecturesSkeletonWrapper();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: LecturesSkeleton(),
    );
  }
}

/// Sticky header delegate for the search bar
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SearchHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.child != child;
  }
}
