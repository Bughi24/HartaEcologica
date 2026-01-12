import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'secret.dart';
import 'add_bin_page.dart'; 

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Color uniformColor = const Color(0xFF2E7D32); 
  final IconData uniformIcon = Icons.delete_rounded;  

  List<Marker> _markers = []; 
  LatLng? _userLocation; 
  Set<String> activeFilters = {}; 
  LatLng? _selectedDestination; 
  List<LatLng> _routePoints = []; 
  StreamSubscription<Position>? _positionStream; 
  final MapController _mapController = MapController(); 
  String? _formattedDistance; 

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

  // Traducere tip deșeu
  String _translateType(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return 'PLASTIC';
      case 'paper': return 'HÂRTIE';
      case 'glass': return 'STICLĂ';
      case 'metal': return 'METAL';
      case 'batteries': return 'BATERII';
      default: return type.toUpperCase();
    }
  }

  // Marker unitar pentru toate tipurile
  Widget _buildUnifiedMarker(String tooltipText, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipText,
        // Marker design unitar
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: uniformColor, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Icon(
            uniformIcon, 
            color: uniformColor, 
            size: 24, 
          ),
        ),
      ),
    );
  }

  // Adaugare punct de reciclare nou
  Future<void> _addNewBin() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Așteptăm localizarea GPS...')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBinPage()),
    );

    if (result != null && result is Map) {
      final String type = result['type']; 
      final String typeRo = _translateType(type); 
      
      setState(() {
        _markers.add(
          Marker(
            width: 45.0,
            height: 45.0,
            point: _userLocation!, 
            
            child: _buildUnifiedMarker(
              "Adăugat de tine ($typeRo)", 
              () {
                setState(() {
                  _selectedDestination = _userLocation!;
                  _formattedDistance = "0 m (Adăugat de tine)";
                });
              }
            ),
          )
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Punct de reciclare ($typeRo) adăugat cu succes!'),
          backgroundColor: uniformColor,
        ),
      );
    }
  }

  // Fetch puncte de reciclare din Overpass API
  Future<void> _fetchRecyclingPoints() async {
    final overpassQuery = '''
    [out:json][timeout:25];
    area["name"="România"]->.searchArea;
    node["amenity"="recycling"](area.searchArea);
    out body;
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': overpassQuery},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        setState(() {
          List<Marker> apiMarkers = elements.map((element) {
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

            String infoText = name;
            if (types.isNotEmpty) {
              String typesRo = types.map((t) => _translateType(t)).join(", ");
              infoText += "\nAcceptă: $typesRo";
            }

            return Marker(
              width: 40.0,
              height: 40.0,
              point: LatLng(lat, lon),
              child: _buildUnifiedMarker(
                infoText,
                () {
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
                }
              ),
            );
          }).whereType<Marker>().toList();
          
          _markers = apiMarkers; 
        });
      }
    } catch (e) {
      print('Eroare API: $e');
    }
  }

  // Rutare către destinație
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

    try {
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
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final coords = features[0]['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
          });
        }
      }
    } catch (e) {
      print("Eroare rută: $e");
    }
  }

  // Filtre pentru tipuri de deșeuri
  Widget _buildFilterChips() {
    final categories = ['plastic', 'paper', 'glass', 'metal', 'batteries'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))
        ]
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
                  _translateType(category), 
                  style: TextStyle(
                    color: isSelected ? Colors.white : uniformColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                checkmarkColor: Colors.white,
                selectedColor: uniformColor, 
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: uniformColor), 
                ),
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

  // Obținerea locației curente
  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
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
    // Markerul pentru utilizator 
    if (_userLocation != null) {
      allMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _userLocation!,
          child: Container(
             decoration: const BoxDecoration(
               color: Colors.white,
               shape: BoxShape.circle,
               boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
             ),
             child: const Icon(Icons.my_location, color: Colors.blue, size: 25),
          ),
        ),
      );
    }
    // Construirea hărții
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harta Reciclării', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: uniformColor, // Verde
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(45.9432, 24.9668),
                    initialZoom: 13.0,
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
                            strokeWidth: 5.0,
                            color: uniformColor, 
                          ),
                        ]
                      ),
                    MarkerLayer(markers: allMarkers),
                  ],
                ),
              ),
            ],
          ),
          
          // Card distanță
          if (_selectedDestination != null && _formattedDistance != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, color: uniformColor),
                    const SizedBox(width: 8),
                    Text(
                      'Distanța: $_formattedDistance',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                    ),
                  ],
                ),
              ),
            ),
          
          
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "btn_add",
                  backgroundColor: Colors.orange, 
                  onPressed: _addNewBin,
                  child: const Icon(Icons.add_a_photo, color: Colors.white),
                ),
                const SizedBox(height: 15),
                FloatingActionButton(
                  heroTag: "btn_loc", 
                  backgroundColor: uniformColor,
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 16);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Localizarea utilizatorului nu este disponibilă.'))
                      );
                    }
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}