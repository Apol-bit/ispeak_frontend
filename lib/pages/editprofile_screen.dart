import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; 
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_textfield.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId; 
  final String firstName;
  final String lastName;
  final String username;
  final String userEmail;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.userEmail,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _usernameController = TextEditingController(text: widget.username);
    _emailController = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  //The DB Save function
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/user/${widget.userId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'username': _usernameController.text.trim(),
            // EMAIL OMITTED ON PURPOSE FOR SECURITY
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          if (!mounted) return;
          
          Navigator.pop(context, true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to update database');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
                      // --- USERNAME CONTAINER (Freely Changeable) ---
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
                              'Username',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _usernameController,
                              hintText: 'Choose a username',
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter a username';
                                if (value.length < 3) return 'Username must be at least 3 characters';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                                            // --- REAL NAME CONTAINER (Restricted) ---
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
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('First Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                                      const SizedBox(height: 8),
                                      CustomTextField(
                                        controller: _firstNameController,
                                        hintText: 'First Name',
                                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Last Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                                      const SizedBox(height: 8),
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Real name changes are restricted to once every 30 days.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- EMAIL CONTAINER (Locked) ---
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
                              'Email Address',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              enabled: false, 
                              style: TextStyle(color: Colors.grey[600]), 
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: const Icon(Icons.lock, color: Colors.grey, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

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