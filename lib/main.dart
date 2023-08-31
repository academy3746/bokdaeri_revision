// ignore_for_file: avoid_print
import 'dart:async';

import 'package:bokdaeri_hybrid/features/webview/webview_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

void _getAndroidAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String version = packageInfo.version;
  String buildNumber = packageInfo.buildNumber;

  print("User Device App Version: $version");
  print("User Devie Build Number: $buildNumber");

  /// Google Play Store Info (Hard Code)
  const String marketVersion = "2.0.0";
  const String marketBuildNumber = "50";

  /// Google Play Store Direction
  if (version != marketVersion || buildNumber != marketBuildNumber) {
    final Uri marketUri = Uri.parse("market://details?id=kr.co.lawired.bok");
    final Uri fallbackUri = Uri.parse("https://play.google.com/store/apps/details?id=kr.co.lawired.bok");

    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri);
    } else if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri);
    } else {
      throw "Can not launch $marketUri";
    }
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runZonedGuarded(() async {}, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });

  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  _getAndroidAppVersion();
  runApp(const BokdaeriApp());
}


class BokdaeriApp extends StatelessWidget {
  const BokdaeriApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '복대리',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F81FC)),
        primaryColor: const Color(0xFF2F81FC),
        useMaterial3: false,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const WebviewController(),
    );
  }
}
