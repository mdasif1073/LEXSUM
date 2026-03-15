import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api.dart';
import 'auth_provider.dart';

final latestQuizProvider = FutureProvider.family<QuizOut?, String>((ref, lectureId) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken;
  if ((token ?? '').isEmpty) throw Exception('Not authenticated');

  final api = ApiClient(token: token);
  try {
    return await api.getLatestQuiz(lectureId);
  } on ApiException catch (e) {
    if (e.statusCode == 404) return null;
    rethrow;
  }
});

final myQuizAttemptsProvider = FutureProvider.family<List<QuizAttemptOut>, String>((ref, quizId) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken;
  if ((token ?? '').isEmpty) throw Exception('Not authenticated');

  final api = ApiClient(token: token);
  return api.myQuizAttempts(quizId);
});

final quizTeacherStatsProvider = FutureProvider.family<QuizTeacherStatsOut, String>((ref, lectureId) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken;
  if ((token ?? '').isEmpty) throw Exception('Not authenticated');

  final api = ApiClient(token: token);
  return api.getQuizTeacherStats(lectureId);
});
