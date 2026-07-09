import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(SleepGuardApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sleep_guard_channel', 'Sleep Guard Service',
    description: 'تطبيق القفل التلقائي شغال',
    importance: Importance.low,
  );
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'sleep_guard_channel',
      initialNotificationTitle: 'Sleep Guard شغال',
      initialNotificationContent: 'بيراقب الوقت لتوفير البطارية',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool('enabled') ?? true;
    if (!enabled) return;
    int lockHour = prefs.getInt('lockHour') ?? 23;
    int lockMinute = prefs.getInt('lockMinute') ?? 30;
    int wakeHour = prefs.getInt('wakeHour') ?? 7;
    int wakeMinute = prefs.getInt('wakeMinute') ?? 0;
    DateTime now = DateTime.now();
    DateTime lockTime = DateTime(now.year, now.month, now.day, lockHour, lockMinute);
    DateTime wakeTime = DateTime(now.year, now.month, now.day, wakeHour, wakeMinute);
    if (now.isAfter(lockTime) && now.isBefore(wakeTime)) {
      try {
        await Brightness.setBrightness(0.0);
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 1000, amplitude: 128);
        }
        AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.HOME',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      } catch (e) {}
    }
  });
}

class SleepGuardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0F0F1A),
        primaryColor: Color(0xFF7C3AED),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFFEC4899),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TimeOfDay _lockTime = TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = TimeOfDay(hour: 7, minute: 0);
  bool _enabled = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = _prefs!.getBool('enabled') ?? true;
      _lockTime = TimeOfDay(
        hour: _prefs!.getInt('lockHour') ?? 23,
        minute: _prefs!.getInt('lockMinute') ?? 30,
      );
      _wakeTime = TimeOfDay(
        hour: _prefs!.getInt('wakeHour') ?? 7,
        minute: _prefs!.getInt('wakeMinute') ?? 0,
      );
    });
  }

  Future<void> _saveSettings() async {
    await _prefs!.setBool('enabled', _enabled);
    await _prefs!.setInt('lockHour', _lockTime.hour);
    await _prefs!.setInt('lockMinute', _lockTime.minute);
    await _prefs!.setInt('wakeHour', _wakeTime.hour);
    await _prefs!.setInt('wakeMinute', _wakeTime.minute);
  }

  Future<void> _pickTime(bool isLock) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isLock ? _lockTime : _wakeTime,
    );
    if (picked != null) {
      setState(() {
        if (isLock) _lockTime = picked; else _wakeTime = picked;
      });
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sleep Guard').animate().fadeIn(),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.nightlight_round, size: 80, color: Color(0xFF7C3AED))
                .animate().scale().shake(),
            SizedBox(height: 20),
            Text('حماية نومك وبطاريتك',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                .animate().fadeIn(delay: 200.ms),
            SizedBox(height: 30),
            SwitchListTile(
              title: Text('تفعيل القفل التلقائي'),
              value: _enabled,
              onChanged: (val) { setState(() { _enabled = val; }); _saveSettings(); },
              activeColor: Color(0xFF7C3AED),
            ).animate().slideX(),
            SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.lock_clock, color: Color(0xFFEC4899)),
                title: Text('وقت القفل'),
                subtitle: Text(_lockTime.format(context)),
                trailing: Icon(Icons.edit),
                onTap: () => _pickTime(true),
              ),
            ).animate().fadeIn(delay: 400.ms),
            SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: Icon(Icons.wb_sunny, color: Colors.amber),
                title: Text('وقت الاستيقاظ'),
                subtitle: Text(_wakeTime.format(context)),
                trailing: Icon(Icons.edit),
                onTap: () => _pickTime(false),
              ),
            ).animate().fadeIn(delay: 600.ms),
            Spacer(),
            Text('التطبيق هيقفل الشاشة ويقلل السطوع في الوقت المحدد',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey))
                .animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}