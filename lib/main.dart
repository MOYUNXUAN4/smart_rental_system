import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:smart_rental_system/Compoents/fade_transition_builder.dart';
import 'package:smart_rental_system/Compoents/glass_dialog_helper.dart';
import 'package:smart_rental_system/Services/firebase_options.dart';

import 'Screens/splash_screen.dart';

// ✅ 全局 NavigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ConnectivityHelper {
  static bool _isDialogShowing = false;

  /// check and ensure connectivity
  static Future<bool> ensureConnection() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      final context = navigatorKey.currentContext;
      // avoid multiple dialogs
      if (context != null && !_isDialogShowing) {
        _isDialogShowing = true;
        

        await showGlassConfirmDialog(
          context: context,
          title: "Connection Required",
          content: "We detected no internet. Please reconnect to sync your rental data.",
          confirmBtnText: "Retry",
          icon: Icons.wifi_off_rounded,
          isDestructive: true,
        );
        
        _isDialogShowing = false;
      }
      return false; // connectivity issue
    }
    return true; // connected great
  }
}

// ✅ change screen observer to check connectivity
class ConnectivityNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // is push is a popup, skip
    if (route is! PopupRoute) {
      ConnectivityHelper.ensureConnection();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is! PopupRoute) {
      ConnectivityHelper.ensureConnection();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  Stripe.publishableKey = 'pk_test_51SeDucL7fpWOo6Fl4norAYosjDiupQufgRP7ak6u2Q7JFO5X5rNVMF1ssfCiijx3T7t2zh6jhI0Prx0mVIB5x0Jk00XBgywnlO'; 
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      // ✅ 绑定观察者
      navigatorObservers: [ConnectivityNavigationObserver()],
      debugShowCheckedModeBanner: false,
      title: 'Smart Rental System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0E1C22), // 极光深色背景
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadePageTransitionsBuilder(),
            TargetPlatform.iOS: FadePageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}