import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  // Funcție helper pentru a obține datele (Culoare, Icon, Sfat) pe baza categoriei
  Map<String, dynamic> getWasteInfo(String category) {
    switch (category.toLowerCase()) {
      // --- PUBELA GALBENĂ (Plastic & Metal) ---
      case 'plastic':
        return {
          'color': Colors.amber[700],
          'icon': Icons.local_drink,
          'advice': 'Se aruncă în pubela GALBENĂ.\nClătește recipientul înainte și presează-l pentru a ocupa mai puțin loc.',
          'bin': 'Plastic & Metal'
        };
      case 'metal':
        return {
          'color': Colors.amber[700],
          'icon': Icons.settings_applications, // sau alt icon generic
          'advice': 'Se aruncă în pubela GALBENĂ.\nDozele de aluminiu și conservele trebuie să fie goale și curate.',
          'bin': 'Plastic & Metal'
        };

      // --- PUBELA ALBASTRĂ (Hârtie & Carton) ---
      case 'paper':
        return {
          'color': Colors.blue[700],
          'icon': Icons.newspaper,
          'advice': 'Se aruncă în pubela ALBASTRĂ.\nNu arunca hârtia dacă este pătată de ulei sau mâncare.',
          'bin': 'Hârtie & Carton'
        };
      case 'cardboard':
        return {
          'color': Colors.blue[700],
          'icon': Icons.inventory_2, // Cutie
          'advice': 'Se aruncă în pubela ALBASTRĂ.\nDesfă cutiile de carton și pliază-le pentru a economisi spațiu.',
          'bin': 'Hârtie & Carton'
        };

      // --- PUBELA VERDE (Sticlă) ---
      case 'glass':
        return {
          'color': Colors.green[700],
          'icon': Icons.wine_bar,
          'advice': 'Se aruncă în pubela VERDE (sau clopot).\nÎndepărtează capacele (ele merg la metal/plastic). Nu sparge sticla.',
          'bin': 'Sticlă'
        };

      // --- DEȘEURI PERICULOASE / ELECTRICE ---
      case 'battery':
        return {
          'color': Colors.red[700],
          'icon': Icons.battery_alert,
          'advice': 'PERICULOS! Nu arunca la gunoiul menajer.\nDu-le la punctele de colectare specială din supermarketuri.',
          'bin': 'Puncte Speciale'
        };
      case 'electronics':
        return {
          'color': Colors.red[700],
          'icon': Icons.electrical_services,
          'advice': 'Deșeu DEEE.\nNu arunca la gunoi. Predă-le la magazinele de electrocasnice sau centre de reciclare.',
          'bin': 'Centre DEEE'
        };

      // --- TEXTILE ---
      case 'clothes':
      case 'shoes':
        return {
          'color': Colors.purple[600],
          'icon': Icons.checkroom,
          'advice': 'Dacă sunt în stare bună, donează-le!\nDacă sunt uzate, du-le la containerele speciale pentru textile.',
          'bin': 'Textile / Donații'
        };

      // --- MENAJER / ALTELE ---
      case 'trash':
        return {
          'color': Colors.grey[800],
          'icon': Icons.delete_outline,
          'advice': 'Gunoi menajer (nereciclabil).\nSe aruncă în pubela NEAGRĂ sau GRI.',
          'bin': 'Menajer'
        };

      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'advice': 'Categorie necunoscută.\nVerifică regulile locale de salubritate.',
          'bin': 'Necunoscut'
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Primim argumentul, sau un string gol dacă e null
    final String category = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'Unknown';
    
    // Obținem datele
    final info = getWasteInfo(category);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Rezultat Scanare', style: TextStyle(color: Colors.white)),
        backgroundColor: info['color'], // AppBar-ul ia culoarea categoriei
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Iconița mare
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: (info['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                info['icon'],
                size: 100,
                color: info['color'],
              ),
            ),
            
            const SizedBox(height: 30),

            // 2. Numele Categoriei
            Text(
              category.toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: info['color'],
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 10),

            // 3. Tipul Pubelei (Badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: info['color'],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Recipient: ${info['bin']}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 40),

            // 4. Sfatul (Card)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 10),
                        Text("Instrucțiuni:", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      info['advice'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 5. Butonul Back
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scanează alt obiect', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}