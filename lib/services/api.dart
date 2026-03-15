import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../models/student.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static String get baseUrl => ApiConfig.baseUrl;
  
  final String? token;
  late final LectureApi lectureApi;
  late final SubjectApi subjectApi;
  late final PhotoApi photoApi;
  late final QuizApi quizApi;

  ApiClient({this.token}) {
    lectureApi = LectureApi(client: this);
    subjectApi = SubjectApi(client: this);
    photoApi = PhotoApi(client: this);
    quizApi = QuizApi(client: this);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    try {
      if (kDebugMode) debugPrint('[API] GET $baseUrl$endpoint');
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(),
      );
      if (kDebugMode) debugPrint('[API] GET $baseUrl$endpoint -> ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      if (kDebugMode) debugPrint('[API] POST $baseUrl$endpoint');
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(),
        body: jsonEncode(body ?? <String, dynamic>{}),
      );
      if (kDebugMode) debugPrint('[API] POST $baseUrl$endpoint -> ${response.statusCode}');
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> postFile(
    String endpoint, {
    required List<int> fileBytes,
    required String fileName,
    String fieldName = 'file',
  }) async {
    try {
      if (kDebugMode) debugPrint('[API] POST-MULTIPART $baseUrl$endpoint');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (kDebugMode) debugPrint('[API] POST-MULTIPART $baseUrl$endpoint -> ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(responseBody);
      } else {
        final error = _parseErrorBody(responseBody, response.statusCode);
        throw ApiException(error, statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      final error = _parseError(response);
      throw ApiException(error, statusCode: response.statusCode);
    }
  }

  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return json['detail'] ?? 'Error: ${response.statusCode}';
    } catch (_) {
      return 'Error: ${response.statusCode}';
    }
  }

  String _parseErrorBody(String body, int statusCode) {
    try {
      final json = jsonDecode(body);
      return json['detail'] ?? 'Error: $statusCode';
    } catch (_) {
      if (body.trim().isNotEmpty) return body.trim();
      return 'Error: $statusCode';
    }
  }

  // Convenience method to create a lecture
  Future<LectureOut> createLecture({
    required String subjectId,
    DateTime? lectureAt,
  }) async {
    return lectureApi.createLecture(subjectId, lectureAt: lectureAt);
  }

  // Subject convenience methods
  Future<SubjectOut> createSubject(String name) async {
    return subjectApi.createSubject(name: name);
  }

  Future<SubjectOut> joinSubjectByCode(String code) async {
    return subjectApi.joinSubject(inviteCode: code);
  }

  Future<List<SubjectOut>> listSubjects() async {
    return subjectApi.listSubjects();
  }

  Future<SubjectOut> getSubject(String id) async {
    return subjectApi.getSubject(id);
  }

  // Lecture convenience methods
  Future<List<LectureOut>> listLectures(String subjectId) async {
    return lectureApi.listLectures(subjectId);
  }

  Future<LectureDetailOut> getLectureDetail(String lectureId) async {
    return lectureApi.getLectureDetail(lectureId);
  }

  Future<Map<String, dynamic>> uploadAudio(
    String lectureId, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    return lectureApi.uploadAudio(lectureId, fileBytes: fileBytes, fileName: fileName);
  }

  // Photo convenience methods
  Future<PhotoOut> addNotePhoto(
    String lectureId,
    String filePath,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return photoApi.uploadPhoto(lectureId, fileBytes: bytes, fileName: file.path.split('/').last);
  }

  Future<List<Map<String, String>>> listNotePhotos(String lectureId) async {
    final photos = await photoApi.getPhotos(lectureId);
    return photos
        .map((p) => <String, String>{
              'id': p.id,
              'url': p.signedUrl,
              'by': p.uploadedByName ?? '',
            })
        .toList();
  }

  // Quiz convenience methods
  Future<QuizOut> getLatestQuiz(String lectureId) async {
    return quizApi.getLatestQuiz(lectureId);
  }

  Future<QuizAttemptOut> submitQuizAttempt(String quizId, {required Map<String, String> answers}) async {
    return quizApi.submitAttempt(quizId, answers: answers);
  }

  Future<List<QuizAttemptOut>> myQuizAttempts(String quizId) async {
    return quizApi.myAttempts(quizId);
  }

  Future<QuizTeacherStatsOut> getQuizTeacherStats(String lectureId) async {
    return quizApi.getTeacherStats(lectureId);
  }

  // Placeholder methods for now (not in API yet)
  Future<List<Student>> listStudents(String subjectId) async {
    final response = await subjectApi.listStudents(subjectId);
    return response
        .map((s) => Student(
              id: s.id,
              name: s.name,
              isRepresentative: s.isRepresentative,
            ))
        .toList();
  }

  Future<void> toggleRepresentative(String subjectId, String userId) async {
    await subjectApi.toggleRepresentative(subjectId, userId);
  }
}

