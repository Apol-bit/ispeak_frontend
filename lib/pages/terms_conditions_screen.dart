import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  final bool isAccepted;

  const TermsConditionsScreen({super.key, this.isAccepted = false});

  static const _sections = <({String title, String body})>[
    (
      title: '1. About iSpeak',
      body:
          'iSpeak is a learning application designed to help users practice and improve public-speaking skills. By creating an account or using the app, you agree to these Terms and Conditions.',
    ),
    (
      title: '2. Accounts and eligibility',
      body:
          'You must provide accurate account information and keep your sign-in details secure. You are responsible for activity performed through your account. If you are not legally able to accept these terms on your own, a parent, guardian, or authorized representative must approve your use of iSpeak.',
    ),
    (
      title: '3. Recordings and speech analysis',
      body:
          'Practice features may record your voice and process speech, transcripts, timing, and performance indicators to provide feedback. Only submit recordings and content that you have the right to use. Automated scores and suggestions are estimates intended for learning and may not always be complete or accurate.',
    ),
    (
      title: '4. Acceptable use',
      body:
          'You may use iSpeak only for lawful learning and practice. You must not misuse the service, interfere with its operation, attempt unauthorized access, impersonate another person, upload harmful or unlawful material, or use the app to harass or harm others.',
    ),
    (
      title: '5. Your content',
      body:
          'You retain ownership of content you submit. You allow iSpeak to store, process, and display that content only as needed to operate the app, provide feedback, maintain your progress, and protect the service.',
    ),
    (
      title: '6. App content and intellectual property',
      body:
          'The iSpeak name, interface, lessons, prompts, graphics, and other app materials are protected by applicable intellectual-property laws. You may use them for personal learning, but you may not copy, sell, redistribute, or commercially exploit them without permission.',
    ),
    (
      title: '7. Service availability',
      body:
          'We may update, suspend, or discontinue parts of iSpeak to improve or protect the service. We aim to keep the app available, but uninterrupted or error-free operation is not guaranteed.',
    ),
    (
      title: '8. Suspension and termination',
      body:
          'Access may be restricted or terminated when these terms are violated, the service is endangered, or applicable law requires it. You may stop using iSpeak at any time.',
    ),
    (
      title: '9. Disclaimer and limitation',
      body:
          'iSpeak is an educational aid and does not guarantee a particular academic, professional, or speaking outcome. To the extent permitted by law, iSpeak is not responsible for indirect or consequential loss arising from use of, or inability to use, the app.',
    ),
    (
      title: '10. Changes and questions',
      body:
          'These terms may be updated when the app or applicable requirements change. Material updates will be presented in the app when appropriate. Questions may be directed to the iSpeak administrator or the official support channel provided with the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: AppTheme.primaryColor,
                          size: 30,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Please read before continuing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Effective August 31, 2026',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final section in _sections) ...[
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isAccepted ? 'Keep Accepted' : 'Accept'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
