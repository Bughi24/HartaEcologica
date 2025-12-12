import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'secret.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Marker> _markers = []; // Puncte de reciclare
  LatLng? _userLocation; //locatie utilizator
  Set<String> activeFilters = {}; //filtre active
  LatLng? _selectedDestination; //destinatie selectata
  List<LatLng> _routePoints = []; //puncte traseu
  StreamSubscription<Position>? _positionStream; //stream pozitie
  final MapController _mapController = MapController(); //controller harta
  String? _formattedDistance; //distanta


  @override
  void initState() {
    super.initState();
    _fetchRecyclingPoints();
    _goToCurrentLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

// Preia punctele de reciclare din Overpass API
  Future<void> _fetchRecyclingPoints() async {
    final overpassQuery = '''
    [out:json][timeout:25];
    area["name"="România"]->.searchArea;
    node["amenity"="recycling"](area.searchArea);
    out body;
    ''';

    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': overpassQuery},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final elements = data['elements'] as List;

      setState(() {
        _markers = elements.map((element) {
          final lat = element['lat'];
          final lon = element['lon'];
          final tags = element['tags'] ?? {};
          final name = tags['name'] ?? 'Punct reciclare';
          final types = [
            if (tags['recycling:plastic'] == 'yes') 'plastic',
            if (tags['recycling:paper'] == 'yes') 'paper',
            if (tags['recycling:glass'] == 'yes') 'glass',
            if (tags['recycling:metal'] == 'yes') 'metal',
            if (tags['recycling:batteries'] == 'yes') 'batteries',
          ];

          if (activeFilters.isNotEmpty && activeFilters.intersection(types.toSet()).isEmpty) {
            return null;
          }

          return Marker(
            width: 40.0,
            height: 40.0,
            point: LatLng(lat, lon),
            child: GestureDetector(
              onTap: () {
                final destination = LatLng(lat, lon);
                final distanceMeters = _userLocation != null
                    ? Geolocator.distanceBetween(
                        _userLocation!.latitude,
                        _userLocation!.longitude,
                        destination.latitude,
                        destination.longitude,
                      )
                    : 0;
                final formattedDistance = distanceMeters >= 1000
                    ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
                    : '${distanceMeters.toStringAsFixed(0)} m';
                setState(() {
                  _selectedDestination = LatLng(lat, lon);
                  _formattedDistance = formattedDistance;
                });
                _getRouteToDestination();

              },
              child: Tooltip(
                message: name,
                child: Icon(Icons.delete, color: Colors.green, size: 40),
              ),
            ),
          );
        }).whereType<Marker>().toList();
      });
    } else {
      print('Eroare la Overpass API: ${response.statusCode}');
    }
  }

  Future<void> _getRouteToDestination() async {
    if (_userLocation == null || _selectedDestination == null) return;

    const apiKey = Secret.orsApiKey;
    final url = Uri.parse('https://api.openrouteservice.org/v2/directions/foot-walking/geojson');

    final body = jsonEncode({
      "coordinates": [
        [_userLocation!.longitude, _userLocation!.latitude],
        [_selectedDestination!.longitude, _selectedDestination!.latitude]
      ]
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['features'][0]['geometry']['coordinates'] as List;

      setState(() {
        _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      });
    } else {
      print('Eroare la cererea de rută: ${response.statusCode}');
    }
  }

  Widget _buildFilterChips() {
    final categories = ['plastic', 'paper', 'glass', 'metal', 'batteries'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
       border: Border.all(color: Colors.green.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected = activeFilters.contains(category);
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FilterChip(
                label: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.green.shade600,
                backgroundColor: Colors.green.shade100,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      activeFilters.add(category);
                    } else {
                      activeFilters.remove(category);
                    }
                    _fetchRecyclingPoints();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviciul de localizare este dezactivat.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return Future.error('Permisiunea de localizare este refuzata');
      }
    }
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      if (_selectedDestination != null) {
        _getRouteToDestination();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> allMarkers = List.from(_markers);
    if (_userLocation != null) {
      allMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _userLocation!,
          child: Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Harta reciclării',style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        elevation: 4,
      ),
      backgroundColor: Colors.green.shade100,
      body: Stack(
        children: [
          Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation ?? LatLng(45.9432, 24.9668),
                initialZoom: 6.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.green.shade800,  
                    ),
                  ]
                ),
                MarkerLayer(markers: allMarkers),
              ],
            ),
          ),
        ],
      ),
      if(_selectedDestination != null && _formattedDistance != null)
      Positioned(
        bottom: 90,
        left: 16,
        right: 16,
        child: Container(
          padding : EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0,2),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions, color: Colors.green.shade800),
              SizedBox(width: 8),
              Text('Distanța până la destinație: $_formattedDistance', style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600)),
            ],          ),
          ),
        ),
    Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        backgroundColor: Colors.green.shade600,
        onPressed: (){
          if (_userLocation !=null){
            _mapController.move(_userLocation!, 16);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Localizarea utilizatorului nu este disponibilă.'))
            );
          }
        }, child: Icon(Icons.my_location, color: Colors.white),
      ),
    ),
        ],
      ),
    );
  }
}
