import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Modul pentru baza de date NoSQL
import '../secret.dart'; 
import 'add_bin_page.dart'; 

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Constante UI - Iconița default (folosită doar ca fallback)
  final IconData defaultIcon = Icons.delete_rounded;  

  // Structuri de date pentru gestionarea punctelor de interes (POI)
  List<dynamic> _allRecyclingElements = []; // Buffer pentru datele brute preluate din OpenStreetMap
  List<Map<String, dynamic>> _rawFirebaseData = []; // Buffer pentru documentele brute din Firestore)

  List<Marker> _apiMarkers = [];            // Markere generate din datele statice (API)
  List<Marker> _firebaseMarkers = [];       // Markere dinamice sincronizate în timp real (Cloud)

  // Variabile de stare pentru geolocalizare și rutare
  LatLng? _userLocation; 
  Set<String> activeFilters = {}; 
  LatLng? _selectedDestination; 
  List<LatLng> _routePoints = []; // Coordonatele poliliniei pentru afișarea rutei
  StreamSubscription<Position>? _positionStream; 
  final MapController _mapController = MapController(); 
  String? _formattedDistance; 
  
  // Flag pentru modul de urmărire automată a utilizatorului
  bool _isTrackingUser = true;

  @override
  void initState() {
    super.initState();
    // Inițializarea asincronă a serviciilor de date și localizare
    _fetchRecyclingPoints();      // Interogare API extern (Overpass)
    _listenToFirebaseBins();      // Stabilire conexiune WebSocket cu Firestore
    _startLiveLocationUpdates();  // Activare servicii GNSS
  }

  @override
  void dispose() {
    // Eliberarea resurselor și oprirea stream-urilor pentru prevenirea memory leaks
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- LOGICA DE CODIFICARE VIZUALĂ (Visual Encoding) ---
  
  /// Determină culoarea markerului în funcție de tipul deșeului.
  /// Această asociere semantică îmbunătățește viteza de procesare vizuală a utilizatorului.
  Color _getMarkerColor(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return Colors.amber.shade700;
      case 'paper': return Colors.blue.shade600;
      case 'glass': return Colors.green.shade600;
      case 'metal': return Colors.grey.shade700;
      case 'batteries': return Colors.red.shade600;
      case 'mixed': return Colors.purple.shade600; // Culoare distinctivă pentru puncte multi-colectare
      default: return const Color(0xFF2E7D32);     // Fallback (Verde)
    }
  }

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

  // Generator de widget-uri pentru reprezentarea vizuală a markerelor
  // Semnătura corectă: Text -> Tip -> Funcție
  Widget _buildUnifiedMarker(String tooltipText, String type, VoidCallback onTap) {
    final Color markerColor = _getMarkerColor(type);
    
    // Logică de selecție a iconiței: 
    // Dacă punctul este mixt, folosim simbolul universal de reciclare.
    // Altfel, folosim simbolul standard de recipient.
    final IconData markerIcon = type == 'mixed' ? Icons.recycling : Icons.delete_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipText,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: markerColor, width: 3), // Bordură colorată semantic
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Icon(
            markerIcon, 
            color: markerColor, 
            size: 24, 
          ),
        ),
      ),
    );
  }

  // --- LOGICA DE SINCRONIZARE CLOUD (Firebase Firestore) ---

  /// Inițializează un ascultător (listener) pe colecția 'bins' din Firestore.
  /// Această metodă asigură actualizarea reactivă a interfeței (UI).
  void _listenToFirebaseBins() {
    FirebaseFirestore.instance
        .collection('bins') // Referință către colecția NoSQL
        .snapshots()        // Stream de documente (Snapshot-uri)
        .listen((snapshot) {
        
        List<Map<String, dynamic>> tempData = [];
        for(var doc in snapshot.docs) {
          final data = doc.data();
          if(data['lat'] != null && data['lon'] != null)
          {
            tempData.add(data);
          }
        }
        
        if(mounted){
          setState(() {
            _rawFirebaseData = tempData; // Actualizare buffer de date brute
        });
        _filterMarkers(); // Reaplicare filtre și regenerare markere{}
        }});
      
  }

  /// Persistă un nou punct de colectare în infrastructura Cloud.
  Future<void> _addBinToFirebase(double lat, double lon, String type) async {
    try {
      await FirebaseFirestore.instance.collection('bins').add({
        'lat': lat,
        'lon': lon,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(), 
      });
    } catch (e) {
      debugPrint("Eroare la persistența datelor în Cloud: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la salvarea online.')),
      );
    }
  }

  /// Gestionează interacțiunea utilizatorului cu un marker.
  void _onMarkerTap(LatLng destination, String description) {
      setState(() {
        _isTrackingUser = false; // Dezactivează centrarea automată
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

  // --- Modulul de Validare și Adăugare (Computer Vision Integration) ---
  Future<void> _addNewBin() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se așteaptă triangularea GPS...')),
      );
      return;
    }

    // Navigare către modulul de clasificare a imaginii
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBinPage()),
    );

    if (result != null && result is Map) {
      final String type = result['type']; 
      
      final double lat = _userLocation!.latitude;
      final double lon = _userLocation!.longitude;

      // Declanșarea procedurii de scriere în baza de date
      await _addBinToFirebase(lat, lon, type);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Punct sincronizat cu succes în rețea!'),
          backgroundColor: _getMarkerColor(type),
        ),
      );
    }
  }

  // --- Integrare API OpenStreetMap (Overpass) ---
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
      debugPrint('Eroare la interogarea API Overpass: $e');
    }
  }

  // --- Filtrare și Procesare Date ---
  /// Aplică filtrele active și determină dacă un punct este "Mixt" sau simplu.
  void _filterMarkers() {
    setState(() {
      _apiMarkers = _allRecyclingElements.map((element) {
        final lat = element['lat'];
        final lon = element['lon'];
        final tags = element['tags'] ?? {};
        final name = tags['name'] ?? 'Punct reciclare';
        
        // Extragerea categoriilor de reciclare din tag-urile OSM
        final types = [
          if (tags['recycling:plastic'] == 'yes') 'plastic',
          if (tags['recycling:paper'] == 'yes') 'paper',
          if (tags['recycling:glass'] == 'yes') 'glass',
          if (tags['recycling:metal'] == 'yes') 'metal',
          if (tags['recycling:batteries'] == 'yes') 'batteries',
        ];

        // Logica de intersecție pentru filtrare
        if (activeFilters.isNotEmpty && activeFilters.intersection(types.toSet()).isEmpty) {
          return null;
        }
        

        String infoText = name;
        String primaryType = 'unknown'; 
        
        // --- LOGICA DE AGREGARE VIZUALĂ ---
        if (types.length > 1) {
           // Dacă sunt mai multe tipuri, clasificăm punctul ca MIXT (Centru Colectare)
           primaryType = 'mixed';
           String typesRo = types.map((t) => _translateType(t)).join(", ");
           infoText += "\nCentru Colectare: $typesRo";
        } else if (types.isNotEmpty) {
           // Dacă e un singur tip, îl preluăm pe acela
           primaryType = types.first; 
           String typesRo = _translateType(primaryType);
           infoText += "\nAcceptă: $typesRo";
        }

        return Marker(
          width: 45.0,
          height: 45.0,
          point: LatLng(lat, lon),
          child: _buildUnifiedMarker(
            infoText,
            primaryType, // Parametrul Tip (poate fi 'mixed' sau specific)
            () {
               _onMarkerTap(LatLng(lat, lon), name);
            }
          ),
        );
      }).whereType<Marker>().toList();

      _firebaseMarkers = _rawFirebaseData.map((data){
        final double lat = (data['lat'] as num).toDouble();
        final double lon = (data['lon'] as num).toDouble();
        final String type = data['type'] ?? 'unknown';

        if(activeFilters.isNotEmpty && !activeFilters.contains(type)) {
          return null;
        }

        final String typeRo = _translateType(type);
        return Marker(
          width: 45.0,
          height: 45.0,
          point: LatLng(lat, lon),
          child: _buildUnifiedMarker(
            'Punct adăugat de utilizatori\nAcceptă: $typeRo',
            type,
            () {
              _onMarkerTap(LatLng(lat, lon), 'Punct adăugat de utilizatori');
            }
          ),
          );
      }).whereType<Marker>().toList();
      });
  }

  // --- Serviciu de Rutare (OpenRouteService) ---
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
      debugPrint("Eroare la calculul rutei: $e");
    }
  }

  // Widget pentru zona de filtrare (Chips) cu culori dinamice
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
            final typeColor = _getMarkerColor(category); // Culoare dinamică

            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FilterChip(
                label: Text(
                  _translateType(category), 
                  style: TextStyle(
                    color: isSelected ? Colors.white : typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSelected,
                checkmarkColor: Colors.white,
                selectedColor: typeColor, 
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: typeColor), 
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

  // --- Geolocalizare ---
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
    // Agregarea surselor de date (API + Cloud) într-un singur strat de afișare
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
        backgroundColor: const Color(0xFF2E7D32),
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
                            color: const Color(0xFF2E7D32), 
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
                    const Icon(Icons.directions_walk, color: Colors.green),
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
                  backgroundColor: _isTrackingUser ? Colors.blue : const Color(0xFF2E7D32),
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