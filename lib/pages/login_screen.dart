import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_textfield.dart';
import '../transitions/page_transitions.dart';
import '../services/auth_service.dart';
import '../config/responsive.dart';
import '../main.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handles authentication and Ban status
  void _handleLogin() async {
    final isValid = _formKey.currentState!.validate();

    if (isValid) {
      setState(() => _isLoading = true);

      try {
        // Call Node.js Backend via AuthService
        final result = await AuthService().login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        setState(() => _isLoading = false);

        // Successful Login (Status is Active)
        if (result['token'] != null) {
          final String userId = result['user']['id'];
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login successful!')),
            ); 
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => MainPage(userId: userId),
              ),
              (route) => false,
            );
          }
        } 
        // Error or Banned Status (403 or 400)
        else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Login failed'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not connect to server. Check your IP/Wi-Fi.')),
          );
        }
      }
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      RightToLeftPageRoute(page: const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
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
                        color: Colors.black.withOpacity(0.08),
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
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: r.sp(22),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        SizedBox(height: r.h(24)),

                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: r.sp(13),
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),

                        SizedBox(height: r.h(8)),

                        CustomTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                        ),

                        SizedBox(height: r.h(20)),

                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: r.sp(13),
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),

                        SizedBox(height: r.h(8)),

                        CustomTextField(
                          controller: _passwordController,
                          hintText: 'Enter your password',
                          obscureText: !_isPasswordVisible,
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            child: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                        SizedBox(height: r.h(12)),

                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset feature coming soon'),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: r.sp(13),
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                                text: 'Log In',
                                onPressed: _handleLogin,
                              ),

                        SizedBox(height: r.h(16)),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(
                                fontSize: r.sp(13),
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: r.w(4)),
                            GestureDetector(
                              onTap: _goToSignUp,
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: r.sp(13),
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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