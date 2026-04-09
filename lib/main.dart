import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for System UI controls
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pages/dashboard_page.dart';
import 'pages/progress_page.dart';
import 'pages/result_page.dart';
import 'pages/practice_page.dart';
import 'pages/learning_resources_page.dart';
import 'pages/splash_screen.dart';
import 'pages/login_screen.dart';
import 'theme/app_theme.dart';
import 'transitions/page_transitions.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- EDGE-TO-EDGE UI CONFIGURATION ---
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.light, 
      systemNavigationBarColor: Colors.transparent, 
      systemNavigationBarIconBrightness: Brightness.dark, 
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iSpeak',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppTheme.primaryColor,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        fontFamily: AppTheme.fontFamily,
        textTheme: AppTheme.textTheme,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ModernPageTransitionsBuilder(),
            TargetPlatform.iOS: ModernPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class MainPage extends StatefulWidget {
  final String userId;

  const MainPage({super.key, required this.userId});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Map<String, dynamic>? _currentSessionData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfStillActive();
    }
  }

  Future<void> _checkIfStillActive() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'Banned') {
          _forceLogout();
        }
      }
    } catch (e) {
      debugPrint('Status check failed: $e');
    }
  }

  void _forceLogout() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your account has been suspended. Please contact the administrator.'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hideBars = _currentIndex == 3;

    final List<Widget> pages = [
      DashBoardPage(
        userId: widget.userId,
        onStartPractice: () => setState(() => _currentIndex = 1),
        onLearningResources: () => setState(() => _currentIndex = 4),
      ),
      PracticePage(
        userId: widget.userId,
        onFinish: (data) => setState(() {
          _currentSessionData = data;
          _currentIndex = 3;
        }),
      ),
      ProgressPage(userId: widget.userId),
      ResultPage(
        sessionData: _currentSessionData,
        onBackToHome: () => setState(() => _currentIndex = 0),
        onPracticeAgain: () => setState(() => _currentIndex = 1),
      ),
      LearningResourcesScreen(
        userId: widget.userId,
        onBack: () => setState(() => _currentIndex = 0),
      ),
    ];

    return Scaffold(
      extendBody: true, 
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F5F5),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: hideBars
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                shape: const CircleBorder(),
                onPressed: () => setState(() => _currentIndex = 1),
                backgroundColor: const Color(0xFF3F7CF4),
                elevation: 6,
                child: const Icon(Icons.mic, size: 36, color: Colors.white),
              ),
            ),
      bottomNavigationBar: hideBars
          ? null
          : BottomAppBar(
              // UNIVERSAL FIX 1: Override Material 3's sneaky default padding
              padding: EdgeInsets.zero, 
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              elevation: 10,
              child: SafeArea(
                child: SizedBox(
                  height: 65, // Safe fixed height for the content only
                  child: Row(
                    // UNIVERSAL FIX 2: Expanded widgets automatically calculate perfect spacing on any screen
                    children: [
                      Expanded(child: _buildNavItem(Icons.home, 'Home', 0)),
                      const Expanded(child: SizedBox()), // Empty flexible space for the Mic button notch
                      Expanded(child: _buildNavItem(Icons.show_chart, 'Progress', 2)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey),
          const SizedBox(height: 4),
          // UNIVERSAL FIX 3: Flexible guarantees text will NEVER overflow vertically or horizontally
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}