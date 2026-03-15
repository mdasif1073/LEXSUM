import 'package:flutter/material.dart';
import '../core/theme.dart';

class CreateSubjectResult {
  final String subjectName;
  final String? roomOrCode;

  const CreateSubjectResult({
    required this.subjectName,
    this.roomOrCode,
  });
}

Future<CreateSubjectResult?> showCreateSubjectSheet(BuildContext context) {
  return showModalBottomSheet<CreateSubjectResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateSubjectSheet(),
  );
}

class _CreateSubjectSheet extends StatefulWidget {
  const _CreateSubjectSheet();

  @override
  State<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<_CreateSubjectSheet> {
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.black.withOpacity(0.40), // backdrop
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 48,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4, bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCDCE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 10),
                        child: Text(
                          "Create subject",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF121117),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      _LabeledField(
                        label: "Subject name",
                        controller: _nameCtrl,
                        hint: "e.g., Operating Systems",
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),

                      _LabeledField(
                        label: "Room / Code (Optional)",
                        controller: _roomCtrl,
                        hint: "e.g., Room 402",
                        autofocus: false,
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                foregroundColor: const Color(0xFF121117),
                              ),
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                                shadowColor: scheme.primary.withOpacity(0.30),
                              ),
                              onPressed: () {
                                final name = _nameCtrl.text.trim();
                                if (name.isEmpty) return;

                                Navigator.pop(
                                  context,
                                  CreateSubjectResult(
                                    subjectName: name,
                                    roomOrCode: _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Create",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
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

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.autofocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF121117),
            ),
          ),
        ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCDCE5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCDCE5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.85), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
