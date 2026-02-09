import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'secret.dart'; // Asigură-te că ai fișierul secret.dart cu cheia API
import 'add_bin_page.dart'; 

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Color uniformColor = const Color(0xFF2E7D32); 
  final IconData uniformIcon = Icons.delete_rounded;  

  List<dynamic> _allRecyclingElements = [];
  List<Marker> _markers = []; 
  LatLng? _userLocation; 
  Set<String> activeFilters = {}; 
  LatLng? _selectedDestination; 
  List<LatLng> _routePoints = []; 
  StreamSubscription<Position>? _positionStream; 
  final MapController _mapController = MapController(); 
  String? _formattedDistance; 
  
  // Variabilă pentru urmărirea automată a utilizatorului
  bool _isTrackingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchRecyclingPoints();
    _startLiveLocationUpdates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- Traducere Tipuri ---
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

  // --- Marker Design ---
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

  // --- Adăugare Pubele ---
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
                  _isTrackingUser = false;
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

  // FUNCȚIA 1: Descarcă datele de pe net (Se rulează doar la început)
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
        
        setState(() {
          // Salvăm datele brute în memorie
          _allRecyclingElements = data['elements'] as List;
        });

        // După ce am descărcat, aplicăm filtrele (inițial arată tot)
        _filterMarkers();
      }
    } catch (e) {
      print('Eroare API: $e');
    }
  }

  // FUNCȚIA 2: Filtrează datele din memorie (Se rulează instant la click)
  void _filterMarkers() {
    setState(() {
      List<Marker> filteredMarkers = _allRecyclingElements.map((element) {
        final lat = element['lat'];
        final lon = element['lon'];
        final tags = element['tags'] ?? {};
        final name = tags['name'] ?? 'Punct reciclare';
        
        // Identificăm tipurile
        final types = [
          if (tags['recycling:plastic'] == 'yes') 'plastic',
          if (tags['recycling:paper'] == 'yes') 'paper',
          if (tags['recycling:glass'] == 'yes') 'glass',
          if (tags['recycling:metal'] == 'yes') 'metal',
          if (tags['recycling:batteries'] == 'yes') 'batteries',
        ];

        // LOGICA DE FILTRARE:
        // Dacă avem filtre active ȘI punctul nu are niciunul din tipurile selectate, îl ignorăm (return null)
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
              setState(() => _isTrackingUser = false);
              
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
      
      // Actualizăm doar lista de markere afișate
      _markers = filteredMarkers;
    });
  }

  // --- Calcul Rută ---
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

  // --- Filtre UI ---
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

  // --- Live Location Logic ---
  Future<void> _startLiveLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    _positionStream?.cancel();
    
    // Setăm filtrul la 2 metri pentru mișcare fluidă
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 2 
      ),
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      // Dacă modul "Urmărire" e activ, mutăm harta automat
      if (_isTrackingUser) {
        _mapController.move(
          LatLng(position.latitude, position.longitude), 
          _mapController.camera.zoom
        );
      }

      // Recalculăm ruta în timp real
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
        title: const Text('Harta Reciclării', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    // Când userul trage de hartă, oprim urmărirea automată
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _isTrackingUser = false;
                        });
                      }
                    },
                  ),
                  children: [
                    // --- MODIFICARE CHEIE: CartoDB Voyager TileLayer ---
                    TileLayer(
                      // Aceasta este sursa care NU este blocată și arată modern
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.garbageselection', // Identificare obligatorie
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