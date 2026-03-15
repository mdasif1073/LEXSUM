import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/create_subject_sheet.dart';
import '../widgets/join_subject_sheet.dart';
import '../widgets/invite_code_sheet.dart';

import '../core/theme.dart';
import '../models/subject.dart';
import '../state/auth_provider.dart';
import '../state/app_services.dart';
import '../state/subjects_provider.dart';
import 'settings_screen.dart';
import '../widgets/shimmer_skeleton.dart';
import 'subject_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0; // UI only (matches Stitch bottom nav)

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final role = session.role;

    // single page app: show subjects only

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        title: const Text("Subjects"),
        actions: [
          // profile avatar -> settings
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _SubjectsBody(role: role)),
        floatingActionButton: (role == Role.teacher)
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () async {
  final result = await showCreateSubjectSheet(context);
  if (result == null) return;

  final api = ref.read(apiProvider);
  final subject = await api.createSubject(result.subjectName);

  ref.invalidate(subjectsProvider);

  if (context.mounted) {
    await showInviteCodeSheet(
      context,
      subjectName: subject.name,
      code: subject.inviteCode ?? "ERROR",
    );
  }
},

              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      // no bottom navigation: students and settings are accessible via class and top-right avatar
    );
  }

  Future<void> _showCreateSubject(BuildContext context) async {
    final ctrl = TextEditingController();
    final api = ref.read(apiProvider);

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create subject"),
        content: TextField(
          controller: ctrl,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: "Subject name",
            hintText: "e.g., Operating Systems",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await api.createSubject(name);
              ref.invalidate(subjectsProvider);
              if (context.mounted) Navigator.pop(ctx, true);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject created")),
      );
    }
  }
}

class _SubjectsBody extends ConsumerWidget {
  final Role? role;
  const _SubjectsBody({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => const SubjectsSkeleton(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (subjects) {
        if (subjects.isEmpty) {
          return _EmptySubjects(role: role);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), // bottom nav spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (role == Role.teacher) ...[
                const _TeacherBanner(),
                const SizedBox(height: 14),
                _SectionLabel(text: "YOUR CURRICULUM"),
                const SizedBox(height: 10),
                ...subjects.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TeacherSubjectTile(subject: s),
                    )),
              ] else ...[
                const _JoinSubjectCard(),
                const SizedBox(height: 16),
                const Text(
                  "My Subjects",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF121118),
                  ),
                ),
                const SizedBox(height: 10),
                ...subjects.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StudentSubjectTile(subject: s),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// ---------------- TEACHER UI ----------------

class _TeacherBanner extends StatelessWidget {
  const _TeacherBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEFF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "TEACHER MODE",
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Manage your classes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF121118),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Create subjects, share invite codes, and record your lectures.",
                  style: TextStyle(
                    color: Color(0xFF67608A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF330DF2), Color(0xFF7E64F7)],
              ),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 34),
          )
        ],
      ),
    );
  }
}

class _TeacherSubjectTile extends ConsumerWidget {
  final Subject subject;
  const _TeacherSubjectTile({required this.subject});

