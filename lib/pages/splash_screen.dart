import 'package:flutter/material.dart';
import '../widgets/feature_card.dart';
import '../widgets/primary_button.dart';
import '../theme/app_theme.dart';
import '../transitions/page_transitions.dart';
import '../config/responsive.dart';
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
    final r = Responsive(context);

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
                    padding: r.pad(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: r.h(40)),

                        Hero(
                          tag: 'logo',
                          child: Image.asset(
                            'assets/images/ispeak_logo.png',
                            height: r.h(120),
                          ),
                        ),

                        SizedBox(height: r.h(20)),

                        Hero(tag: 'brand_text', child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            "iSpeak", 
                            style: TextStyle(
                              fontSize: r.sp(52),
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        )),

                        SizedBox(height: r.h(10)),

                        Text(
                          "Master Your Public Speaking\nSkills with Real-Time Feedback",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: r.sp(14)),
                        ),

                        SizedBox(height: r.h(40)),

                        const FeatureCard(
                          icon: Icons.volume_up,
                          title: "Real-Time Analysis",
                          subtitle: "Track pace, clarity & energy",
                        ),

                        SizedBox(height: r.h(15)),

                        const FeatureCard(
                          icon: Icons.trending_up,
                          title: "Progress Tracking",
                          subtitle: "See your improvement over time",
                        ),

                        SizedBox(height: r.h(15)),

                        const FeatureCard(
                          icon: Icons.language,
                          title: "Taglish Support",
                          subtitle: "English, Filipino & Taglish",
                        ),

                        const Spacer(),
                        SizedBox(height: r.h(20)),

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