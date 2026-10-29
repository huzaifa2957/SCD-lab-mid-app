import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/session_provider.dart';
import 'screens/common/root_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const StudentNestApp());
}

class StudentNestApp extends StatelessWidget {
  const StudentNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        title: 'StudentNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const RootGate(),
      ),
    );
  }
}
