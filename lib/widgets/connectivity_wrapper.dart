import 'dart:async';
import 'dart:io'; // Required for InternetAddress
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey; // Receive the key

  const ConnectivityWrapper({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _subscription = Connectivity().onConnectivityChanged.listen(_handleConnectionChange);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _handleConnectionChange(results);
    } on PlatformException catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  Future<void> _handleConnectionChange(List<ConnectivityResult> results) async {
    // 1. Basic Hardware Check (WiFi/Mobile on?)
    bool hardwareOn = results.any((result) =>
    result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn
    );

    if (!hardwareOn) {
      _showNoInternetDialog();
      return;
    }

    // 2. "Real" Internet Check (Ping)
    // If hardware is on, we double-check if we can actually reach the web.
    // Emulators often say "WiFi On" even when offline.
    bool hasRealInternet = await _checkRealInternet();

    if (!hasRealInternet) {
      _showNoInternetDialog();
    } else {
      _dismissDialogIfOpen();
    }
  }

  Future<bool> _checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _showNoInternetDialog() {
    if (_isDialogShowing) return;

    // USE GLOBAL KEY CONTEXT (This fixes the "Did not pop up" bug)
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;

    setState(() => _isDialogShowing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 12),
              Text('No Internet'),
            ],
          ),
          content: const Text(
            'This app requires an active internet connection.\n\nPlease check your connection settings.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Manual re-check when user clicks "Try Again"
                final results = await Connectivity().checkConnectivity();
                _handleConnectionChange(results);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissDialogIfOpen() {
    if (_isDialogShowing) {
      // USE GLOBAL KEY TO POP
      final context = widget.navigatorKey.currentContext;
      if (context != null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() => _isDialogShowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}