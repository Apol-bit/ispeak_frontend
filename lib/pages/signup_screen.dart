import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/responsive.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_textfield.dart';
import '../transitions/page_transitions.dart';
import 'demographic_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // FULL-STACK SIGNUP LOGIC
  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to terms and conditions'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          if (!mounted) return;
          // Extract the newly created userId from the response
          final String newUserId = data['user']?['_id'] ?? data['userId'] ?? '';
          final String username = _usernameController.text.trim();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, $username! Account created.'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;

          // Navigate to Demographic screen for onboarding
          Navigator.of(context).pushReplacement(
            ModernPageRoute(
              page: DemographicScreen(
                userId: newUserId,
                username: username,
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Sign up failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Check your connection to the server.'),
            backgroundColor: Colors.red,
          ),
        );
        debugPrint("Signup Error: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() {
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: r.padH(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: r.h(40)),

                Hero(
                  tag: 'logo', 
                  child: Image.asset(
                    'assets/images/ispeak_logo.png',
                    height: r.h(80),
                    ),
                  ),

                SizedBox(height: r.h(5)),

                Hero(
                  tag: 'brand_text', 
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      'iSpeak',
                      style: TextStyle(
                        fontSize: r.sp(32),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: r.h(8)),

                Text(
                  'Master Your Public Speaking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.sp(14),
                    color: Colors.grey,
                  ),
                ),

                SizedBox(height: r.h(50)),

                Container(
                  padding: r.pad(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: r.radius(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.08 * 255).round()),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: r.sp(22),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        SizedBox(height: r.h(24)),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('First Name', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                                  SizedBox(height: r.h(8)),
                                  CustomTextField(
                                    controller: _firstNameController,
                                    hintText: 'First Name',
                                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: r.w(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Last Name', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                                  SizedBox(height: r.h(8)),
                                  CustomTextField(
                                    controller: _lastNameController,
                                    hintText: 'Last Name',
                                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: r.h(20)),

                        Text('Username', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                        SizedBox(height: r.h(8)),
                        CustomTextField(
                          controller: _usernameController,
                          hintText: 'Choose a username',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter a username';
                            if (value.length < 3) return 'Must be at least 3 characters';
                            return null;
                          },
                        ),

                        SizedBox(height: r.h(20)),

                        Text('Email Address', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                        SizedBox(height: r.h(8)),
                        CustomTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Please enter a valid email';
                            return null;
                          },
                        ),

                        SizedBox(height: r.h(20)),

                        Text('Password', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                        SizedBox(height: r.h(8)),
                        CustomTextField(
                          controller: _passwordController,
                          hintText: 'Enter your password',
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter a password';
                            if (value.length < 6) return 'Must be at least 6 characters';
                            return null;
                          },
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            child: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey[600]),
                          ),
                        ),

                        SizedBox(height: r.h(20)),

                        Text('Confirm Password', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.black87)),
                        SizedBox(height: r.h(8)),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm your password',
                          obscureText: !_isConfirmPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            child: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey[600]),
                          ),
                        ),

                        SizedBox(height: r.h(20)),

                        Row(
                          children: [
                            SizedBox(
                              width: r.w(20),
                              height: r.w(20),
                              child: Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                                activeColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: r.radius(4)),
                              ),
                            ),
                            SizedBox(width: r.w(12)),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'I agree to the ', style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600])),
                                      TextSpan(text: 'Terms & Conditions', style: TextStyle(fontSize: r.sp(12), color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: r.h(28)),

                        _isLoading
                            ? SizedBox(
                                height: r.h(54),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : PrimaryButton(
                                text: 'Create Account',
                                onPressed: _handleSignUp,
                              ),

                        SizedBox(height: r.h(16)),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account?', style: TextStyle(fontSize: r.sp(13), color: Colors.grey)),
                            SizedBox(width: r.w(4)),
                            GestureDetector(
                              onTap: _goToLogin,
                              child: Text('Log In', style: TextStyle(fontSize: r.sp(13), color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: r.h(24)),

                Text(
                  '© 2026 iSpeak. English & Filipino Supported',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.sp(11),
                    color: Colors.grey[600],
                  ),
                ),

                SizedBox(height: r.h(20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}