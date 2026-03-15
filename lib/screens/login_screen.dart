import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import '../core/theme.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return _LoginFormScreen(
      onBackTap: () => Navigator.maybePop(context),
    );
  }
}

class _RoleSelectionScreen extends StatelessWidget {
  final VoidCallback onTeacherTap;
  final VoidCallback onStudentTap;

  const _RoleSelectionScreen({
    required this.onTeacherTap,
    required this.onStudentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          color: AppTheme.backgroundLight,
          child: Column(
            children: [
              // Hero section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _HeroCard(
                  onPrimary: Colors.white,
                  onPrimarySoft: Colors.white.withOpacity(0.90),
                ),
              ),

              // Role list
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select your role",
                    style: TextStyle(
                      color: const Color(0xFF121118),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    _RoleCard(
                      title: "Teacher",
                      subtitle: "Create subjects, invite students, record lectures",
                      icon: Icons.school_rounded,
                      onTap: onTeacherTap,
                      primary: AppTheme.primary,
                      chevronColor: const Color(0xFF67608A),
                      borderColor: const Color(0xFFF0F0F6),
                      cardColor: Colors.white,
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      title: "Student",
                      subtitle: "Join classes, read notes, take quizzes",
                      icon: Icons.person_rounded,
                      onTap: onStudentTap,
                      primary: AppTheme.primary,
                      chevronColor: const Color(0xFF67608A),
                      borderColor: const Color(0xFFF0F0F6),
                      cardColor: Colors.white,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  "OFFLINE CLASSROOM ASSISTANT",
                  style: TextStyle(
                    color: const Color(0xFF67608A).withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginFormScreen extends ConsumerWidget {
  final VoidCallback onBackTap;

  const _LoginFormScreen({required this.onBackTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LoginFormContent(onBackTap: onBackTap);
  }
}

class _LoginFormContent extends ConsumerStatefulWidget {
  final VoidCallback onBackTap;

  const _LoginFormContent({required this.onBackTap});

  @override
  ConsumerState<_LoginFormContent> createState() => __LoginFormContentState();
}

class __LoginFormContentState extends ConsumerState<_LoginFormContent> {
  bool isTeacher = true;
  late TextEditingController emailOrNameController;
  late TextEditingController passwordController;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    emailOrNameController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailOrNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            color: AppTheme.backgroundLight,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          color: Color(0xFF121118),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Role toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => isTeacher = true),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isTeacher ? AppTheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Teacher',
                                    style: TextStyle(
                                      color: isTeacher ? Colors.white : const Color(0xFF121118),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => isTeacher = false),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !isTeacher ? AppTheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Student',
                                    style: TextStyle(
                                      color: !isTeacher ? Colors.white : const Color(0xFF121118),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email/Name field
                      Text(
                        'Email or Name',
                        style: const TextStyle(
                          color: Color(0xFF121118),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailOrNameController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your email or name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password field
                      Text(
                        'Password',
                        style: const TextStyle(
                          color: Color(0xFF121118),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() => obscurePassword = !obscurePassword);
                              },
                              child: Icon(
                                obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: const Color(0xFF67608A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (authState.error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            authState.error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (authState.error != null) const SizedBox(height: 16),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  if (emailOrNameController.text.isEmpty || passwordController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please fill all fields')),
                                    );
                                    return;
                                  }

                                  try {
                                    if (isTeacher) {
                                      await ref.read(authProvider.notifier).loginTeacher(
                                        emailOrName: emailOrNameController.text.trim(),
                                        password: passwordController.text,
                                      );
                                    } else {
                                      await ref.read(authProvider.notifier).loginStudent(
                                        emailOrName: emailOrNameController.text.trim(),
                                        password: passwordController.text,
                                      );
                                    }
                                    if (mounted) {
                                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                                    }
                                  } catch (e) {
                                    // Error is handled in state
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sign up button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignupScreen(
                                  role: isTeacher ? Role.teacher : Role.student,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppTheme.primary),
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color onPrimary;
  final Color onPrimarySoft;

  const _HeroCard({
    required this.onPrimary,
    required this.onPrimarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F31F5),
            Color(0xFF330DF2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -34,
            right: -34,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -18,
            left: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.school_rounded, color: onPrimary, size: 48),
                ),
                const SizedBox(height: 18),
                Text(
                  "Classroom",
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    "Summaries & quizzes from offline lectures",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onPrimarySoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  final Color primary;
  final Color chevronColor;
  final Color borderColor;
  final Color cardColor;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.primary,
    required this.chevronColor,
    required this.borderColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF121118),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF67608A),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: chevronColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