// Subject API
class SubjectOut {
  final String id;
  final String name;
  final String? inviteCode;
  final bool isOwner;
  final String? roleInSubject;
  final DateTime createdAt;

  SubjectOut({
    required this.id,
    required this.name,
    this.inviteCode,
    required this.isOwner,
    this.roleInSubject,
    required this.createdAt,
  });

  factory SubjectOut.fromJson(Map<String, dynamic> json) {
    return SubjectOut(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String?,
      isOwner: json['is_owner'] as bool? ?? false,
      roleInSubject: json['role_in_subject'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SubjectApi {
  final ApiClient client;

  SubjectApi({required this.client});

  /// Create a new subject (teacher only)
  Future<SubjectOut> createSubject({required String name}) async {
    final response = await client.post(
      '/subjects',
      body: {'name': name},
    );
    return SubjectOut.fromJson(response);
  }

  /// Join a subject with invite code
  Future<SubjectOut> joinSubject({required String inviteCode}) async {
    final response = await client.post(
      '/subjects/join',
      body: {'invite_code': inviteCode},
    );
    return SubjectOut.fromJson(response);
  }

  /// Get all subjects for current user
  Future<List<SubjectOut>> listSubjects() async {
    final response = await client.get('/subjects');
    return (response as List).map((e) => SubjectOut.fromJson(e)).toList();
  }

  /// Get subject details
  Future<SubjectOut> getSubject(String subjectId) async {
    final response = await client.get('/subjects/$subjectId');
    return SubjectOut.fromJson(response);
  }

  /// List students in a subject
  Future<List<StudentOut>> listStudents(String subjectId) async {
    final response = await client.get('/subjects/$subjectId/students');
    return (response as List).map((e) => StudentOut.fromJson(e)).toList();
  }

  /// Toggle representative role for a student
  Future<void> toggleRepresentative(String subjectId, String userId) async {
    await client.post('/subjects/$subjectId/reps/$userId', body: {});
  }
}

// Lecture API
class LectureOut {
  final String id;
  final String subjectId;
  final DateTime lectureAt;
  final String status;
  final String? preview;
  final DateTime createdAt;

  LectureOut({
    required this.id,
    required this.subjectId,
    required this.lectureAt,
    required this.status,
    this.preview,
    required this.createdAt,
  });

  factory LectureOut.fromJson(Map<String, dynamic> json) {
    return LectureOut(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      lectureAt: DateTime.parse(json['lecture_at'] as String),
      status: json['status'] as String,
      preview: json['preview'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class LectureDetailOut {
  final String id;
  final String subjectId;
  final DateTime lectureAt;
  final String status;
  final String? transcriptText;
  final String? notesMd;
  final String? summaryMd;
  final DateTime createdAt;

  LectureDetailOut({
    required this.id,
    required this.subjectId,
    required this.lectureAt,
    required this.status,
    this.transcriptText,
    this.notesMd,
    this.summaryMd,
    required this.createdAt,
  });

  factory LectureDetailOut.fromJson(Map<String, dynamic> json) {
    return LectureDetailOut(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      lectureAt: DateTime.parse(json['lecture_at'] as String),
      status: json['status'] as String,
      transcriptText: json['transcript_text'] as String?,
      notesMd: json['notes_md'] as String?,
      summaryMd: json['summary_md'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class LectureApi {
  final ApiClient client;

  LectureApi({required this.client});

  /// Create a new lecture
  Future<LectureOut> createLecture(String subjectId, {DateTime? lectureAt}) async {
    final body = <String, dynamic>{};
    if (lectureAt != null) {
      body['lecture_at'] = lectureAt.toIso8601String();
    }
    
    final response = await client.post(
      '/subjects/$subjectId/lectures',
      body: body,
    );
    return LectureOut.fromJson(response);
  }

  /// Get lectures for a subject
  Future<List<LectureOut>> listLectures(String subjectId) async {
    final response = await client.get('/subjects/$subjectId/lectures');
    return (response as List).map((e) => LectureOut.fromJson(e)).toList();
  }

  /// Get lecture details
  Future<LectureDetailOut> getLectureDetail(String lectureId) async {
    final response = await client.get('/lectures/$lectureId');
    return LectureDetailOut.fromJson(response);
  }

  /// Upload audio file for a lecture
  Future<Map<String, dynamic>> uploadAudio(
    String lectureId, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final response = await client.postFile(
      '/lectures/$lectureId/audio',
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return response as Map<String, dynamic>;
  }
}

// Photo API
class PhotoOut {
  final String id;
  final String lectureId;
  final String objectPath;
  final String signedUrl;
  final String? uploadedByName;
  final DateTime createdAt;

  PhotoOut({
    required this.id,
    required this.lectureId,
    required this.objectPath,
    required this.signedUrl,
    this.uploadedByName,
    required this.createdAt,
  });

  factory PhotoOut.fromJson(Map<String, dynamic> json) {
    return PhotoOut(
      id: json['id'] as String,
      lectureId: json['lecture_id'] as String,
      objectPath: json['object_path'] as String,
      signedUrl: json['signed_url'] as String,
      uploadedByName: json['uploaded_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PhotoApi {
  final ApiClient client;

  PhotoApi({required this.client});

  /// Upload lecture photo (image note)
  Future<PhotoOut> uploadPhoto(
    String lectureId, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final response = await client.postFile(
      '/lectures/$lectureId/photos',
      fileBytes: fileBytes,
      fileName: fileName,
      fieldName: 'files',
    );
    if (response is List && response.isNotEmpty) {
      return PhotoOut.fromJson(response.first as Map<String, dynamic>);
    }
    if (response is Map<String, dynamic>) {
      return PhotoOut.fromJson(response);
    }
    throw ApiException('Unexpected response format');
  }

  /// Get photos for a lecture
  Future<List<PhotoOut>> getPhotos(String lectureId) async {
    final response = await client.get('/lectures/$lectureId/photos');
    return (response as List).map((e) => PhotoOut.fromJson(e)).toList();
  }
}

class QuizOut {
  final String id;
  final String lectureId;
  final String quizJson;
  final DateTime createdAt;

  QuizOut({
    required this.id,
    required this.lectureId,
    required this.quizJson,
    required this.createdAt,
  });

  factory QuizOut.fromJson(Map<String, dynamic> json) {
    return QuizOut(
      id: json['id'] as String,
      lectureId: json['lecture_id'] as String,
      quizJson: json['quiz_json'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class QuizAttemptOut {
  final String id;
  final String quizId;
  final String userId;
  final int score;
  final String answersJson;
  final DateTime createdAt;

  QuizAttemptOut({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.score,
    required this.answersJson,
    required this.createdAt,
  });

  factory QuizAttemptOut.fromJson(Map<String, dynamic> json) {
    return QuizAttemptOut(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      userId: json['user_id'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      answersJson: json['answers_json'] as String? ?? '{}',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class QuizTeacherStatsOut {
  final String lectureId;
  final String? quizId;
  final int totalStudents;
  final int attemptedStudents;
  final int notAttemptedStudents;
  final double? averageScore;
  final DateTime? latestAttemptAt;

  QuizTeacherStatsOut({
    required this.lectureId,
    required this.quizId,
    required this.totalStudents,
    required this.attemptedStudents,
    required this.notAttemptedStudents,
    required this.averageScore,
    required this.latestAttemptAt,
  });

  factory QuizTeacherStatsOut.fromJson(Map<String, dynamic> json) {
    return QuizTeacherStatsOut(
      lectureId: json['lecture_id'] as String,
      quizId: json['quiz_id'] as String?,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      attemptedStudents: (json['attempted_students'] as num?)?.toInt() ?? 0,
      notAttemptedStudents: (json['not_attempted_students'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble(),
      latestAttemptAt: json['latest_attempt_at'] == null
          ? null
          : DateTime.parse(json['latest_attempt_at'] as String),
    );
  }
}

class QuizApi {
  final ApiClient client;

  QuizApi({required this.client});

  Future<QuizOut> getLatestQuiz(String lectureId) async {
    final response = await client.get('/lectures/$lectureId/quizzes/latest');
    return QuizOut.fromJson(response as Map<String, dynamic>);
  }

  Future<QuizAttemptOut> submitAttempt(String quizId, {required Map<String, String> answers}) async {
    final response = await client.post(
      '/quizzes/$quizId/attempt',
      body: {'answers': answers},
    );
    return QuizAttemptOut.fromJson(response as Map<String, dynamic>);
  }

  Future<List<QuizAttemptOut>> myAttempts(String quizId) async {
    final response = await client.get('/quizzes/$quizId/attempts/me');
    return (response as List).map((e) => QuizAttemptOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<QuizTeacherStatsOut> getTeacherStats(String lectureId) async {
    final response = await client.get('/lectures/$lectureId/quizzes/stats');
    return QuizTeacherStatsOut.fromJson(response as Map<String, dynamic>);
  }
}

class StudentOut {
  final String id;
  final String name;
  final bool isRepresentative;

  StudentOut({
    required this.id,
    required this.name,
    required this.isRepresentative,
  });

  factory StudentOut.fromJson(Map<String, dynamic> json) {
    return StudentOut(
      id: json['id'] as String,
      name: json['name'] as String,
      isRepresentative: json['is_representative'] as bool? ?? false,
    );
  }
}
