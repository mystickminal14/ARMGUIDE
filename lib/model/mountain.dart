class Mountain {
  final String name;
  final double latitude;
  final double longitude;
  final double elevation;

  Mountain({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'elevation': elevation,
  };

  factory Mountain.fromMap(Map<String, dynamic> map) {
    return Mountain(
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      elevation: map['elevation'],
    );
  }
}
