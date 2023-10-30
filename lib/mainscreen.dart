import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sensor_reader_prototype_websocket/ListOfBeaconNearBy.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uni_links/uni_links.dart';
import 'DistanceEstimation.dart';
import 'kalman.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:rename/rename.dart';
import 'package:flutter_background/flutter_background.dart';

import 'main.dart';


String long = "0.0", lat = "0.0";
String nearestBuilding = '';
String nearestBuildingforlink = '';
String nearestBuildingID = '';
List<Map<String, dynamic>> BeaconsNearBy = [];
double measuredPower = -66.64; // RSSI at reference distance (dBm)
double pathLossExponent = 2.0; // Path loss exponent
int windowSize = 10; // Number of RSSI samples to consider in the moving average
DistanceEstimator estimator = DistanceEstimator(measuredPower, pathLossExponent, windowSize);
List<Map<String, dynamic>> TopThreeBeacons = [];
Map<BluetoothDevice, KalmanFilter> deviceFilters = {};
int? floor;
Map<String, List<double>> rssiValues = {};
int cc=0;

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final localsocket = io.io('http://10.194.17.111:8080', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });
  final socket = io.io('https://maps.iwayplus.in', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });
  List<double>? _magnetometerValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  bool servicestatus = false;
  bool hasgpspermission = false;
  late LocationPermission permission;
  late Position position;
  late StreamSubscription<Position> positionStream;
  double compassValue = 0.0;
  final FlutterBluePlus flutterBlue = new FlutterBluePlus();
  List<Map<String, dynamic>> bluetooth_list = [];
  List<Map<String, dynamic>> topblefrombluetooth_list = [];
  List<Map<String, dynamic>> nearestbledetails = [];
  String _deeplink = "";
  String? UserID = "";
  late Timer _timer;
  StreamSubscription? _sub;
  bool _isLoadingBluetooth = true;
  bool _isLoadingLocation = true;
  bool _bluetoothPermissionGranted = false;
  bool _locationPermissionGranted = false;
  Map<String, dynamic> mostFrequentMap = {};

  @override
  void initState() {
    super.initState();

    _streamSubscriptions.add(
      magnetometerEvents.listen(
        (MagnetometerEvent event) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );

    _timer = Timer.periodic(Duration(milliseconds: 3000), (timer) {
      nearestbledetails.clear();
      _sendMessage();
      _sendMessagetolocal();
    });
    _timer = Timer.periodic(Duration(milliseconds: 2000), (timer) {
      showContinuousNotification();
    });
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      ListOfBeaconNearBy();
    });
    checkPermissions();
    startCompassStream();
    localsocket.connect();
    socket.connect();
    _startScan();
    WidgetsBinding.instance!.addObserver(this);



  }

  Map<String, dynamic> findMostFrequentMap(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      throw ArgumentError("Input list is empty");
    }

    Map<Map<String, dynamic>, int> mapCount = {};


    int? maxCount = 0;

    for (var map in list) {
      if (mapCount.containsKey(map)) {
        mapCount[map] = mapCount[map]! + 1; // Handle potential null value
      } else {
        mapCount[map] = 1;
      }
    }

    for (var item in list){
      if(mapCount[item]! > maxCount!){
        maxCount = mapCount[item];
        mostFrequentMap = item;
      }
    }


    print(mostFrequentMap.toString());
    mapCount.clear();
    return mostFrequentMap!;
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && cc==1) {
      String url = 'https://maps.iwayplus.in?redirect=true';
      _launchInBrowser(Uri.parse(url));    }
  }

  void checkPermissions() async {
    // Request Bluetooth permission first
    await requestBluetoothConnectPermission();

    setState(() {
      _bluetoothPermissionGranted = true;
      _isLoadingBluetooth = false;
    });

    // Then check and request location permission
    await checkGps();

    setState(() {
      _locationPermissionGranted = hasgpspermission;
      _isLoadingLocation = false;
    });



    await initUniLinks();
  }

  Future<void> requestBluetoothConnectPermission() async {
    final PermissionStatus permissionStatus =
        await Permission.bluetoothConnect.request();

    if (permissionStatus.isGranted) {
      // Permission granted, you can now perform Bluetooth operations
    } else {
      // Permission denied, handle accordingly
    }
  }

  checkGps() async {
    servicestatus = await Geolocator.isLocationServiceEnabled();
    if (servicestatus) {
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        } else if (permission == LocationPermission.deniedForever) {
          print("'Location permissions are permanently denied");
        } else {
          hasgpspermission = true;
        }
      } else {
        hasgpspermission = true;
      }

      if (hasgpspermission) {
        setState(() {
          //refresh the UI
        });

        getLocation();
      }
    } else {
      print("GPS Service is not enabled, turn on GPS location");
    }
    setState(() {});
  }

  Future<void> initUniLinks() async {
    // Attach a listener to handle incoming deep links
    Uri? initialLink;
    try {
      initialLink = await getInitialUri();
    } catch (e) {
      print('Error getting initial link: $e');
    }

    // Handle the initial deep link if there is one
    if (initialLink != null) {
      handleDeepLink(initialLink);
    } else {
      cc=1;
      _launchInBrowser(Uri.parse('https://maps.iwayplus.in'));
    }

    // Attach a listener for incoming deep links
    uriLinkStream.listen((dynamic uri) {
      handleDeepLink(uri as Uri);
    });
  }

  void handleDeepLink(Uri uri) {
    setState(() {
      _deeplink = uri.toString();
    });

    // Now you can extract parameters from the URI and perform actions accordingly
    UserID = uri.queryParameters['id'];

    // Do something with the parameters
    print('UserID: $_deeplink');
    String url = 'https://maps.iwayplus.in?redirect=true';
    _launchInBrowser(Uri.parse(url));
  }

  getLocation() async {
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    long = position.longitude.toString();
    lat = position.latitude.toString();

    setState(() {});

    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      long = position.longitude.toString();
      lat = position.latitude.toString();
      setState(() {});
    });
  }

  Future<void> startCompassStream() async {
    StreamSubscription<CompassEvent> compassSubscription;

    compassSubscription = FlutterCompass.events!.listen((CompassEvent event) {
      setState(() {
        compassValue = event.heading!;
        if (compassValue < 0.00) {
          compassValue = 360.00 + compassValue;
        }
      });
    });
  }

  void _startScan() {
    FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      // Handle scan results here
      for (ScanResult result in results) {
        String dID = (result.device.remoteId).toString();
        int rssi = result.rssi;

        if (!deviceFilters.containsKey(result.device)) {
          // Create a new Kalman filter for the device
          KalmanFilter kalmanFilter = KalmanFilter(
            processNoise: 0.03, // Adjust these values as needed
            measurementNoise: 8.0, // Adjust these values as needed
            estimate: rssi.toDouble(), // Initial estimate
            errorEstimate: 1.0, // Initial error estimate
          );
          deviceFilters[result.device] = kalmanFilter;
        }

        // Get the Kalman filter for the device
        KalmanFilter? kalmanFilter = deviceFilters[result.device];

        if (kalmanFilter == null) {
          // Create a new Kalman filter for the device
          kalmanFilter = KalmanFilter(
            processNoise: 0.03, // Adjust these values as needed
            measurementNoise: 8.0, // Adjust these values as needed
            estimate: rssi.toDouble(), // Initial estimate
            errorEstimate: 1.0, // Initial error estimate
          );
          deviceFilters[result.device] = kalmanFilter;
        }

        // Perform the Kalman filter prediction and update
        kalmanFilter.predict();
        kalmanFilter.update(rssi.toDouble());

        // The filtered RSSI value for this device
        double filteredRssiforlist = kalmanFilter.estimate;

        if (!rssiValues.containsKey(dID)) {
          rssiValues[dID] =
              []; // Initialize an empty list for the dID if it doesn't exist
        }

        // Ensure that the list for the dID is not null
        if (rssiValues[dID] != null) {
          // Add the latest RSSI value to the list for the dID
          rssiValues[dID]!.add(filteredRssiforlist.toDouble());

          // Ensure that the list for the dID contains at most 10 values
          if (rssiValues[dID]!.length > 10) {
            rssiValues[dID]!.removeAt(
                0); // Remove the oldest value if there are more than 10
          }

          // Calculate the average of the last 10 RSSI values for the dID
          double filteredRssi = rssiValues[dID]!.reduce((a, b) => a + b) /
              rssiValues[dID]!.length;

          Map<String, dynamic> bleitem = {};
          bleitem['"macID"'] = '"$dID"';
          bleitem['"RSSI"'] = filteredRssi;
          estimator.addRssi(dID, filteredRssi.toInt());
          double distanceTemp = estimator.calculateDistance(dID);
          bleitem['"Distance"'] = distanceTemp;
          for (var item in BeaconsNearBy) {
            if (item['macId'] == dID) {
              bleitem['"lat"'] = item['lat'];
              bleitem['"long"'] = item['long'];
              bleitem['"floor"'] = item['floor'];
              bleitem['"x"'] = item['x'];
              bleitem['"y"'] = item['y'];
            }
          }
          bool isKeyPresentinscanned = bluetooth_list
              .any((map) => map.containsKey('"macID"') && map['"macID"'] == '"$dID"');
          bool isKeyPresentinapi = BeaconsNearBy.any(
              (map) => map.containsKey('macId') && map['macId'] == dID);

          if (dID != '' && isKeyPresentinapi && !isKeyPresentinscanned) {
            bluetooth_list.add(bleitem);
          }
          if (isKeyPresentinapi && isKeyPresentinscanned) {
            for (var map in bluetooth_list) {
              if (map['"macID"'] == '"$dID"') {
                map['"RSSI"'] = filteredRssi;
                estimator.addRssi(dID, filteredRssi.toInt());
                double distanceTemp = estimator.calculateDistance(dID);
                map['"Distance"'] = distanceTemp;
              }
            }
          }

          bluetooth_list.sort((a, b) => a['"Distance"'].compareTo(b['"Distance"']));
          if(bluetooth_list.isNotEmpty){
            topblefrombluetooth_list.add(bluetooth_list.first);
          }
          TopThreeBeacons.clear();
          if (bluetooth_list.length >= 3) {
            TopThreeBeacons.addAll(bluetooth_list.sublist(0, 3));
            floor = TopThreeBeacons[0]['"floor"'];
          }
        }
      }
    });

    FlutterBluePlus.startScan();
    _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
  }

  void _sendMessage() {
    if(topblefrombluetooth_list.isNotEmpty){
      findMostFrequentMap(topblefrombluetooth_list);
      nearestbledetails.add(mostFrequentMap);
      topblefrombluetooth_list.clear();
    }

    final Information = "{\n  "
        "\"UserId\": \"$UserID\",\n  "
        "\"buildingID\": \"$nearestBuildingID\",\n  "
    //"\"details\": $bluetooth_list,\n  "
        "\"details\": $nearestbledetails,\n  "
        //"\"details\": $bluetooth_list,\n  "
        "\"magnetometer\": $_magnetometerValues,\n  "
        "\"compass\": ${compassValue.toString()}\n } ";

    socket.emit("beacon_data", Information);
  }

  void _sendMessagetolocal() {
    if(topblefrombluetooth_list.isNotEmpty){
      findMostFrequentMap(topblefrombluetooth_list);
      nearestbledetails.add(mostFrequentMap);
      topblefrombluetooth_list.clear();
    }

    final Information = "{\n  "
        "\"UserId\": \"$UserID\",\n  "
        "\"buildingID\": \"$nearestBuildingID\",\n  "
        //"\"details\": $bluetooth_list,\n  "
        "\"details\": $nearestbledetails,\n  "
        //"\"details\": $bluetooth_list,\n  "
        "\"magnetometer\": $_magnetometerValues,\n  "
        "\"compass\": ${compassValue.toString()}\n } ";

    localsocket.emit("beacon_data", Information);
  }

  @override
  Widget build(BuildContext context) {
    _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth and Location Permission'),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bluetooth Permission',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                _isLoadingBluetooth
                    ? CircularProgressIndicator()
                    : _bluetoothPermissionGranted
                        ? Icon(
                            Icons.check,
                            size: 24,
                            color: Colors.green,
                          )
                        : Icon(
                            Icons.cancel,
                            size: 24,
                            color: Colors.red,
                          ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Location Permission',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                _isLoadingLocation
                    ? CircularProgressIndicator()
                    : _locationPermissionGranted
                        ? Icon(
                            Icons.check,
                            size: 24,
                            color: Colors.green,
                          )
                        : Icon(
                            Icons.cancel,
                            size: 24,
                            color: Colors.red,
                          ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }
}
