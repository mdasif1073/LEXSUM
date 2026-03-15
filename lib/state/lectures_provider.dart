import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lecture.dart';
import '../services/api.dart';
import 'auth_provider.dart';

final lecturesProvider = FutureProvider.family<List<Lecture>, String>((ref, subjectId) async {
  final auth = ref.watch(authProvider);
  
  if ((auth.accessToken ?? '').isEmpty) {
    return [];
  }

  final client = ApiClient(token: auth.accessToken);
  final api = LectureApi(client: client);
  
  try {
    final lectures = await api.listLectures(subjectId);
    return lectures
        .map((l) => Lecture(
              id: l.id,
              subjectId: l.subjectId,
              dateTime: l.lectureAt,
              status: _parseStatus(l.status),
              englishSummaryPreview: l.preview ?? 'No summary yet',
              title: 'Lecture',
              subjectName: 'Subject',
            ))
        .toList();
  } catch (e) {
    throw Exception('Failed to load lectures: $e');
  }
});

final lectureDetailProvider = FutureProvider.family<Lecture, String>((ref, lectureId) async {
  final auth = ref.watch(authProvider);
  
  if ((auth.accessToken ?? '').isEmpty) {
    throw Exception('Not authenticated');
  }

  final client = ApiClient(token: auth.accessToken);
  final api = LectureApi(client: client);
  
  final detail = await api.getLectureDetail(lectureId);
  return Lecture(
    id: detail.id,
    subjectId: detail.subjectId,
    dateTime: detail.lectureAt,
    status: _parseStatus(detail.status),
    englishSummaryPreview: detail.summaryMd ?? detail.notesMd ?? 'Processing...',
    title: 'Lecture',
    subjectName: 'Subject',
  );
});

final lectureDetailOutProvider = FutureProvider.family<LectureDetailOut, String>((ref, lectureId) async {
  final auth = ref.watch(authProvider);

  if ((auth.accessToken ?? '').isEmpty) {
    throw Exception('Not authenticated');
  }

  final api = ApiClient(token: auth.accessToken);
  return api.getLectureDetail(lectureId);
});

LectureStatus _parseStatus(String status) {
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
