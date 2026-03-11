import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/progress_page.dart';
import 'pages/result_page.dart';
import 'pages/practice_page.dart';
import 'pages/learning_resources_page.dart';
import 'pages/splash_screen.dart';
import 'theme/app_theme.dart';
import 'transitions/page_transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  Map<String, dynamic>? _currentSessionData; 

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
          Text(label, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}