import 'package:flutter/material.dart';
import '../widgets/feature_card.dart';
import '../widgets/primary_button.dart';
import '../theme/app_theme.dart';
import '../transitions/page_transitions.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  void goToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      ModernPageRoute(page: const LoginScreen()), 
    );
  }

  @override
  Widget build(BuildContext context) {
    // UNIVERSAL FIX 1: Grab the exact dimensions of the phone's screen
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: size.height * 0.05),

                        Hero(
                          tag: 'logo',
                          child: Image.asset(
                            'assets/images/ispeak_logo.png',
                            height: size.height * 0.15, 
                          ),
                        ),

                        const SizedBox(height: 20),

                        Hero(tag: 'brand_text', child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            "iSpeak", 
                            style: TextStyle(
                              fontSize: 52,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        )),

                        const SizedBox(height: 10),

                        const Text(
                          "Master Your Public Speaking\nSkills with Real-Time Feedback",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),

                        SizedBox(height: size.height * 0.05),

                        const FeatureCard(
                          icon: Icons.volume_up,
                          title: "Real-Time Analysis",
                          subtitle: "Track pace, clarity & energy",
                        ),

                        const SizedBox(height: 15),

                        const FeatureCard(
                          icon: Icons.trending_up,
                          title: "Progress Tracking",
                          subtitle: "See your improvement over time",
                        ),

                        const SizedBox(height: 15),

                        const FeatureCard(
                          icon: Icons.language,
                          title: "Bilingual Support",
                          subtitle: "English & Filipino languages",
                        ),

                        const Spacer(),
                        const SizedBox(height: 20),

                        PrimaryButton(
                          text: "Get Started",
                          onPressed: () => goToLogin(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}