import 'dart:math';

class KalmanFilter {
  double processNoise; // Process noise
  double measurementNoise; // Measurement noise
  double estimatedLat; // Estimated latitude
  double estimatedLong; // Estimated longitude
  double errorLat; // Error in latitude
  double errorLong; // Error in longitude

  KalmanFilter(
      {this.processNoise = 0.1, this.measurementNoise = 1.0, this.estimatedLat = 0.0, this.estimatedLong = 0.0, this.errorLat = 1.0, this.errorLong = 1.0});

  void update(double latMeasurement, double longMeasurement) {
    // Prediction
    double predictedLat = estimatedLat;
    double predictedLong = estimatedLong;
    double predictedErrorLat = errorLat + processNoise;
    double predictedErrorLong = errorLong + processNoise;

    // Update
    double kalmanGainLat = predictedErrorLat / (predictedErrorLat + measurementNoise);
    double kalmanGainLong = predictedErrorLong / (predictedErrorLong + measurementNoise);
    estimatedLat = predictedLat + kalmanGainLat * (latMeasurement - predictedLat);
    estimatedLong = predictedLong + kalmanGainLong * (longMeasurement - predictedLong);
    errorLat = (1 - kalmanGainLat) * predictedErrorLat;
    errorLong = (1 - kalmanGainLong) * predictedErrorLong;
  }
}