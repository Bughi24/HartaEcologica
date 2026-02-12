import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesar pentru accesul la resurse (Assets)
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Componente TFLite pentru execuția modelului neural
  Interpreter? interpreter;
  List<String> labels = [];
  
  // Starea imaginii și a procesului de inferență
  String? imagePath;
  bool isInferencing = false; // Indicator de stare pentru procesare

  // Configurare Tensor de Intrare
  // Dimensiunea 150x150 px conform arhitecturii rețelei convoluționale antrenate
  static const int inputSize = 150; 

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  /// Inițializează asincron modelul TFLite și încarcă etichetele asociate.
  Future<void> _initModel() async {
    try {
      // Încărcarea fișierului binar al modelului optimizat (.tflite)
      interpreter = await Interpreter.fromAsset(
        'assets/model/garbage_classification_model_v2.tflite',
      );

      // Încărcarea și parsarea fișierului de etichete (clase)
      final rawLabels = await rootBundle.loadString('assets/model/labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
      
      debugPrint("Model neural inițializat. Număr clase: ${labels.length}");
    } catch (e) {
      debugPrint("Eroare critică la încărcarea modelului: $e");
    }
  }

  /// Gestionează fluxul de achiziție a imaginii prin intermediul camerei.
  Future<void> pickImage() async {
    final picker = ImagePicker();
    
    // Configurare parametri captură: rezoluție și compresie
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, 
      imageQuality: 100, 
      preferredCameraDevice: CameraDevice.rear,
    );

    if (file == null) return;

    setState(() {
      imagePath = file.path;
      isInferencing = true; // Activare indicator UI
    });

    // Latență intenționată pentru a permite randarea UI-ului înainte de blocarea thread-ului
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Declanșarea pipeline-ului de clasificare
    await classify(File(file.path));
  }

  // --- IMPLEMENTARE TEST TIME AUGMENTATION (TTA) ---
  /// Execută clasificarea imaginii folosind o strategie de tip Ensemble.
  /// Imaginea este procesată în multiple variante (original, rotit, oglindit),
  /// iar rezultatele sunt mediate pentru a crește robustețea predicției.
  Future<void> classify(File imageFile) async {
    if (interpreter == null) {
      debugPrint("Eroare: Interpretor neinițializat.");
      setState(() => isInferencing = false);
      return;
    }

    try {
      // 1. Decodare imagine în memorie
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) return;

      // Corecție orientare EXIF
      img.Image baseImage = img.bakeOrientation(originalImage);

      // Vector de acumulare pentru scorurile de probabilitate
      List<double> totalScores = List.filled(labels.length, 0.0);

      // --- PASUL 1: Inferență pe imaginea originală ---
      await _runInference(baseImage, totalScores);

      // --- PASUL 2: Augmentare Geometrică - Rotație 90° ---
      // Reduce sensibilitatea modelului la orientarea obiectului
      img.Image rotated = img.copyRotate(baseImage, angle: 90);
      await _runInference(rotated, totalScores);

      // --- PASUL 3: Augmentare Geometrică - Oglindire (Flip) ---
      // Asigură invarianța la simetrie
      img.Image flipped = img.copyFlip(baseImage, direction: img.FlipDirection.horizontal);
      await _runInference(flipped, totalScores);

      // --- AGREGARE REZULTATE (Ensemble Averaging) ---
      double maxScore = -1;
      int maxIdx = -1;

      for (int i = 0; i < totalScores.length; i++) {
        // Calculul mediei aritmetice a probabilităților
        double avgScore = totalScores[i] / 3.0;
        
        if (avgScore > maxScore) {
          maxScore = avgScore;
          maxIdx = i;
        }
      }

      String detectedLabel = labels[maxIdx];

      debugPrint("Rezultat agregat TTA: $detectedLabel (Încredere: ${(maxScore * 100).toStringAsFixed(1)}%)");

      // Aplicare prag de siguranță (Confidence Threshold)
      // Dacă modelul nu este sigur nici după TTA, clasificăm ca deșeu generic
      if (maxScore < 0.55) {
        debugPrint("Scor sub pragul minim de încredere.");
        detectedLabel = 'trash'; 
      }

      setState(() => isInferencing = false);

      // Navigare către ecranul de rezultate
      if (mounted) {
        Navigator.pushNamed(context, '/result', arguments: detectedLabel);
      }

    } catch (e) {
      debugPrint("Eroare în timpul inferenței: $e");
      setState(() => isInferencing = false);
    }
  }

  /// Execută o singură pasă de inferență pe un tensor de imagine dat.
  /// Rezultatele sunt adăugate în vectorul acumulator.
  Future<void> _runInference(img.Image imgToAnalyze, List<double> accumulator) async {
    // Preprocesare: Redimensionare la 150x150 (Center Crop)
    img.Image resized = img.copyResizeCropSquare(imgToAnalyze, size: inputSize);

    // Normalizare: Conversie RGB [0, 255] -> Float [0.0, 1.0]
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

    // Alocare tensor output [1, num_clase]
    var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);
    
    // Execuție efectivă a modelului
    interpreter!.run(input, output);
    
    // Acumulare scoruri
    var scores = output[0] as List<double>;
    for (int i = 0; i < scores.length; i++) {
      accumulator[i] += scores[i];
    }
  }

  @override
  void dispose() {
    interpreter?.close(); // Eliberare resurse native TFLite
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scanare Deșeu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Zona de Previzualizare
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                ]
              ),
              child: imagePath == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Așteptare input vizual", style: TextStyle(color: Colors.grey)),
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

            // Indicator de stare sau Buton de Acțiune
            if (isInferencing)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 15),
                  Text(
                    "Se execută inferența neurală...", 
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
                  elevation: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}