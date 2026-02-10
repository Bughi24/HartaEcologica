import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firebase
import 'secret.dart'; // Asigură-te că calea e corectă (poate fi doar 'secret.dart')
import 'add_bin_page.dart'; 

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Color uniformColor = const Color(0xFF2E7D32); 
  final IconData uniformIcon = Icons.delete_rounded;  

  List<dynamic> _allRecyclingElements = []; // Date API Overpass
  List<Marker> _apiMarkers = [];            // Markere API
  List<Marker> _firebaseMarkers = [];       // Markere din Cloud (Firebase)

  LatLng? _userLocation; 
  Set<String> activeFilters = {}; 
  LatLng? _selectedDestination; 
  List<LatLng> _routePoints = []; 
  StreamSubscription<Position>? _positionStream; 
  final MapController _mapController = MapController(); 
  String? _formattedDistance; 
  
  bool _isTrackingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchRecyclingPoints();      // Încarcă datele publice (OSM)
    _listenToFirebaseBins();      // Ascultă datele din Cloud în timp real
    _startLiveLocationUpdates();  // Pornește GPS
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- FIREBASE LOGIC (Partea Nouă) ---

  // 1. Ascultăm modificările în timp real
  void _listenToFirebaseBins() {
    FirebaseFirestore.instance
        .collection('bins') // Numele colecției în baza de date
        .snapshots()        // Stream de date
        .listen((snapshot) {
      
      // De fiecare dată când se schimbă ceva în baza de date, se execută codul ăsta:
      final List<Marker> newMarkers = snapshot.docs.map((doc) {
        final data = doc.data();
        // Verificăm dacă datele există și sunt valide
        if (data['lat'] == null || data['lon'] == null) return null;

        final double lat = (data['lat'] as num).toDouble();
        final double lon = (data['lon'] as num).toDouble();
        final String type = data['type'] ?? 'unknown';
        final String typeRo = _translateType(type);

        return Marker(
          width: 45.0,
          height: 45.0,
          point: LatLng(lat, lon),
          child: _buildUnifiedMarker(
            "Utilizator: $typeRo", 
            () {
               _onMarkerTap(LatLng(lat, lon), "Adăugat de comunitate");
            }
          ),
        );
      }).whereType<Marker>().toList(); // Filtrăm eventualele valori nule

      if (mounted) {
        setState(() {
          _firebaseMarkers = newMarkers;
        });
      }
    });
  }

  // 2. Salvare în Cloud
  Future<void> _addBinToFirebase(double lat, double lon, String type) async {
    try {
      await FirebaseFirestore.instance.collection('bins').add({
        'lat': lat,
        'lon': lon,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(), // E bine să știm când a fost adăugat
      });
    } catch (e) {
      print("Eroare la salvarea în Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la salvarea online.')),
      );
    }
  }

  // --- Helper funcții ---
  
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

  Widget _buildUnifiedMarker(String tooltipText, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipText,
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

  void _onMarkerTap(LatLng destination, String description) {
      setState(() {
        _isTrackingUser = false;
        _selectedDestination = destination;
        
        if (_userLocation != null) {
             final dist = Geolocator.distanceBetween(
                _userLocation!.latitude, _userLocation!.longitude,
                destination.latitude, destination.longitude
             );
             _formattedDistance = dist >= 1000 
                ? '${(dist/1000).toStringAsFixed(2)} km' 
                : '${dist.toStringAsFixed(0)} m';
        } else {
             _formattedDistance = description;
        }
      });
      _getRouteToDestination();
  }

  // --- Adăugare Pubele (Modificat pentru Cloud) ---
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
      
      final double lat = _userLocation!.latitude;
      final double lon = _userLocation!.longitude;

      // SALVĂM ÎN CLOUD
      await _addBinToFirebase(lat, lon, type);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Punct salvat online pentru toți utilizatorii!'),
          backgroundColor: uniformColor,
        ),
      );
    }
  }

  // --- API Overpass ---
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
        if (mounted) {
            setState(() {
            _allRecyclingElements = data['elements'] as List;
            });
            _filterMarkers();
        }
      }
    } catch (e) {
      print('Eroare API: $e');
    }
  }

  // --- Filtrare ---
  void _filterMarkers() {
    setState(() {
      _apiMarkers = _allRecyclingElements.map((element) {
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
               _onMarkerTap(LatLng(lat, lon), name);
            }
          ),
        );
      }).whereType<Marker>().toList();
    });
  }

  // --- Rută ---
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

  Widget _buildFilterChips() {
    final categories = ['plastic', 'paper', 'glass', 'metal', 'batteries'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
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
                    _filterMarkers();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _startLiveLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    _positionStream?.cancel();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 2 
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      if (_isTrackingUser) {
        _mapController.move(
          LatLng(position.latitude, position.longitude), 
          _mapController.camera.zoom
        );
      }

      if (_selectedDestination != null) {
        _getRouteToDestination();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Combinăm markerele API cu cele din Firebase
    List<Marker> allDisplayMarkers = [..._apiMarkers, ..._firebaseMarkers];
    
    if (_userLocation != null) {
      allDisplayMarkers.add(
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harta Reciclării (Online)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: uniformColor,
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
                    initialZoom: 16.0, 
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _isTrackingUser = false;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.garbageselection', 
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
                    MarkerLayer(markers: allDisplayMarkers),
                  ],
                ),
              ),
            ],
          ),
          
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
                  backgroundColor: _isTrackingUser ? Colors.blue : uniformColor,
                  onPressed: () {
                    if (_userLocation != null) {
                      setState(() {
                        _isTrackingUser = true; 
                      });
                      _mapController.move(_userLocation!, 16);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Căutăm locația GPS...'))
                      );
                    }
                  },
                  child: Icon(
                    _isTrackingUser ? Icons.gps_fixed : Icons.gps_not_fixed, 
                    color: Colors.white
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}