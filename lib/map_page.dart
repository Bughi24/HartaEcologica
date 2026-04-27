import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../secret.dart';
import 'add_bin_page.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final IconData defaultIcon = Icons.delete_rounded;

  List<dynamic> _allRecyclingElements = [];
  List<Map<String, dynamic>> _rawFirebaseData = [];

  List<Marker> _apiMarkers = [];
  List<Marker> _firebaseMarkers = [];

  LatLng? _userLocation;
  Set<String> activeFilters = {};
  LatLng? _selectedDestination;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();
  String? _formattedDistance;

  bool _isTrackingUser = true;

  // Gardă pentru a aplica filtrul din argumente o singură dată
  bool _filtersInitialized = false;

  final _cacheStore = MemCacheStore();

  @override
  void initState() {
    super.initState();
    _fetchRecyclingPoints();
    _listenToFirebaseBins();
    _startLiveLocationUpdates();
  }

  // didChangeDependencies este primul loc unde putem accesa ModalRoute
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Aplicăm filtrul din argumente o singură dată
    if (!_filtersInitialized) {
      _filtersInitialized = true;

      final String? filterArg =
          ModalRoute.of(context)?.settings.arguments as String?;

      if (filterArg != null && filterArg.isNotEmpty) {
        setState(() {
          activeFilters.add(filterArg);
        });
        // _filterMarkers va fi apelat după ce datele sunt încărcate,
        // dar dacă sunt deja disponibile, le filtrăm imediat
        _filterMarkers();
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Color _getMarkerColor(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return Colors.amber.shade700;
      case 'paper': return Colors.blue.shade600;
      case 'glass': return Colors.green.shade600;
      case 'metal': return Colors.grey.shade700;
      case 'batteries': return Colors.red.shade600;
      case 'mixed': return Colors.purple.shade600;
      default: return const Color(0xFF2E7D32);
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

  Widget _buildUnifiedMarker(String tooltipText, String type, VoidCallback onTap) {
    final Color markerColor = _getMarkerColor(type);
    final IconData markerIcon = type == 'mixed' ? Icons.recycling : Icons.delete_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipText,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: markerColor, width: 3),
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

  void _listenToFirebaseBins() {
    FirebaseFirestore.instance
        .collection('bins')
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> tempData = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['lat'] != null && data['lon'] != null) {
          tempData.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _rawFirebaseData = tempData;
        });
        _filterMarkers();
      }
    });
  }

  Future<void> _addBinToFirebase(double lat, double lon, List<String> types) async {
    try {
      await FirebaseFirestore.instance.collection('bins').add({
        'lat': lat,
        'lon': lon,
        'types': types,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Eroare la persistența datelor în Cloud: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la salvarea online.')),
      );
    }
  }

  void _onMarkerTap(LatLng destination, String description) {
    setState(() {
      _isTrackingUser = false;
      _selectedDestination = destination;

      if (_userLocation != null) {
        final dist = Geolocator.distanceBetween(
          _userLocation!.latitude, _userLocation!.longitude,
          destination.latitude, destination.longitude,
        );
        _formattedDistance = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(2)} km'
            : '${dist.toStringAsFixed(0)} m';
      } else {
        _formattedDistance = "Distanță necunoscută";
      }
    });

    _getRouteToDestination();
    _showRouteDetailsSheet(description);
  }

  void _showRouteDetailsSheet(String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.only(top: 15, left: 24, right: 24, bottom: 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.directions_walk_rounded, color: Colors.green, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Traseu Pietonal",
                          style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formattedDistance ?? "Calculare...",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 24),
                  label: const Text("Am înțeles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {});
  }

  Future<void> _addNewBin() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se așteaptă triangularea GPS...')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBinPage()),
    );

    if (result != null && result is Map) {
      final List<String> types = List<String>.from(result['types']);
      final double lat = _userLocation!.latitude;
      final double lon = _userLocation!.longitude;

      await _addBinToFirebase(lat, lon, types);

      Color snackColor = types.length > 1
          ? Colors.purple.shade600
          : _getMarkerColor(types.first);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Punct sincronizat cu succes în rețea!'),
          backgroundColor: snackColor,
        ),
      );
    }
  }

  Future<void> _fetchRecyclingPoints() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? cachedData = prefs.getString('osm_recycling_cache');
    if (cachedData != null) {
      final decodedData = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _allRecyclingElements = decodedData['elements'] as List;
        });
        _filterMarkers();
        debugPrint("📍 Date OSM încărcate din Cache (Offline)");
      }
    }

    final overpassQuery = '''
      [out:json][timeout:15];
      area["name"="România"]->.searchArea;
      node["amenity"="recycling"](area.searchArea);
      out body;
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': overpassQuery},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await prefs.setString('osm_recycling_cache', response.body);

        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _allRecyclingElements = data['elements'] as List;
          });
          _filterMarkers();
          debugPrint("🌍 Date OSM actualizate de pe Server");
        }
      }
    } catch (e) {
      debugPrint('⚠️ Notă: Nu s-au putut actualiza punctele (Internet slab). Folosim cache-ul existent.');
    }
  }

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
        String primaryType = 'unknown';

        if (types.length > 1) {
          primaryType = 'mixed';
          String typesRo = types.map((t) => _translateType(t)).join(", ");
          infoText += "\nCentru Colectare: $typesRo";
        } else if (types.isNotEmpty) {
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
            primaryType,
            () => _onMarkerTap(LatLng(lat, lon), name),
          ),
        );
      }).whereType<Marker>().toList();

      _firebaseMarkers = _rawFirebaseData.map((data) {
        final double lat = (data['lat'] as num).toDouble();
        final double lon = (data['lon'] as num).toDouble();

        final List<String> types = data['types'] != null
            ? List<String>.from(data['types'])
            : (data['type'] != null ? [data['type']] : []);

        if (activeFilters.isNotEmpty && activeFilters.intersection(types.toSet()).isEmpty) {
          return null;
        }

        String infoText = 'Punct adăugat de utilizatori';
        String primaryType = 'unknown';

        if (types.length > 1) {
          primaryType = 'mixed';
          String typesRo = types.map((t) => _translateType(t)).join(", ");
          infoText += "\nCentru Colectare: $typesRo";
        } else if (types.isNotEmpty) {
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
            primaryType,
            () => _onMarkerTap(LatLng(lat, lon), 'Punct adăugat de utilizatori'),
          ),
        );
      }).whereType<Marker>().toList();
    });
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

  Widget _buildFilterChips() {
    final categories = ['plastic', 'paper', 'glass', 'metal', 'batteries'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected = activeFilters.contains(category);
            final typeColor = _getMarkerColor(category);

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
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      if (_isTrackingUser) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
      }

      if (_selectedDestination != null) {
        _getRouteToDestination();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 25),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Harta Reciclării',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
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
                      tileProvider: CachedTileProvider(
                        store: _cacheStore,
                        maxStale: const Duration(days: 30),
                      ),
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: const Color(0xFF2E7D32),
                          ),
                        ],
                      ),
                    MarkerLayer(markers: allDisplayMarkers),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
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
                        const SnackBar(content: Text('Căutăm locația GPS...')),
                      );
                    }
                  },
                  child: Icon(
                    _isTrackingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: Colors.white,
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