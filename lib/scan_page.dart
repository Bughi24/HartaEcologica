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

  // --- CONFIGURARE CRITICĂ ---
  // Trebuie să fie identic cu 'img_size' din Python
  static const int inputSize = 150; 

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      // 1. Încărcare Model
      interpreter = await Interpreter.fromAsset(
        'assets/model/garbage_classification_model_v2.tflite',
      );

      // 2. Încărcare Labels
      // Asigură-te că fișierul labels.txt este ordonat ALFABETIC!
      final rawLabels = await rootBundle.loadString('assets/model/labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
      
      print("Model încărcat. Labels: ${labels.length}");
    } catch (e) {
      debugPrint("EROARE ÎNCĂRCARE MODEL: $e");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    // Luăm imaginea la o calitate bună, dar nu exagerată
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, 
    );

    if (file == null) return;

    setState(() {
      imagePath = file.path;
      isBusy = true; // Pornim loader-ul
    });

    // Mică pauză pentru ca UI-ul să se randeze
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Pornim clasificarea
    await classify(File(file.path));
  }

  Future<void> classify(File imageFile) async {
    if (interpreter == null) {
      print("Interpreter este null!");
      setState(() => isBusy = false);
      return;
    }

    try {
      // --- PASUL 1: Citire și Decodare ---
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) return;

      // --- PASUL 2: Preprocesare Geometrică ---
      // a) Corectăm rotația (pentru poze portrait)
      img.Image orientedImage = img.bakeOrientation(originalImage);

      // b) Tăiem un pătrat din centru și redimensionăm la 150x150
      // Aceasta previne deformarea/turtirea obiectelor
      img.Image resized = img.copyResizeCropSquare(orientedImage, size: inputSize);

      // --- PASUL 3: Conversie și Normalizare ---
      // Python: rescale=1./255  => Valori 0.0 ... 1.0
      var input = List.generate(
        1,
        (batch) => List.generate(
          inputSize,
          (y) => List.generate(
            inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              // Extragem canalele RGB și le împărțim la 255.0
              return [
                pixel.r / 255.0, 
                pixel.g / 255.0, 
                pixel.b / 255.0
              ];
            },
          ),
        ),
      );

      // Buffer pentru rezultat [1, 10]
      var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);

      // --- PASUL 4: Inferență (Rulează modelul) ---
      interpreter!.run(input, output);

      // --- PASUL 5: Interpretare Rezultate ---
      final scores = output[0] as List<double>;
      
      double maxScore = -1;
      int maxIdx = -1;

      // Găsim cel mai mare scor
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      String detectedLabel = labels[maxIdx];
      
      // LOG DE DEBUG (Să vezi în consolă ce se întâmplă)
      print("------------------------------------------------");
      print("Detectat: $detectedLabel cu încredere: ${(maxScore * 100).toStringAsFixed(1)}%");
      
      // --- PASUL 6: Filtru de Siguranță ---
      // Dacă modelul e mai puțin de 60% sigur, probabil greșește (ex: șervețel văzut ca telefon)
      if (maxScore < 0.60) {
        print("Scor sub pragul de siguranță. Redirecționare către Trash/Unknown.");
        detectedLabel = 'trash'; // Sau o categorie 'unknown' dacă ai logică pt ea
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
                  Text("Analizez imaginea...", style: TextStyle(color: Colors.white70))
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