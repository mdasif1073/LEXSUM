import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

Future<void> showInviteCodeSheet(
  BuildContext context, {
  required String subjectName,
  required String code,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InviteCodeSheet(subjectName: subjectName, code: code),
  );
}

class _InviteCodeSheet extends StatelessWidget {
  final String subjectName;
  final String code;

  const _InviteCodeSheet({
    required this.subjectName,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(0.40),
        child: Align(
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // prevent closing when tapping the card
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 34,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          width: 40,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCDCE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "INVITE CODE • $subjectName",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF656487),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          code,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF121117),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Copy pill button
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Copied to clipboard")),
                            );
                          },
                          style: TextButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: AppTheme.primary.withOpacity(0.10),
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.content_copy_rounded, size: 18),
                          label: const Text(
                            "Copy code",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "Share this code with your students so they can join your classroom.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const StadiumBorder(),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Done",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
