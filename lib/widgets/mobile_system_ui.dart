import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One owner above the Navigator; routes and dialogs never configure system UI.
/// Android may ignore immersiveSticky on newer target/OS combinations. Keep the
/// normal safe insets and SDK target instead of relying on bars staying hidden.
class MobileSystemUi extends StatefulWidget {
  final Widget child;
  const MobileSystemUi({super.key, required this.child});
  @override
  State<MobileSystemUi> createState() => _MobileSystemUiState();
}

class _MobileSystemUiState extends State<MobileSystemUi>
    with WidgetsBindingObserver {
  Timer? _restore;
  ui.FlutterView? _view;
  bool _keyboardVisible = false;
  bool _active = true;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      WidgetsBinding.instance.addObserver(this);
      _apply();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
  }

  void _apply() {
    if (_supported && mounted && _active && !_keyboardVisible) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  void _scheduleRestore() {
    _restore?.cancel();
    // Android blocks system-UI changes for one second after keyboard dismissal.
    _restore = Timer(const Duration(milliseconds: 1100), _apply);
  }

  @override
  void didChangeMetrics() {
    final visible = (_view?.viewInsets.bottom ?? 0) > 0;
    if (visible == _keyboardVisible) return;
    _keyboardVisible = visible;
    if (visible) {
      _restore?.cancel();
    } else if (_active) {
      _scheduleRestore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _restore?.cancel();
    if (_active && !_keyboardVisible) _scheduleRestore();
  }

  @override
  void dispose() {
    _restore?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
