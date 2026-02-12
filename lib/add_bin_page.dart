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
  // Componente TFLite
  Interpreter? interpreter;
  List<String> labels = [];
  
  // Gestionare resurse imagine
  String? imagePath;
  bool isBusy = false;

  // Variabile de stare pentru procesul de clasificare
  bool isValidBin = false;     // Flag pentru rezultatul validării AI
  bool hasAnalyzed = false;    // Indică finalizarea procesului de inferență
  String selectedType = 'plastic'; // Tipul de deșeu implicit

  // Lista categoriilor de reciclare disponibile (sincronizată cu baza de date)
  final List<String> binTypes = ['plastic', 'paper', 'glass', 'metal', 'batteries'];

  // Configurare parametri model neural
  // Dimensiunea 224x224 este standard pentru arhitecturile de tip MobileNet
  static const int inputSize = 224; 

  @override
  void initState() {
    super.initState();
    _initModel();
    // Declanșarea automată a camerei la inițializarea paginii
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pickImage();
    });
  }

  /// Inițializează interpretorul TFLite și încarcă etichetele claselor.
  Future<void> _initModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model/bin_model.tflite');
      final rawLabels = await rootBundle.loadString('assets/model/bin_labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
    } catch (e) {
      debugPrint("Eroare la inițializarea modelului: $e");
    }
  }

  /// Gestionează captura imaginii folosind camera dispozitivului.
  Future<void> pickImage() async {
    final picker = ImagePicker();
    // Limităm rezoluția pentru optimizarea performanței
    final XFile? file = await picker.pickImage(source: ImageSource.camera, maxWidth: 800);

    // Gestionare navigare înapoi în caz de anulare
    if (file == null && imagePath == null) {
      if (mounted) Navigator.pop(context);
    }

    if (file != null) {
      setState(() {
        imagePath = file.path;
        isBusy = true;
        hasAnalyzed = false;
        isValidBin = false;
      });
      
      // Mică latență pentru actualizarea UI-ului înainte de procesare intensivă
      await Future.delayed(const Duration(milliseconds: 200));
      await validateBin(File(file.path));
    }
  }

  /// Procesează imaginea și execută inferența pe modelul neural.
  Future<void> validateBin(File imageFile) async {
    if (interpreter == null) {
      debugPrint("Eroare: Interpretorul nu este inițializat.");
      return;
    }

    try {
      // 1. Preprocesare Imagine
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      // Corecție orientare EXIF și redimensionare la input-ul modelului
      img.Image image = img.bakeOrientation(originalImage);
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

      // 2. Normalizare Pixelilor
      // Conversie RGB la intervalul [0, 1] pentru tensorul de intrare
      var input = List.generate(1, (batch) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      // 3. Alocare Tensor Output
      // Modelul binar returnează o matrice [1, 1] reprezentând probabilitatea clasei pozitive
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

      // 4. Execuție Inferență
      interpreter!.run(input, output);

      // 5. Interpretare Rezultate
      // Extragem scorul de încredere (probability score)
      double score = output[0][0];
      
      debugPrint("Scor inferență: $score"); 

      // Logica de decizie bazată pe pragul de încredere (Confidence Threshold)
      // Pragul de 0.70 asigură un echilibru între precizie și recall
      bool isBin = score > 0.70; 

      setState(() {
        isBusy = false;
        hasAnalyzed = true;
        
        if (isBin) {
          isValidBin = true;
          debugPrint("Validare reușită. Clasa: Pubelă. Încredere: ${(score * 100).toStringAsFixed(1)}%");
        } else {
          isValidBin = false;
          debugPrint("Validare respinsă. Scor insuficient sau clasă negativă: ${(score * 100).toStringAsFixed(1)}%");
        }
      });

    } catch (e) {
      setState(() => isBusy = false);
      debugPrint("Eroare critică în timpul validării: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Validare Punct"), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Secțiune Previzualizare Imagine
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.black,
              child: imagePath == null
                  ? const Center(child: Icon(Icons.camera_alt, color: Colors.white))
                  : Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
            
            const SizedBox(height: 20),

            // Gestionare Stări UI (Loading / Success / Error)
            if (isBusy)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Se analizează imaginea..."),
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

 // Widget pentru formularul de colectare date (cazul valid)
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
                    "Imagine Validată.\nSistemul a identificat un punct de colectare.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          const Text("Tipul de deșeu colectat:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Selector tip deșeu
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

          // Buton Confirmare - Returnare date către harta principală
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'type': selectedType,
                  'verified': true
                });
              },
              child: const Text("SALVARE PUNCT", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pentru afișarea erorilor de validare
  Widget _buildFailureMessage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 10),
          const Text(
            "Validare Eșuată",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 10),
          const Text(
            "Algoritmul nu a detectat cu suficientă certitudine un punct de colectare valid.\nAsigurați-vă că subiectul este încadrat corect.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: pickImage, // Reinițializare proces captură
            icon: const Icon(Icons.refresh, size: 30),
            label: const Text("Reîncercare", style: TextStyle(fontSize: 18)),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          )
        ],
      ),
    );
  }

  // Metode utilitare pentru generarea elementelor grafice
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