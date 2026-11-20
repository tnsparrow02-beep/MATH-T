import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'pin_screen.dart';
import 'widgets.dart';

/// Wraps the whole app (see MaterialApp.builder): while the app is locked, the PIN screen
/// covers every page, including pages opened on top of the dashboard.
///
/// The app locks: when it opens, when you press "lock now", and when you come back after
/// more than 2 minutes away (a file picker or camera does not count as "away").
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const Duration _relockAfter = Duration(minutes: 2);

  bool _ready = false;
  bool _hasPin = true;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final has = await AppLock.hasPin();
    if (!mounted) return;
    setState(() {
      _hasPin = has;
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null && AppLock.busy == 0 && DateTime.now().difference(at) > _relockAfter) {
        AppLock.locked.value = true;
      }
    }
  }

  void _onUnlocked() {
    setState(() => _hasPin = true);
    AppLock.locked.value = false;
  }

  void _onReset() {
    setState(() => _hasPin = false);
    AppLock.locked.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: AppLock.locked,
          builder: (context, locked, _) {
            if (!_ready) {
              return const Positioned.fill(child: ColoredBox(color: AppColors.deepIndigo));
            }
            if (!locked && _hasPin) return const SizedBox.shrink();
            return Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ModalBarrier(dismissible: false, color: AppColors.deepIndigo),
                  PinScreen(
                    key: ValueKey<bool>(_hasPin),
                    mode: _hasPin ? PinMode.unlock : PinMode.setup,
                    onDone: _onUnlocked,
                    onReset: _onReset,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
