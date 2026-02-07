import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:rentdone/app/app.dart';
import 'package:rentdone/firebase/firebase_options.dart';

/// ------------------------------------------------------------
/// ENTRY POINT
/// ------------------------------------------------------------
Future<void> main() async {
  // Ensures binding is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (single responsibility)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app with Riverpod scope
  runApp(const ProviderScope(child: RentDoneApp()));
}
