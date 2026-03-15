import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import '../core/theme.dart';

class SignupScreen extends ConsumerWidget {
  final Role role;

  const SignupScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            color: AppTheme.backgroundLight,
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: const Color(0xFF121118),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        role == Role.teacher ? 'Teacher Sign Up' : 'Student Sign Up',
                        style: const TextStyle(
                          color: Color(0xFF121118),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SignupForm(role: role),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupForm extends ConsumerStatefulWidget {
  final Role role;

  const _SignupForm({required this.role});

  @override
  ConsumerState<_SignupForm> createState() => __SignupFormState();
}

class __SignupFormState extends ConsumerState<_SignupForm> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          Text(
            'Full Name',
            style: const TextStyle(
              color: Color(0xFF121118),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            validator: validateName,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 18),

          // Email field
          Text(
            'Email',
            style: const TextStyle(
              color: Color(0xFF121118),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            validator: validateEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your email',
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
            validator: validatePassword,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password (min 6 characters)',
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
          const SizedBox(height: 18),

          // Confirm Password field
          Text(
            'Confirm Password',
            style: const TextStyle(
              color: Color(0xFF121118),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: confirmPasswordController,
            validator: validateConfirmPassword,
            obscureText: obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Confirm your password',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => obscureConfirmPassword = !obscureConfirmPassword);
                  },
                  child: Icon(
                    obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
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

          // Sign up button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      // Validate all fields
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          passwordController.text.isEmpty ||
                          confirmPasswordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }

                      // Validate email format
                      if (validateEmail(emailController.text) != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(validateEmail(emailController.text)!)),
                        );
                        return;
                      }

                      // Validate password
                      if (validatePassword(passwordController.text) != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(validatePassword(passwordController.text)!)),
                        );
                        return;
                      }

                      // Validate password match
                      if (validateConfirmPassword(confirmPasswordController.text) != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(validateConfirmPassword(confirmPasswordController.text)!)),
                        );
                        return;
                      }

                      try {
                        if (widget.role == Role.teacher) {
                          await ref.read(authProvider.notifier).signupTeacher(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                          );
                        } else {
                          await ref.read(authProvider.notifier).signupStudent(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                          );
                        }
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      } catch (e) {
                        // Error is handled in state, no need to show again
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
                  : Text(
                      'Sign Up as ${widget.role == Role.teacher ? 'Teacher' : 'Student'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Already have account?
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Color(0xFF67608A),
                    fontSize: 14,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/login'),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
