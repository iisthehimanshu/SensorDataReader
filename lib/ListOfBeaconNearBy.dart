import 'dart:convert';
import 'dart:math' as Math;
import 'package:sensor_reader_prototype_websocket/mainscreen.dart';
import 'package:http/http.dart' as http;
import 'finding_nearest_building.dart';

Future<void> ListOfBeaconNearBy() async {
  BeaconsNearBy.clear();
  NearestBuildingCalculator();

  final apiUrl = 'https://maps.iwayplus.in/building/beacons';
  var urlparse = Uri.parse(apiUrl);
  final response = await http.post(urlparse,body: {"buildingId": "${nearestBuildingID.toString()}"});

  if (response.statusCode == 200) {
    List<dynamic> BeaconData = json.decode(response.body);
    for (var beacondata in BeaconData) {
      Map<String, dynamic> itemz = {};
      itemz['macId']= beacondata['properties']['macId'].toString();
      itemz['long'] = double.parse(beacondata['properties']['longitude']);
      itemz['lat'] = double.parse(beacondata['properties']['latitude']);
      itemz['floor'] = beacondata['floor'];
      itemz['x'] = beacondata['coordinateX'];
      itemz['y'] = beacondata['coordinateY'];
      BeaconsNearBy.add(itemz);
    }
  } else {
    print('Failed to fetch data from the server ${response.statusCode}');
  }
}

