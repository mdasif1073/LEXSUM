import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api.dart';
import 'auth_provider.dart';

final apiProvider = Provider<ApiClient>((ref) {
  // Get current user's token from auth state
  final auth = ref.watch(authProvider);
  return ApiClient(token: auth.accessToken);
});
