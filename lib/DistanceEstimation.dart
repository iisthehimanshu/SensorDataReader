import 'dart:math' as Math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';


// class DistanceEstimator {
//   double measuredPower; // RSSI at reference distance (dBm)
//   double pathLossExponent; // Path loss exponent
//   int windowSize; // Number of RSSI samples to consider in the moving average
//   Map<String, List<int>> rssiBuffers = {};
//
//
//   DistanceEstimator(this.measuredPower, this.pathLossExponent, this.windowSize);
//
//   void addRssi(String beaconIdentifier, int rssi) {
//     // Ensure the buffer exists for the given beacon identifier
//     if (!rssiBuffers.containsKey(beaconIdentifier)) {
//       rssiBuffers[beaconIdentifier] = [];
//     }
//
//     // Add the RSSI value to the buffer
//     rssiBuffers[beaconIdentifier]!.add(rssi);
//
//     // Limit the buffer size (optional)
//     if (rssiBuffers[beaconIdentifier]!.length > windowSize) {
//       rssiBuffers[beaconIdentifier]!.removeAt(0);
//     }
//   }
//
//   List<int> getRssiBuffer(String beaconIdentifier) {
//     // Return the RSSI buffer for the given beacon identifier
//     return rssiBuffers[beaconIdentifier] ?? [];
//   }
//
//   double calculateDistance(String beaconIdentifier) {
//     if (!rssiBuffers.containsKey(beaconIdentifier)) {
//       return double.infinity;
//     }
//
//     List<int> buffer = rssiBuffers[beaconIdentifier]!;
//     if (buffer.isEmpty) {
//       return double.infinity;
//     }
//
//     double sum = buffer.map((rssi) => rssi.toDouble()).reduce((value, element) => value + element);
//     double averageRssi = sum / buffer.length;
//
//     // Calculate the distance as before
//     double distance = pow(10.0, (measuredPower - averageRssi) / (10.0 * pathLossExponent)).toDouble();
//
//     // Detect and remove outliers
//     List<double> distances = buffer.map((rssi) {
//       return pow(10.0, (measuredPower - rssi.toDouble()) / (10.0 * pathLossExponent)).toDouble();
//     }).toList();
//
//     double mean = distances.reduce((value, element) => value + element) / distances.length;
//     double stdDev = sqrt(distances.map((distance) => pow(distance - mean, 2)).reduce((value, element) => value + element) / distances.length);
//
//     double outlierThreshold = 2.0; // Adjust this threshold as needed
//
//     List<double> filteredDistances = distances.where((distance) {
//       return (distance >= mean - outlierThreshold * stdDev) && (distance <= mean + outlierThreshold * stdDev);
//     }).toList();
//
//     double filteredMean = filteredDistances.reduce((value, element) => value + element) / filteredDistances.length;
//
//     return filteredMean;
//   }
// }

class DistanceEstimator {
  double measuredPower; // RSSI at reference distance (dBm)
  double pathLossExponent; // Path loss exponent
  int windowSize; // Number of RSSI samples to consider in the moving average
  Map<String, List<int>> rssiBuffers = {};
  Map<String, List<double>> rssiMovingAverages = {}; // Store moving averages

  DistanceEstimator(this.measuredPower, this.pathLossExponent, this.windowSize);

  void addRssi(String beaconIdentifier, int rssi) {
    // Ensure the buffer exists for the given beacon identifier
    if (!rssiBuffers.containsKey(beaconIdentifier)) {
      rssiBuffers[beaconIdentifier] = [];
    }

    // Add the RSSI value to the buffer
    rssiBuffers[beaconIdentifier]!.add(rssi); // Explicitly cast to double

    // Limit the buffer size (optional)
    if (rssiBuffers[beaconIdentifier]!.length > windowSize) {
      rssiBuffers[beaconIdentifier]!.removeAt(0);
    }
  }

  double calculateDistance(String beaconIdentifier) {
    if (!rssiBuffers.containsKey(beaconIdentifier) ||
        rssiBuffers[beaconIdentifier]!.isEmpty) {
      return -1.0; // Invalid or missing data
    }

    // Calculate the moving average of RSSI values
    double rssiSum = rssiBuffers[beaconIdentifier]!.fold(0, (a, b) => a + b);
    double rssiMovingAverage = rssiSum / rssiBuffers[beaconIdentifier]!.length;

    // Explicitly cast to double to resolve the error
    //double distance = (0.882909233)* Math.pow((rssiMovingAverage/-66.46),4.57459326)+0.045275821;
    double distance = ((Math.log(rssiMovingAverage*(-1)) - Math.log(62.727)).abs()/0.0355);

    return distance;
  }
}