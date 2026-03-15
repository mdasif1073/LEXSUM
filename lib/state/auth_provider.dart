import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_api.dart';

enum Role { teacher, student }

class AuthState {
  final bool isLoggedIn;
  final Role? role;
  final String? displayName;
  final String? email;
  final String? userId;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const AuthState({
    required this.isLoggedIn,
    this.role,
    this.displayName,
    this.email,
    this.userId,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    Role? role,
    String? displayName,
    String? email,
    String? userId,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  static const loggedOut = AuthState(isLoggedIn: false);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState.loggedOut);

  Future<void> _loginAndLoadProfile({
    required Role role,
    required String emailOrName,
    required String password,
  }) async {
    final auth = role == Role.teacher
        ? await AuthApi.loginTeacher(emailOrName: emailOrName, password: password)
        : await AuthApi.loginStudent(emailOrName: emailOrName, password: password);

    // Fetch profile for name/id
    final me = await AuthApi.me(token: auth.accessToken);

    state = AuthState(
      isLoggedIn: true,
      role: role,
      displayName: me.name,
      email: me.email,
      userId: me.id,
      accessToken: auth.accessToken,
      isLoading: false,
    );
  }

  /// Sign up as teacher
  Future<void> signupTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthApi.signupTeacher(
        name: name,
        email: email,
        password: password,
      );
      await _loginAndLoadProfile(role: Role.teacher, emailOrName: email, password: password);
    } on AuthApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Sign up as student
  Future<void> signupStudent({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthApi.signupStudent(
        name: name,
        email: email,
        password: password,
      );
      await _loginAndLoadProfile(role: Role.student, emailOrName: email, password: password);
    } on AuthApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Login as teacher
  Future<void> loginTeacher({
    required String emailOrName,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _loginAndLoadProfile(role: Role.teacher, emailOrName: emailOrName, password: password);
    } on AuthApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Login as student
  Future<void> loginStudent({
    required String emailOrName,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _loginAndLoadProfile(role: Role.student, emailOrName: emailOrName, password: password);
    } on AuthApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Logout
  void logout() {
    state = AuthState.loggedOut;
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
