import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- ADDED: Required for System UI controls
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

  // --- ADDED: EDGE-TO-EDGE UI CONFIGURATION ---
  // This tells the OS to draw your app behind the status and navigation bars.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent top bar
      statusBarIconBrightness: Brightness.light, // White icons (battery/wifi) to contrast with your blue headers
      systemNavigationBarColor: Colors.transparent, // Transparent bottom swipe pill area
      systemNavigationBarIconBrightness: Brightness.dark, 
    ),
  );
  // ---------------------------------------------

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

  // Called every time the app comes back to the foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfStillActive();
    }
  }

  // Hits the server and kicks banned users out immediately
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
        onBack: () => setState(() => _currentIndex = 0),
      ),
    ];

    return Scaffold(
      extendBody: true, // <-- This is what allows your UI to flow under the navigation bar!
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
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              elevation: 10,
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 'Home', 0),
                  const SizedBox(width: 48),
                  _buildNavItem(Icons.show_chart, 'Progress', 2),
                ],
              ),
            ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}