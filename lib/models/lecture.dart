enum LectureStatus { uploaded, processing, ready, failed }

class Lecture {
  final String id;
  final String subjectId;
  final DateTime dateTime;
  final LectureStatus status;

  // what we show in UI
  final String englishSummaryPreview;
  // optional nicer title or derived fields to satisfy UI expectations
  final String? title;
  final String? subjectName;

  const Lecture({
    required this.id,
    required this.subjectId,
    required this.dateTime,
    required this.status,
    required this.englishSummaryPreview,
    this.title,
    this.subjectName,
  });

  String get summaryPreview => englishSummaryPreview;
}
