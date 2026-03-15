import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/api_config.dart';

void main() {
  // Helpful startup log to confirm which API base URL the app is using.
  // Safe in debug; no sensitive data included.
  // ignore: avoid_print
  print('[API] baseUrl=${ApiConfig.baseUrl}');
  runApp(const ProviderScope(child: ClassroomApp()));
}
