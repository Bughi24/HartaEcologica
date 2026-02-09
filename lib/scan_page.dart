import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesar pentru rootBundle
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  Interpreter? interpreter;
  List<String> labels = [];
  String? imagePath;
  bool isBusy = false;

  // --- CONFIGURARE PENTRU MODELUL EXISTENT ---
  // Păstrăm 150x150 pentru că este stabil și funcțional.
  static const int inputSize = 150; 

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      // Încărcare Model (versiunea stabilă)
      interpreter = await Interpreter.fromAsset(
        'assets/model/garbage_classification_model_v2.tflite',
      );

      // Încărcare Labels
      final rawLabels = await rootBundle.loadString('assets/model/labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
      
      print("Model stabil încărcat. Labels: ${labels.length}");
    } catch (e) {
      debugPrint("EROARE ÎNCĂRCARE MODEL: $e");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    // Setări optimizate pentru o calitate mai bună a pozei
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, // Rezoluție decentă pentru claritate
      imageQuality: 100, // Calitate maximă
      preferredCameraDevice: CameraDevice.rear,
    );

    if (file == null) return;

    setState(() {
      imagePath = file.path;
      isBusy = true; // Pornim loader-ul
    });

    // Mică pauză pentru ca UI-ul să se randeze
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Pornim clasificarea inteligentă
    await classify(File(file.path));
  }

  // --- LOGICA DE CLASIFICARE CU "VOTARE" (Ensemble) ---
  Future<void> classify(File imageFile) async {
    if (interpreter == null) {
      print("Interpreter este null!");
      setState(() => isBusy = false);
      return;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) return;

      // 1. Imaginea de bază (orientare corectă)
      img.Image baseImage = img.bakeOrientation(originalImage);

      // Inițializăm lista de scoruri (acumulator) cu 0.0
      List<double> totalScores = List.filled(labels.length, 0.0);

      // --- RUNDA 1: Imagine Normală ---
      await _runInference(baseImage, totalScores);

      // --- RUNDA 2: Imagine Rotită (90 grade) ---
      // Ajută mult dacă utilizatorul ține telefonul sau obiectul puțin strâmb
      img.Image rotated = img.copyRotate(baseImage, angle: 90);
      await _runInference(rotated, totalScores);

      // --- RUNDA 3: Imagine Oglindită (Flip Horizontal) ---
      // Ajută modelul să recunoască forma indiferent de cum e așezată stânga/dreapta
      img.Image flipped = img.copyFlip(baseImage, direction: img.FlipDirection.horizontal);
      await _runInference(flipped, totalScores);

      // --- CALCUL FINAL (Media celor 3 runde) ---
      double maxScore = -1;
      int maxIdx = -1;

      for (int i = 0; i < totalScores.length; i++) {
        // Împărțim la 3.0 pentru a obține media reală (0.0 - 1.0)
        double avgScore = totalScores[i] / 3.0;
        
        if (avgScore > maxScore) {
          maxScore = avgScore;
          maxIdx = i;
        }
      }

      String detectedLabel = labels[maxIdx];

      // LOG DEBUG
      print("------------------------------------------------");
      print("REZULTAT FINAL (MEDIE): $detectedLabel (${(maxScore * 100).toStringAsFixed(1)}%)");

      // Prag de siguranță (putem fi mai permisivi, media e mai stabilă)
      if (maxScore < 0.55) {
        print("Scor sub pragul de siguranță.");
        detectedLabel = 'trash'; 
      }

      setState(() => isBusy = false);

      // Navigare către pagina de rezultat
      if (mounted) {
        Navigator.pushNamed(context, '/result', arguments: detectedLabel);
      }

    } catch (e) {
      debugPrint("Eroare la clasificare: $e");
      setState(() => isBusy = false);
    }
  }

  // --- FUNCȚIE AJUTĂTOARE (Rulează modelul o singură dată) ---
  Future<void> _runInference(img.Image imgToAnalyze, List<double> accumulator) async {
    // Resize la 150x150 (pentru modelul vechi)
    img.Image resized = img.copyResizeCropSquare(imgToAnalyze, size: inputSize);

    // Normalizare (0-255 -> 0.0-1.0)
    var input = List.generate(
      1,
      (batch) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0, 
              pixel.g / 255.0, 
              pixel.b / 255.0
            ];
          },
        ),
      ),
    );

    // Buffer pentru output
    var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);
    
    // Execuția
    interpreter!.run(input, output);
    
    // Adăugăm rezultatele acestei runde la scorul total din accumulator
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scanează Deșeul", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Container Imagine
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: imagePath == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Fără imagine", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            
            const SizedBox(height: 50),

            // Buton sau Loader
            if (isBusy)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 15),
                  Text(
                    "Analizez inteligent...", 
                    style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)
                  )
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Capturează Imagine", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}