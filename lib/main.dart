import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for System UI controls
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
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'widgets/mobile_system_ui.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock orientation to Portrait Only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  ApiClient.onAuthenticationExpired = () async {
    await AuthService.clearSession();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'iSpeak',
      builder: (context, child) => MobileSystemUi(child: child!),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: AppTheme.colorScheme(Brightness.light),
        primaryColor: AppTheme.primaryColor,
        canvasColor: AppTheme.lightMenuSurface,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        fontFamily: AppTheme.fontFamily,
        textTheme: AppTheme.textTheme,
        popupMenuTheme: AppTheme.popupMenuTheme(Brightness.light),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: AppTheme.menuStyle(Brightness.light),
        ),
        menuTheme: MenuThemeData(style: AppTheme.menuStyle(Brightness.light)),
        menuButtonTheme: MenuButtonThemeData(
          style: AppTheme.menuButtonStyle(Brightness.light),
        ),
        hoverColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
        focusColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
        highlightColor: AppTheme.resourceBlue.withValues(alpha: 0.08),
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
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Map<String, dynamic>?> _session;

  @override
  void initState() {
    super.initState();
    _session = AuthService.validateSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const SplashScreen();
        return MainPage(userId: user['id'].toString());
      },
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
  int _refreshCount = 0;
  int _recordingResetVersion = 0;

  void _switchTab(int index) {
    setState(() {
      if (_currentIndex == 3 && index != 3) _recordingResetVersion++;
      _currentIndex = index;
      _refreshCount++;
    });
  }

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
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/user/${widget.userId}'),
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

  Future<void> _forceLogout() async {
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your account has been suspended. Please contact the administrator.',
        ),
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
        refreshKey: _refreshCount,
        onStartPractice: () => _switchTab(1),
        onBackToHome: () => _switchTab(0),
        onLearningResources: () => _switchTab(4),
      ),
      PracticePage(
        userId: widget.userId,
        resetVersion: _recordingResetVersion,
        onFinish: (data) {
          _currentSessionData = data;
          _switchTab(3);
        },
      ),
      ProgressPage(
        userId: widget.userId,
        refreshKey: _refreshCount,
        onStartPractice: () => _switchTab(1),
        onBackToHome: () => _switchTab(0),
      ),
      ResultPage(
        sessionData: _currentSessionData,
        onBackToHome: () => _switchTab(0),
        onPracticeAgain: () => _switchTab(1),
      ),
      LearningResourcesScreen(
        userId: widget.userId,
        isActive: _currentIndex == 4,
        refreshKey: _refreshCount,
        onBack: () => _switchTab(0),
      ),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F5F5),
      body: PopScope(
        canPop: _currentIndex != 3 && _currentIndex != 4,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && (_currentIndex == 3 || _currentIndex == 4)) {
            _switchTab(0);
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            for (var index = 0; index < pages.length; index++)
              TickerMode(enabled: index == _currentIndex, child: pages[index]),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: hideBars
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                shape: const CircleBorder(),
                onPressed: () => _switchTab(1),
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
                      const Expanded(
                        child: SizedBox(),
                      ), // Empty flexible space for the Mic button notch
                      Expanded(
                        child: _buildNavItem(Icons.show_chart, 'Progress', 2),
                      ),
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
      onTap: () => _switchTab(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 26,
            color: isSelected ? const Color(0xFF3F7CF4) : Colors.grey,
          ),
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
