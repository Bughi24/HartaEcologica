import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AddBinPage extends StatefulWidget {
  const AddBinPage({super.key});

  @override
  State<AddBinPage> createState() => _AddBinPageState();
}

class _AddBinPageState extends State<AddBinPage> {
  Interpreter? interpreter;
  List<String> labels = [];
  String? imagePath;
  bool isBusy = false;

  // Starea Validării
  bool isValidBin = false;     // A trecut testul AI?
  bool hasAnalyzed = false;    // S-a terminat analiza?
  String selectedType = 'plastic'; // Tipul selectat de utilizator (default)

  // Lista de tipuri pentru Dropdown (trebuie să coincidă cu ce ai în MapPage)
  final List<String> binTypes = ['plastic', 'paper', 'glass', 'metal', 'batteries'];

  // Configurare Model
  static const int inputSize = 224; // Teachable Machine standard

  @override
  void initState() {
    super.initState();
    _initModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pickImage();
    });
  }

  Future<void> _initModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model/bin_model.tflite');
      final rawLabels = await rootBundle.loadString('assets/model/bin_labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
    } catch (e) {
      debugPrint("Eroare model: $e");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.camera, maxWidth: 800);

    if (file == null && imagePath == null) {
      if (mounted) Navigator.pop(context);
    }

    if (file != null) {
      setState(() {
        imagePath = file.path;
        isBusy = true;
        hasAnalyzed = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));
      await validateBin(File(file.path));
    }
  }

  Future<void> validateBin(File imageFile) async {
    if (interpreter == null) return;

    try {
      
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return;

      image = img.bakeOrientation(image);
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

      // Normalizare (0.0 - 1.0)
      var input = List.generate(1, (batch) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      var output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

      
      interpreter!.run(input, output);

      final scores = output[0] as List<double>;
      double maxScore = -1;
      int maxIdx = -1;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      String detectedLabel = labels[maxIdx]; 
      
      print("AI Rezultat: $detectedLabel ($maxScore)");

      setState(() {
        isBusy = false;
        hasAnalyzed = true;

      
        if (detectedLabel == "pubela" && maxScore > 0.70) {
          isValidBin = true;
        } else {
          isValidBin = false;
        }
      });

    } catch (e) {
      setState(() => isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Validare Punct"), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Zona Imagine
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.black,
              child: imagePath == null
                  ? const Center(child: Icon(Icons.camera_alt, color: Colors.white))
                  : Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
            
            const SizedBox(height: 20),

            if (isBusy)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("AI-ul analizează imaginea..."),
                ],
              )
            
            else if (hasAnalyzed && isValidBin)
              _buildSuccessForm()

            else if (hasAnalyzed && !isValidBin)
              _buildFailureMessage()
          ],
        ),
      ),
    );
  }

 // Formularul de succes când e pubelă
  Widget _buildSuccessForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 40),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "Poză Validată!\nAI-ul confirmă că este un punct de reciclare.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          const Text("Ce tip de deșeu se colectează?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Dropdown pentru selecție tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 30),
                items: binTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getIconForType(type), color: _getColorForType(type)),
                        const SizedBox(width: 15),
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedType = newValue!;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Buton Confirmare Finală
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                // Trimitem datele înapoi la MapPage
                Navigator.pop(context, {
                  'type': selectedType, // Tipul ales de user
                  'verified': true      // Validarea AI
                });
              },
              child: const Text("ADAUGĂ PE HARTĂ", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // Mesajul de eroare dacă nu e pubelă
  Widget _buildFailureMessage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 10),
          const Text(
            "Nu putem valida această poză.",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 10),
          const Text(
            "AI-ul nu a detectat o pubelă de reciclare clară.\nTe rugăm să te asiguri că fotografiezi containerul, nu peisajul.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: pickImage, // Redeschide camera
            icon: const Icon(Icons.refresh, size: 30),
            label: const Text("Încearcă din nou", style: TextStyle(fontSize: 18)),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          )
        ],
      ),
    );
  }

  // Helper Vizual
  IconData _getIconForType(String type) {
    switch (type) {
      case 'plastic': return Icons.local_drink;
      case 'paper': return Icons.newspaper;
      case 'glass': return Icons.wine_bar;
      case 'metal': return Icons.settings_applications;
      case 'batteries': return Icons.battery_charging_full;
      default: return Icons.delete;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'plastic': return Colors.amber;
      case 'paper': return Colors.blue;
      case 'glass': return Colors.green;
      case 'metal': return Colors.grey;
      case 'batteries': return Colors.red;
      default: return Colors.black;
    }
  }
}