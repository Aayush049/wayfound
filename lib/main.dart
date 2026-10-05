import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const WayfoundApp());
} 

class WayfoundApp extends StatelessWidget {
  const WayfoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Wayfound',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('Wayfound is connected to Firebase'),
        ),
      ),
    );
  }
}