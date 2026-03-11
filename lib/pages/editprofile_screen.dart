import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_textfield.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId; // 👈 Needs to know WHO to update
  final String userName;
  final String userEmail;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false; // 👈 Added for the loading state

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _emailController = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  //The DB Save function
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.put(
          Uri.parse('http://172.20.10.2:5000/api/user/${widget.userId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          if (!mounted) return;
          
          // Pop the screen and return the new data to the Profile Screen
          Navigator.pop(
            context,
            {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
            },
          );

          // Show a nice success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to update database');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.accentColor, 
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20, 
              left: 24,
              right: 24,
              bottom: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.chevron_left, color: Colors.white, size: 26),
                      SizedBox(width: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.02 * 255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _nameController,
                              hintText: 'Enter your name',
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your name';
                                if (value.length < 2) return 'Name must be at least 2 characters';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.02 * 255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _emailController,
                              hintText: 'Enter your email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your email';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Change the button to show a loading spinner when pressed
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: 'Save Changes',
                              onPressed: _saveChanges,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}