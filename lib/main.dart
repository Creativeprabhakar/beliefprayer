import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import 'about_us.dart';
import 'prayer_sessions.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final AudioPlayer audioPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await _initNotifications();
  _scheduleDailyNotification();
  _scheduleAutoPlayPrayer();
  runApp(PrayerApp());
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void _scheduleDailyNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'daily_prayer', // Channel ID
    'Daily Prayer Notifications', // Channel Name
    channelDescription: 'Daily notification before prayer with sound',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true, // ✅ Enable sound
    // Uncomment below to use custom sound from /res/raw/notification.mp3
    // sound: RawResourceAndroidNotificationSound('notification'),
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Daily Prayer Reminder',
    'Prayer will start at 10:30 AM',
    _nextInstanceOfTime(10, 27),
    platformChannelSpecifics,
    androidAllowWhileIdle: true,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.wallClockTime,
  );
}

void _scheduleAutoPlayPrayer() {
  final now = DateTime.now();
  DateTime target = DateTime(now.year, now.month, now.day, 10, 0);
  if (now.isAfter(target)) {
    target = target.add(const Duration(days: 1));
  }
  Duration delay = target.difference(now);

  Timer(delay, () async {
    await audioPlayer.play(AssetSource('audio/prayer.mp3'));
  });
}

tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

class PrayerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
      routes: {
        '/about': (context) => AboutUsPage(),
        '/prayer': (context) => PrayerSessions(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isPlaying = false;
  bool isPaused = false;
  int countdown = 10;
  Timer? countdownTimer;

  void _startCountdownAndPlay() {
    if (countdownTimer != null && countdownTimer!.isActive) return;

    setState(() {
      countdown = 10;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
      });

      if (countdown == 0) {
        timer.cancel();
        audioPlayer.play(AssetSource('audio/prayer.mp3'));
        setState(() {
          isPlaying = true;
          isPaused = false;
        });
      }
    });
  }

  void _pausePrayer() {
    audioPlayer.pause();
    setState(() {
      isPlaying = false;
      isPaused = true;
    });
  }

  void _stopPrayer() {
    audioPlayer.stop();
    countdownTimer?.cancel();
    setState(() {
      isPlaying = false;
      isPaused = false;
      countdown = 10;
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belief Prayer App'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 250),
            SizedBox(height: 100),
            Text(
              isPlaying
                  ? "Playing Prayer..."
                  : countdown < 10
                      ? "Prayer starts in: $countdown"
                      : isPaused
                          ? "Prayer Paused"
                          : "Tap to start prayer",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            if (!isPlaying && !isPaused)
              ElevatedButton.icon(
                onPressed: _startCountdownAndPlay,
                icon: Icon(Icons.play_arrow),
                label: Text('Play'),
              ),
            if (isPlaying)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pausePrayer,
                    icon: Icon(Icons.pause),
                    label: Text('Pause'),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _stopPrayer,
                    icon: Icon(Icons.stop),
                    label: Text('Stop'),
                  ),
                ],
              ),
            if (isPaused)
              ElevatedButton.icon(
                onPressed: _startCountdownAndPlay,
                icon: Icon(Icons.play_arrow),
                label: Text('Resume'),
              ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/prayer');
                  },
                  child: Text("Prayer Sessions"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/about');
                  },
                  child: Text("About Us"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
