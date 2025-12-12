import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final labelData = await rootBundle.loadString('assets/model/labels.txt');
      labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      // Gestionare silențioasă a erorilor sau afișare Snackbar dacă e critic
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800, // Rezoluție decentă pentru crop
    );

    if (file == null) return;

    setState(() {
      imagePath = file.path;
      isBusy = true;
    });

    // Mică pauză pentru ca UI-ul să afișeze loader-ul
    await Future.delayed(const Duration(milliseconds: 100));
    await classify(File(file.path));
  }

  Future<void> classify(File imageFile) async {
    if (interpreter == null) {
      setState(() => isBusy = false);
      return;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        setState(() => isBusy = false);
        return;
      }

      // --- PREPROCESARE CRITICĂ ---
      // 1. Corectăm rotația imaginii (EXIF data)
      originalImage = img.bakeOrientation(originalImage);

      // 2. Crop Pătrat din centru (pentru a nu deforma obiectele)
      // 3. Resize la 150x150
      img.Image resized = img.copyResizeCropSquare(originalImage, size: 150);

      // --- CONVERSIE MATRICEALA ---
      // Normalizare 0.0 - 1.0 (conform antrenamentului tău Python: rescale=1./255)
      var input = List.generate(
        1,
        (batch) => List.generate(
          150,
          (y) => List.generate(
            150,
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

      // Buffer Output
      var output = List.filled(1 * labels.length, 0.0).reshape([1, labels.length]);

      // --- INFERENȚĂ ---
      interpreter!.run(input, output);

      // --- REZULTAT ---
      final scores = output[0] as List<double>;
      
      double maxScore = -1;
      int maxIdx = -1;

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      if (mounted) {
        setState(() => isBusy = false);
        // Navigare cu rezultatul
        if (maxIdx != -1 && maxIdx < labels.length) {
          Navigator.pushNamed(context, '/result', arguments: labels[maxIdx]);
        }
      }

    } catch (e) {
      // În caz de eroare oprim loader-ul
      if (mounted) setState(() => isBusy = false);
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
        title: const Text("Scanează un deșeu", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Zona de afișare imagine
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: imagePath == null
                  ? const Icon(Icons.image, size: 100, color: Colors.grey)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),

            const SizedBox(height: 40),

            // Buton sau Loader
            if (isBusy)
              const CircularProgressIndicator(color: Colors.white)
            else
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Capturează", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}