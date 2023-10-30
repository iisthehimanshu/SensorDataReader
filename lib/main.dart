import 'package:flutter/material.dart';
import 'package:sensor_reader_prototype_websocket/mainscreen.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:light/light.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uni_links/uni_links.dart' as uni_links;
import 'package:flutter/services.dart' show PlatformException;
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the plugin with the Android initialization settings.
  var androidInitializationSettings = AndroidInitializationSettings('app_icon');
  var initializationSettings =
  InitializationSettings(android: androidInitializationSettings);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "plugin app",
      routerConfig: GoRouter(routes:[
        GoRoute(path: '/',
            builder: (context , state) => const MyHomePage(title: ' ')),

      ]),
    );
  }
}

Future<void> cancelNotification() async {
  await flutterLocalNotificationsPlugin.cancel(0); // Replace 0 with your notification ID
}

Future<void> showContinuousNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'your_channel_id', // Replace with your own channel ID
    'Your Channel Name', // Replace with your own channel name
    importance: Importance.min,
    priority: Priority.low,
    playSound: false,
    enableVibration: false,
    ongoing: true, // This makes the notification ongoing (continuous)
  );
  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID (use a unique ID for each notification)
    'Iwayplus plugin is running', // Notification title
    'Redirecting you to the webpage', // Notification message
    platformChannelSpecifics,
  );
}


