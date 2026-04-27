class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String pincode;
  final String fullAddress;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    required this.pincode,
    required this.fullAddress,
  });

  @override
  String toString() =>
      'LocationData(city: $city, state: $state, pincode: $pincode)';
}
