import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await ScreenBrightness().setScreenBrightness(0.0);
    return Future.value(true);
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sleep Guard')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await ScreenBrightness().setScreenBrightness(0.0);
              const intent = AndroidIntent(
                action: 'android.intent.action.MAIN',
                category: 'android.intent.category.HOME',
                flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
              );
              await intent.launch();
            },
            child: const Text('Start Sleep Mode'),
          ),
        ),
      ),
    );
  }
}