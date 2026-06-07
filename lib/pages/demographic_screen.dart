import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../transitions/page_transitions.dart';
import 'login_screen.dart';

class DemographicScreen extends StatefulWidget {
  final String userId;
  final String username;

  const DemographicScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<DemographicScreen> createState() => _DemographicScreenState();
}

class _DemographicScreenState extends State<DemographicScreen>
    with SingleTickerProviderStateMixin {
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedGender;
  String? _selectedGradeLevel;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _genderOptions = ['Male', 'Female', 'Prefer not to say'];
  final List<String> _gradeLevelOptions = [
    'Elementary',
    'Junior High School',
    'Senior High School',
    'College / University',
    'Graduate / Post-graduate',
    'Working Professional',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Derive initial level from demographics
  String _computeInitialLevel() {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final grade = _selectedGradeLevel ?? '';

    if (grade.contains('Elementary') || age < 13) return 'Beginner';
    if (grade.contains('Junior High') || (age >= 13 && age <= 15)) {
      return 'Beginner';
    }
    if (grade.contains('Senior High') || (age >= 16 && age <= 18)) {
      return 'Intermediate';
    }
    if (grade.contains('College') || grade.contains('University')) {
      return 'Intermediate';
    }
    if (grade.contains('Graduate') || grade.contains('Working')) {
      return 'Advanced';
    }
    // Fallback by age
    if (age < 16) return 'Beginner';
    if (age < 22) return 'Intermediate';
    return 'Advanced';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnack('Please select your gender.');
      return;
    }
    if (_selectedGradeLevel == null) {
      _showSnack('Please select your grade / school level.');
      return;
    }

    setState(() => _isLoading = true);

    final initialLevel = _computeInitialLevel();

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/${widget.userId}/demographics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'age': int.tryParse(_ageController.text.trim()),
          'gender': _selectedGender,
          'gradeLevel': _selectedGradeLevel,
          'initialLevel': initialLevel,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSuccessAndNavigate(initialLevel);
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to save profile. Please try again.');
      }
    } catch (e) {
      if (mounted) _showSnack('Network error. Please check your connection.');
      debugPrint('Demographic save error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showSuccessAndNavigate(String level) {
    // Show a brief level reveal dialog, then go to login
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LevelRevealDialog(
        level: level,
        onContinue: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pushAndRemoveUntil(
            ModernPageRoute(page: const LoginScreen()),
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 36),

                    // Header icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_pin_outlined,
                          color: Colors.white, size: 36),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'One Last Step,\n${widget.username}!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Help us personalize your learning journey\nby telling us a bit about yourself.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                    ),

                    const SizedBox(height: 32),

                    // Progress indicator (step 2 of 2)
                    _StepIndicator(currentStep: 2, totalSteps: 2),

                    const SizedBox(height: 28),

                    // --- Form Card ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Age
                          _FieldLabel(label: 'Age', icon: Icons.cake_outlined),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Enter your age'),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Age is required';
                              final n = int.tryParse(val);
                              if (n == null || n < 12 || n > 100) return 'You must be at least 12 years old';
                              return null;
                            },
                          ),

                          const SizedBox(height: 22),

                          // Gender
                          _FieldLabel(label: 'Gender', icon: Icons.wc_outlined),
                          const SizedBox(height: 10),
                          _GenderSelector(
                            selected: _selectedGender,
                            options: _genderOptions,
                            onSelect: (g) => setState(() => _selectedGender = g),
                          ),

                          const SizedBox(height: 22),

                          // Grade / School Level
                          _FieldLabel(
                              label: 'Grade / School Level',
                              icon: Icons.school_outlined),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGradeLevel,
                            isExpanded: true,
                            decoration: _inputDecoration('Select your level'),
                            items: _gradeLevelOptions
                                .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedGradeLevel = val),
                            validator: (val) =>
                                val == null ? 'Please select your level' : null,
                          ),

                          const SizedBox(height: 28),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: _isLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentColor,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14)),
                                      elevation: 4,
                                      shadowColor:
                                          AppTheme.accentColor.withAlpha(80),
                                    ),
                                    child: const Text(
                                      'Complete Setup',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF5F7FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i + 1 == currentStep;
        final isDone = i + 1 < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: (isActive || isDone)
                ? AppTheme.accentColor
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ─── Gender Selector ──────────────────────────────────────────────────────────
class _GenderSelector extends StatelessWidget {
  final String? selected;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _GenderSelector({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((g) {
        final isSelected = selected == g;
        return GestureDetector(
          onTap: () => onSelect(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentColor
                  : const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              g,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Field Label ──────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Level Reveal Dialog ──────────────────────────────────────────────────────
class _LevelRevealDialog extends StatelessWidget {
  final String level;
  final VoidCallback onContinue;

  const _LevelRevealDialog({required this.level, required this.onContinue});

  Color get _levelColor {
    switch (level) {
      case 'Intermediate':
        return AppTheme.accentColor;
      case 'Advanced':
        return const Color(0xFFB45FD4);
      default:
        return const Color(0xFF3FBD7A);
    }
  }

  IconData get _levelIcon {
    switch (level) {
      case 'Intermediate':
        return Icons.trending_up;
      case 'Advanced':
        return Icons.emoji_events_outlined;
      default:
        return Icons.spa_outlined;
    }
  }

  String get _levelDescription {
    switch (level) {
      case 'Intermediate':
        return 'You\'re at a comfortable speaking level.\nKeep practicing to reach Advanced!';
      case 'Advanced':
        return 'Impressive! You\'re already at an advanced\nlevel. Sharpen your skills further!';
      default:
        return 'Welcome! We\'ll guide you step-by-step\nto become a confident speaker.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _levelColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(_levelIcon, color: _levelColor, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Initial Level',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              level,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _levelColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _levelDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '✦ Complete 10 practices to lock in your official level',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.accentColor),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _levelColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Continue to Login',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
