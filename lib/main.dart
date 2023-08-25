import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:light/light.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sensors Demo',
      home: MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;



  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<double>? _accelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  bool servicestatus = false;
  bool haspermission = false;
  late LocationPermission permission;
  late Position position;
  String long = "", lat = "";
  late StreamSubscription<Position> positionStream;
  String _luxString = 'Unknown';
  Light? _light;
  StreamSubscription? _subscription;
  double compassValue = 0.0;
  late Stream<StepCount> _stepCountStream;
  String  _steps = '?';
  var link = "http://10.0.2.2:8080";

  int backAndForth = 0;

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen(
            (AccelerometerEvent event) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen(
            (GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen(
            (MagnetometerEvent event) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    checkGps();
    startListening();
    startCompassStream();
    initPlatformState();
  }

  checkGps() async {
    servicestatus = await Geolocator.isLocationServiceEnabled();
    if(servicestatus){
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        }else if(permission == LocationPermission.deniedForever){
          print("'Location permissions are permanently denied");
        }else{
          haspermission = true;
        }
      }else{
        haspermission = true;
      }

      if(haspermission){
        setState(() {
          //refresh the UI
        });

        getLocation();
      }
    }else{
      print("GPS Service is not enabled, turn on GPS location");
    }

    setState(() {
    });
  }

  getLocation() async {
    position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    print(position.longitude);
    print(position.latitude);

    long = position.longitude.toString();
    lat = position.latitude.toString();

    setState(() {
    });

    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    StreamSubscription<Position> positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings).listen((Position position) {
      print(position.longitude);
      print(position.latitude);
      long = position.longitude.toString();
      lat = position.latitude.toString();
      setState(() {
      });
    });
  }
  void onData(int luxValue) async {
    print("Lux value: $luxValue");
    setState(() {
      _luxString = "$luxValue";
    });
  }
  void startListening() {
    _light = Light();
    try {
      _subscription = _light?.lightSensorStream.listen(onData);
    } on LightException catch (exception) {
      print(exception);
    }
  }

  Future<void> startCompassStream() async {
    StreamSubscription<CompassEvent> compassSubscription;

    compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
      setState(() {
        compassValue = event.heading!;
      });
    });
  }
  void onStepCount(StepCount event) {
    print(event);
    setState(() {
      _steps = event.steps.toString();
    });
  }

  void onStepCountError(error) {
    print('onStepCountError: $error');
    setState(() {
      _steps = 'Step Count not available.';
    });
  }

  void initPlatformState() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final accelerometer =
    _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope =
    _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final magnetometer =
    _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();


    Future<void> sendGyroDataToServer() async {
      var adres = '/gyro/receive-data';
      final url = link+adres;
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(gyroscope);

      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('Gyro data sent successfully');
      } else {
        print('Error sending Gyro data: ${response.statusCode}');
      }
    }

    Future<void> sendACCDataToServer() async {
      var adres = '/acc/receive-data';
      final url = link+adres;
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(accelerometer);

      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('Acc data sent successfully');
      } else {
        print('Error sending ACC data: ${response.statusCode}');
      }
    }

    Future<void> sendMagDataToServer() async {
      var adres = '/mag/receive-data';
      final url = link+adres;
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(magnetometer);

      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('Mag data sent successfully');
      } else {
        print('Error sending Mag data: ${response.statusCode}');
      }
    }

    Future<void> sendLocDataToServer() async {
      var adres = '/loc/receive-data';
      final url = link+adres;
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      });
      final response = await http.post(Uri.parse(url),
          headers: headers,
          body: body);
      if (response.statusCode == 200) {
        print('Loc data sent successfully');
      } else {
        print('Error sending Loc data: ${response.statusCode}');
      }
    }

    Future<void> sendLuxDataToServer(String value) async {
      var adres = '/lux/receive-data';
      final url = link+adres;
      var urlParse = Uri.parse(url);
      final response = await http.post(urlParse, body: {'Lux_Intensity': value});

      if (response.statusCode == 200) {
        print('Ambient data sent successfully');
      } else {
        print('Failed to send Ambient data to server : ${response.statusCode}');
      }
    }

    Future<void> sendCompassDataToServer(double value) async {
      var adres = '/compass/receive-data';
      final url = link+adres;
      var urlParse = Uri.parse(url);
      final response = await http.post(urlParse, body: {'Diviated_from_North': value.toString()});

      if (response.statusCode == 200) {
        print('Compass data sent successfully');
      } else {
        print('Failed to send Compass data to server : ${response.statusCode}');
      }
    }

    Future<void> sendStepsToServer(String value) async {
      var adres = '/pedometer/receive-data';
      final URL = link+adres;
      var urlParse = Uri.parse(URL);
      final response = await http.post(urlParse, body: {'StepsValue ': value});

      if (response.statusCode == 200) {
        print('Pedometer data sent successfully');
      } else {
        print('Failed to send Pedometer data to server : ${response.statusCode}');
      }
    }




    return Scaffold(
      appBar: AppBar(
        title: const Text('Data from Sensors'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Accelerometer: $accelerometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Gyroscope: $gyroscope'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Magnetometer: $magnetometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('latitude , longitude: [ $lat , $long ]'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('LUX : [ $_luxString ]'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Diviation from North : [ $compassValue ]'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Pedometer : [ $_steps ]'),
              ],
            ),
          ),
          ElevatedButton(
            child: const Text("SEND"),
            onPressed: () {
              sendGyroDataToServer();
              sendACCDataToServer();
              sendMagDataToServer();
              sendLocDataToServer();
              sendLuxDataToServer(_luxString);
              sendCompassDataToServer(compassValue);
              sendStepsToServer(_steps);
            },
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }
}