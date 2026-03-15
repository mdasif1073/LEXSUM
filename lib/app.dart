import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'state/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class ClassroomApp extends ConsumerWidget {
  const ClassroomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Classroom',
      theme: AppTheme.light(),
      home: session.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
