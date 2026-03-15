import 'package:flutter/material.dart';
import '../models/lecture.dart';

class StatusChip extends StatelessWidget {
  final LectureStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final String label;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case LectureStatus.uploaded:
        label = "Uploaded";
        bg = scheme.primary.withOpacity(0.10);
        fg = scheme.primary;
        break;
      case LectureStatus.processing:
        label = "Processing";
        bg = Colors.orange.withOpacity(0.14);
        fg = Colors.orange.shade900;
        break;
      case LectureStatus.ready:
        label = "Ready";
        bg = Colors.green.withOpacity(0.14);
        fg = Colors.green.shade800;
        break;
      case LectureStatus.failed:
        label = "Failed";
        bg = Colors.red.withOpacity(0.14);
        fg = Colors.red.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: fg),
      ),
    );
  }
}
