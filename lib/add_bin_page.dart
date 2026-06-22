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
  Set<String> selectedTypes = {'plastic'}; // Tipul de deșeu implicit

  // Lista categoriilor de reciclare disponibile (sincronizată cu baza de date)
  final List<String> binTypes = ['plastic', 'hârtie', 'sticlă', 'metal', 'baterii'];

  // Configurare parametri model neural
  // Dimensiunea 224x224 este standard pentru arhitecturile de tip MobileNet
  static const int inputSize = 224; 

  @override
  void initState() {
    super.initState();
    _initModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pickImage();
    });
  }

  // Inițializează interpretorul TFLite și încarcă etichetele claselor.
  Future<void> _initModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model/bin_model.tflite');
      final rawLabels = await rootBundle.loadString('assets/model/bin_labels.txt');
      labels = rawLabels.split('\n').where((e) => e.trim().isNotEmpty).toList();
    } catch (e) {
      debugPrint("Eroare la inițializarea modelului: $e");
    }
  }

  // Gestionează captura imaginii folosind camera dispozitivului.
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

  Future<void> validateBin(File imageFile) async {
    if (interpreter == null) {
      debugPrint("Eroare: Interpretorul nu este inițializat.");
      return;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      img.Image image = img.bakeOrientation(originalImage);
      
      int cropSize = image.width > image.height ? image.height : image.width;
      img.Image cropped = img.copyCrop(
        image, 
        x: (image.width - cropSize) ~/ 2, 
        y: (image.height - cropSize) ~/ 2, 
        width: cropSize, 
        height: cropSize
      );

      // Redimensionăm la 224 doar bucata centrală
      img.Image resized = img.copyResize(cropped, width: inputSize, height: inputSize);

      var input = List.generate(1, (batch) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

      interpreter!.run(input, output);
      double score = output[0][0];
      
      debugPrint("Scor inferență: $score"); 

      bool isBin = score > 0.90; 

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
            // UI MODERN: Previzualizarea imaginii (Rounded Corners + Shadow)
            Container(
              margin: const EdgeInsets.all(20),
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  )
                ],
                // Imaginea se mulează pe marginile rotunjite ale containerului
                image: imagePath != null
                    ? DecorationImage(
                        image: FileImage(File(imagePath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.white.withOpacity(0.5), size: 60),
                        const SizedBox(height: 10),
                        Text("Așteptare cameră...", style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      ],
                    )
                  : null,
            ),
            
            // UI MODERN: Starea de încărcare a Inteligenței Artificiale
            if (isBusy)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50,
                      width: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Rețeaua Neurală procesează...",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Se aplică filtrele de convoluție și se caută tiparele de clasificare pentru deșeuri.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              )
            
            // Formularul de succes sau eroare 
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
          const Text(
            "Ce tipuri de deșeuri se pot colecta aici?", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 5),
          const Text(
            "(Puteți selecta mai multe opțiuni)", 
            style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic)
          ),
          const SizedBox(height: 15),
          
          // Interfață cu selecție multiplă (Filter Chips)
          Wrap(
            spacing: 10.0, 
            runSpacing: 10.0, 
            children: binTypes.map((String type) {
              bool isSelected = selectedTypes.contains(type);
              
              return FilterChip(
                selected: isSelected,
                showCheckmark: false, 
                selectedColor: _getColorForType(type).withOpacity(0.8),
                backgroundColor: Colors.grey.shade200,
                elevation: isSelected ? 4 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForType(type), 
                      color: isSelected ? Colors.white : _getColorForType(type),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      selectedTypes.add(type);
                    } else {
                      selectedTypes.remove(type);
                    }
                  });
                },
              );
            }).toList(),
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
                // Dezactivăm butonul dacă nu e nimic selectat
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              
              onPressed: selectedTypes.isEmpty ? null : () {
                Navigator.pop(context, {
                  'types': selectedTypes.toList(),
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