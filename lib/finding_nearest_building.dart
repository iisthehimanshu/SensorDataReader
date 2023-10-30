import 'dart:math' as Math;
import 'package:sensor_reader_prototype_websocket/mainscreen.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

String nearestBuildingtemp = '';
String nearestBuildingIDtemp = '';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const int radiusOfEarth = 6371; // Earth's radius in kilometers

  double latDistance = (lat2 - lat1).toRadians();
  double lonDistance = (lon2 - lon1).toRadians();

  double a = Math.pow(Math.sin(latDistance / 2), 2) +
      Math.cos(lat1.toRadians()) *
          Math.cos(lat2.toRadians()) *
          Math.pow(Math.sin(lonDistance / 2), 2);

  double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return radiusOfEarth * c;
}

extension NumExtensions on num {
  double toRadians() => this * (Math.pi / 180);
}


Future<void> NearestBuildingCalculator() async {
  final apiUrl = 'https://maps.iwayplus.in/building/all';
  var urlparse = Uri.parse(apiUrl);
  final response = await http.post(urlparse);

  if (response.statusCode == 200) {

    List<dynamic> buildingsData = json.decode(response.body);

    double userLatitude = double.parse(lat); // User's latitude
    double userLongitude = double.parse(long); // User's longitude
    double minDistance = double.infinity;

    for (var buildingData in buildingsData) {
      List<dynamic> coordinates = buildingData['coordinates'];
      double buildingLatitude = (coordinates[0] as num).toDouble();
      double buildingLongitude = (coordinates[1] as num).toDouble();
      double distance = calculateDistance(userLatitude, userLongitude, buildingLatitude, buildingLongitude);
      if (distance<minDistance  && buildingData["liveStatus"]){
        minDistance = distance;
        nearestBuildingtemp = buildingData['buildingName'];
        nearestBuildingIDtemp=buildingData['_id'];
      }
    }

    nearestBuilding =nearestBuildingtemp;
    nearestBuildingforlink = nearestBuilding.replaceAll(" ", "%20");
    nearestBuildingID =nearestBuildingIDtemp;

  } else {
    print('Failed to fetch data from the server ${response.statusCode}');

}}