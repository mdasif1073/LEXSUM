import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../services/api.dart';
import 'app_services.dart';
import 'auth_provider.dart';

final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final auth = ref.watch(authProvider);
  
  if ((auth.accessToken ?? '').isEmpty) {
    return [];
  }

  final client = ApiClient(token: auth.accessToken);
  final api = SubjectApi(client: client);
  
  try {
    final subjects = await api.listSubjects();
    return subjects
        .map((s) => Subject(
              id: s.id,
              name: s.name,
              code: s.inviteCode,
              isOwner: s.isOwner,
              roleInSubject: s.roleInSubject,
            ))
        .toList();
  } catch (e) {
    throw Exception('Failed to load subjects: $e');
  }
});

final createSubjectProvider = FutureProvider.family<Subject, String>((ref, name) async {
  final auth = ref.watch(authProvider);
  
  if ((auth.accessToken ?? '').isEmpty) {
    throw Exception('Not authenticated');
  }

  final client = ApiClient(token: auth.accessToken);
  final api = SubjectApi(client: client);
  
  final result = await api.createSubject(name: name);
  return Subject(
    id: result.id,
    name: result.name,
    code: result.inviteCode,
    isOwner: result.isOwner,
    roleInSubject: result.roleInSubject,
  );
});

final joinSubjectProvider = FutureProvider.family<Subject, String>((ref, code) async {
  final auth = ref.watch(authProvider);
  
  if ((auth.accessToken ?? '').isEmpty) {
    throw Exception('Not authenticated');
  }

  final client = ApiClient(token: auth.accessToken);
  final api = SubjectApi(client: client);
  
  final result = await api.joinSubject(inviteCode: code);
  return Subject(
    id: result.id,
    name: result.name,
    code: result.inviteCode,
    isOwner: result.isOwner,
    roleInSubject: result.roleInSubject,
  );
});