  IconData _iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains("math")) return Icons.calculate_rounded;
    if (n.contains("physics") || n.contains("science")) return Icons.science_rounded;
    if (n.contains("history")) return Icons.history_edu_rounded;
    if (n.contains("bio")) return Icons.biotech_rounded;
    return Icons.menu_book_rounded;
    }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubjectScreen(subject: subject)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForName(subject.name), color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subject.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF121118)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _InviteChip(
              code: subject.code,
              onTap: () {
                if (subject.code != null) {
                  showInviteCodeSheet(
                    context,
                    subjectName: subject.name,
                    code: subject.code!,
                  );
                }
              },
            ),

          ],
        ),
      ),
    );
  }

  void _showInvite(BuildContext context, Subject s) {
    if (s.code == null) return; // Don't show for students
    
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Invite code • ${s.name}"),
        content: Row(
          children: [
            Expanded(
              child: SelectableText(
                s.code!,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: "Copy",
              onPressed: () {
                // optional copy later (Clipboard)
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done")),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  final String? code;
  final VoidCallback onTap;
  const _InviteChip({this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (code == null) {
      return const SizedBox.shrink(); // Don't show for students
    }
    
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        backgroundColor: AppTheme.backgroundLight,
        foregroundColor: AppTheme.primary,
        side: BorderSide(color: AppTheme.primary.withOpacity(0.10)),
      ),
      icon: const Icon(Icons.key_rounded, size: 16),
      label: Text(
        code!,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

/// ---------------- STUDENT UI ----------------

class _JoinSubjectCard extends ConsumerWidget {
  const _JoinSubjectCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEFF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded, color: AppTheme.primary, size: 34),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Join a subject",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF121118)),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Enter an invite code to access your classroom",
                  style: TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final code = await showJoinSubjectSheet(context);
                      if (code == null || code.isEmpty) return;

                      if (!context.mounted) return;

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Joining..."),
                          content: const SizedBox(
                            height: 50,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      );

                      final api = ref.read(apiProvider);
                      try {
                        final result = await api.joinSubjectByCode(code);

                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading dialog

                        // Success
                        ref.invalidate(subjectsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("✓ Joined ${result.name} successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading dialog

                        String errorMsg = "Invalid or expired invite code";
                        if (e.toString().contains("404")) {
                          errorMsg = "Class not found - check the code";
                        } else if (e.toString().contains("401")) {
                          errorMsg = "Authentication error - please login again";
                        } else if (e.toString().contains("400")) {
                          errorMsg = "Invalid code format";
                        }

                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Failed to Join"),
                            content: Text(errorMsg),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text("Join", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSubjectTile extends StatelessWidget {
  final Subject subject;
  const _StudentSubjectTile({required this.subject});

  IconData _iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains("math")) return Icons.calculate_rounded;
    if (n.contains("chem")) return Icons.science_rounded;
    if (n.contains("history")) return Icons.history_edu_rounded;
    if (n.contains("english") || n.contains("literature")) return Icons.language_rounded;
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubjectScreen(subject: subject)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEFEFF6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForName(subject.name), color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF121118)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Tap to view lectures",
                    style: TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF67608A)),
          ],
        ),
      ),
    );
  }
}

/// ---------------- EMPTY / ERROR / HELPERS ----------------

class _EmptySubjects extends ConsumerWidget {
  final Role? role;
  const _EmptySubjects({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = "No subjects yet";
    final subtitle =
        "Your professional classroom is ready. Start by creating a new subject or join one using a class code.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 90),
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
                    AppTheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.10)),
              ),
              child: Center(
                child: Icon(Icons.auto_stories_rounded, size: 120, color: AppTheme.primary.withOpacity(0.35)),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF121118))),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF67608A), fontSize: 14, height: 1.35, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            if (role == Role.teacher)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    // Teacher can create subject using FAB; keep this for UX parity.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Use + button to create a subject")),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Create Subject", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: Color(0xFFEFEFF6)),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF121118),
                  ),
                  onPressed: () async {
                    final code = await showJoinSubjectSheet(context);
                    if (code == null || code.isEmpty) return;

                    if (!context.mounted) return;

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const AlertDialog(
                        title: Text("Joining..."),
                        content: SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    );

                    final api = ref.read(apiProvider);
                    try {
                      final result = await api.joinSubjectByCode(code);

                      if (!context.mounted) return;
                      Navigator.pop(context); // Close loading dialog

                      // Success
                      ref.invalidate(subjectsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("✓ Joined ${result.name} successfully!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context); // Close loading dialog

                      String errorMsg = "Invalid or expired invite code";
                      if (e.toString().contains("404")) {
                        errorMsg = "Class not found - check the code";
                      } else if (e.toString().contains("401")) {
                        errorMsg = "Authentication error - please login again";
                      } else if (e.toString().contains("400")) {
                        errorMsg = "Invalid code format";
                      }

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Failed to Join"),
                          content: Text(errorMsg),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text("Join a Class", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF67608A),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          "Something went wrong.\n$message",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF67608A), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final int tab;
  const _PlaceholderTab({required this.tab});

  @override
  Widget build(BuildContext context) {
    final label = switch (tab) {
      1 => "Library (UI placeholder)",
      2 => "Students (UI placeholder)",
      3 => "Settings (UI placeholder)",
      _ => "Home",
    };

    return Center(
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF67608A)),
      ),
    );
  }
}
