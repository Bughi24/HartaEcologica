import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'services/database_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // --- LOGICA TFLITE ---
  Interpreter? interpreter;
  List<String> labels = [];
  String? imagePath;
  bool isInferencing = false;
  static const int inputSize = 224; 

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/model/model_augmentation.tflite', 
      );
      final rawLabels = await rootBundle.loadString('assets/model/labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
      debugPrint("Model AI pregătit.");
    } catch (e) {
      debugPrint("Eroare model: $e");
    }
  }
  Future<void> pickImage() async {
    final picker = ImagePicker();
    
    // Resetăm obligatoriu înainte de orice acțiune
    setState(() {
      isInferencing = false; 
      imagePath = null;
    });

    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 85, // Optimizat pentru viteză
    );

    if (file == null) return; // Utilizatorul a închis camera

    setState(() {
      imagePath = file.path;
      isInferencing = true; // Pornim animația
    });

    // Mic delay pentru a lăsa UI-ul să respire
    await Future.delayed(const Duration(milliseconds: 150));
    await classify(File(file.path));
  }

  Future<void> classify(File imageFile) async {
    final DatabaseService db = DatabaseService();

    if (interpreter == null) {
      setState(() => isInferencing = false);
      return;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Imagine coruptă");

      img.Image baseImage = img.bakeOrientation(originalImage);
      List<double> totalScores = List.filled(labels.length, 0.0);

      // Executăm cele 3 inferențe (TTA)
      await _runInference(baseImage, totalScores);
      await _runInference(img.copyRotate(baseImage, angle: 90), totalScores);
      await _runInference(img.copyFlip(baseImage, direction: img.FlipDirection.horizontal), totalScores);

      double maxScore = -1;
      int maxIdx = -1;

      for (int i = 0; i < totalScores.length; i++) {
        double avgScore = totalScores[i] / 3.0;
        if (avgScore > maxScore) {
          maxScore = avgScore;
          maxIdx = i;
        }
      }

      String detectedLabel = labels[maxIdx];
      if (maxScore < 0.55) detectedLabel = 'trash';

      if (mounted) {
        setState(() => isInferencing = false);
        await db.saveScan(detectedLabel, maxScore);
        Navigator.pushNamed(
          context, 
          '/result', 
          arguments: {
            'label': detectedLabel,
            'confidence': maxScore,
          },
        );
      }
    } catch (e) {
      debugPrint("Eroare clasificare: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Eroare la procesare: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isInferencing = false);
      }
    }
  }

  Future<void> _runInference(img.Image imgToAnalyze, List<double> accumulator) async {
    img.Image resized = img.copyResizeCropSquare(imgToAnalyze, size: inputSize);
    var input = List.generate(1, (batch) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
      final pixel = resized.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    })));

    var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);
    interpreter!.run(input, output);
    
    var scores = output[0] as List<double>;
    for (int i = 0; i < scores.length; i++) {
      accumulator[i] += scores[i];
    }
  }

  @override
  void dispose() {
    interpreter?.close(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const Spacer(),
              _buildScannerVizor(),
              const SizedBox(height: 40),
              _buildInfoPanel(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "ANALIZĂ MATERIAL",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerVizor() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 320,
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 2),
            ),
            child: imagePath == null
                ? _buildEmptyState()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.file(File(imagePath!), fit: BoxFit.cover),
                  ),
          ),
          if (imagePath != null && isInferencing)
            const ScannerAnimation(width: 320, height: 320),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.center_focus_weak_rounded, size: 60, color: Colors.cyan.withOpacity(0.5)),
        const SizedBox(height: 15),
        const Text("Încadrează obiectul în centru", style: TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: isInferencing 
          ? _buildProcessingState() 
          : _buildReadyState(),
      ),
    );
  }

  Widget _buildProcessingState() {
    return const Column(
      children: [
        LinearProgressIndicator(backgroundColor: Colors.white10, color: Colors.cyanAccent),
        const SizedBox(height: 20),
        Text(
          "PROCESARE TTA (Ensemble)...",
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildReadyState() {
    return Column(
      children: [
        const Text("Sistemul MobileNetV2 este pregătit", style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.camera_enhance_rounded),
            label: const Text("PORNEȘTE SCANAREA", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }
}

// --- WIDGET ANIMAȚIE SCANARE ---
class ScannerAnimation extends StatefulWidget {
  final double width;
  final double height;
  const ScannerAnimation({super.key, required this.width, required this.height});

  @override
  State<ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<ScannerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _controller.value * (widget.height - 40) + 20,
              child: Container(
                width: widget.width,
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                  gradient: const LinearGradient(colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}