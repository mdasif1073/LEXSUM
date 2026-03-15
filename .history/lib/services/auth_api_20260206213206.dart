import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class AuthApiException implements Exception {
  final String message;
  AuthApiException(this.message);

  @override
  String toString() => message;
}

class AuthResponse {
  final String accessToken;
  final String tokenType;

  AuthResponse({required this.accessToken, required this.tokenType});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Handle access_token safely - it might come back in different formats
    final accessToken = json['access_token'];
    final token = accessToken is String ? accessToken : accessToken.toString();
    
    return AuthResponse(
      accessToken: token,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

class UserResponse {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime? createdAt;

  UserResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}

class AuthApi {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Sign up a new teacher
  static Future<UserResponse> signupTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    return _signup(name: name, email: email, password: password, role: 'teacher');
  }

  /// Sign up a new student
  static Future<UserResponse> signupStudent({
    required String name,
    required String email,
    required String password,
  }) async {
    return _signup(name: name, email: email, password: password, role: 'student');
  }

  /// Internal signup method
  static Future<UserResponse> _signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final endpoint = role == 'teacher' ? '/auth/register/teacher' : '/auth/register/student';
    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      });
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          return UserResponse.fromJson(json);
        } else {
          throw AuthApiException('Unexpected response format');
        }
      } else if (response.statusCode == 409) {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          throw AuthApiException(error['detail'] as String? ?? 'Email already registered');
        } catch (e) {
          throw AuthApiException('Email already registered');
        }
      } else if (response.statusCode == 422) {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          if (error['detail'] is List) {
            final details = error['detail'] as List;
            final firstError = details.isNotEmpty ? details[0] : null;
            if (firstError is Map && firstError['msg'] != null) {
              final errorMsg = firstError['msg'] as String;
              throw AuthApiException(errorMsg);
            }
          }
          throw AuthApiException('Invalid input: ${response.statusCode}');
        } on AuthApiException {
          rethrow;
        } catch (e) {
          throw AuthApiException('Validation error: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          if (error is Map<String, dynamic>) {
            throw AuthApiException(error['detail'] as String? ?? 'Signup failed');
          } else {
            throw AuthApiException('Signup failed: ${response.statusCode}');
          }
        } catch (e) {
          throw AuthApiException('Signup failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw AuthApiException('Signup error: $e');
    }
  }

  /// Login as teacher
  static Future<AuthResponse> loginTeacher({
    required String emailOrName,
    required String password,
  }) async {
    return _login(emailOrName: emailOrName, password: password, role: 'teacher');
  }

  /// Login as student
  static Future<AuthResponse> loginStudent({
    required String emailOrName,
    required String password,
  }) async {
    return _login(emailOrName: emailOrName, password: password, role: 'student');
  }

  /// Internal login method
  static Future<AuthResponse> _login({
    required String emailOrName,
    required String password,
    required String role,
  }) async {
    final endpoint = role == 'teacher' ? '/auth/login/json/teacher' : '/auth/login/json/student';
    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final body = jsonEncode({
        'email': emailOrName,
        'password': password,
      });
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          return AuthResponse.fromJson(json);
        } else {
          throw AuthApiException('Unexpected response format');
        }
      } else if (response.statusCode == 401) {
        throw AuthApiException('Invalid email/name or password');
      } else if (response.statusCode == 403) {
        throw AuthApiException('This account is not registered as a ${role}');
      } else if (response.statusCode == 422) {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          if (error['detail'] is List) {
            final details = error['detail'] as List;
            final firstError = details.isNotEmpty ? details[0] : null;
            if (firstError is Map && firstError['msg'] != null) {
              final errorMsg = firstError['msg'] as String;
              throw AuthApiException(errorMsg);
            }
          }
          throw AuthApiException('Invalid input: ${response.statusCode}');
        } on AuthApiException {
          rethrow;
        } catch (e) {
          throw AuthApiException('Validation error: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          if (error is Map<String, dynamic>) {
            throw AuthApiException(error['detail'] as String? ?? 'Login failed');
          } else {
            throw AuthApiException('Login failed: ${response.statusCode}');
          }
        } catch (e) {
          throw AuthApiException('Login failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw AuthApiException('Login error: $e');
    }
  }

  /// Get current user from token
  static Future<UserResponse> me({required String token}) async {
    final url = Uri.parse('$baseUrl/auth/me');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          return UserResponse.fromJson(json);
        } else {
          throw AuthApiException('Unexpected response format');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          if (error is Map<String, dynamic>) {
            throw AuthApiException(error['detail'] as String? ?? 'Failed to load profile');
          } else {
            throw AuthApiException('Failed to load profile: ${response.statusCode}');
          }
        } catch (e) {
          throw AuthApiException('Failed to load profile: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw AuthApiException('Profile error: $e');
    }
  }
}
