import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  // ---- LOGICA DE DATE (Culori, Texte, Traduceri) ----
  Map<String, dynamic> getWasteInfo(String category) {
    // 1. CURĂȚARE: Eliminăm spațiile și facem litere mici
    String clean = category.trim().toLowerCase();

    // 2. LOGICA DE DETECȚIE

    // --- BIOLOGIC / BIODEGRADABIL (NOU ADĂUGAT) ---
    // Prinde cuvinte ca: organic, food, vegetable, fruit, compost
    if (clean.contains('organic') || 
        clean.contains('food') || 
        clean.contains('vegetable') || 
        clean.contains('fruit') || 
        clean.contains('biologic') ||
        clean.contains('compost')) {
      return {
        'title': 'BIODEGRADABIL',
        'color': const Color(0xFF795548), // Maro
        'icon': Icons.compost_rounded,
        'advice': 'Resturi de fructe, legume, zaț de cafea, coji de ouă.\nNU folosi pungi de plastic, doar biodegradabile!',
        'bin': 'PUBELA MARO'
      };
    }

    // --- TEXTILE / HAINE ---
    if (clean.contains('clothes') || clean.contains('cloth') || clean.contains('textile') || clean.contains('fabric')) {
      return {
        'title': 'HAINE / TEXTILE',
        'color': Colors.purple.shade700,
        'icon': Icons.checkroom_rounded,
        'advice': 'Hainele bune se donează.\nCele rupte/uzate se duc la containerele speciale pentru textile sau la centre de colectare.',
        'bin': 'CONTAINER TEXTILE'
      };
    }

    // --- ÎNCĂLȚĂMINTE ---
    if (clean.contains('shoes') || clean.contains('shoe') || clean.contains('sneaker') || clean.contains('boot')) {
      return {
        'title': 'ÎNCĂLȚĂMINTE',
        'color': Colors.deepPurple.shade700,
        'icon': Icons.hiking_rounded,
        'advice': 'Leagă șireturile între ele ca să nu se piardă perechea.\nDacă sunt buni, donează-i!',
        'bin': 'CONTAINER TEXTILE'
      };
    }

    // --- CARTON ---
    if (clean.contains('cardboard') || clean.contains('box')) {
      return {
        'title': 'CARTON',
        'color': const Color(0xFF1565C0), // Albastru închis
        'icon': Icons.inventory_2_rounded,
        'advice': 'Pliază cutiile pentru a ocupa mai puțin spațiu.\nScoate banda adezivă de plastic.',
        'bin': 'PUBELA ALBASTRĂ'
      };
    }

    // --- HÂRTIE ---
    if (clean.contains('paper') || clean.contains('newspaper') || clean.contains('magazine')) {
      return {
        'title': 'HÂRTIE',
        'color': const Color(0xFF1976D2), // Albastru
        'icon': Icons.description_rounded,
        'advice': 'Asigură-te că hârtia este curată și uscată.\nHârtia murdară de ulei/mâncare merge la menajer.',
        'bin': 'PUBELA ALBASTRĂ'
      };
    }

    // --- PLASTIC ---
    if (clean.contains('plastic') || clean.contains('bottle')) {
      return {
        'title': 'PLASTIC',
        'color': const Color(0xFFFFCA28), // Galben
        'icon': Icons.local_drink_rounded,
        'advice': 'Clătește recipientul și presează-l (zdrobește-l).\nDopurile se reciclează tot aici.',
        'bin': 'PUBELA GALBENĂ'
      };
    }

    // --- METAL ---
    if (clean.contains('metal') || clean.contains('can') || clean.contains('tin') || clean.contains('aluminum')) {
      return {
        'title': 'METAL',
        'color': const Color(0xFFFFB300), // Galben-Portocaliu
        'icon': Icons.settings_rounded,
        'advice': 'Doze de aluminiu, conserve.\nTrebuie să fie golite de conținut și clătite.',
        'bin': 'PUBELA GALBENĂ'
      };
    }

    // --- STICLĂ ---
    if (clean.contains('glass') || clean.contains('jar')) {
      return {
        'title': 'STICLĂ',
        'color': const Color(0xFF43A047), // Verde
        'icon': Icons.wine_bar_rounded,
        'advice': 'Borcane și sticle.\nSpală-le înainte! Capacele metalice merg la galben.',
        'bin': 'PUBELA VERDE / CLOPOT'
      };
    }

    // --- BATERII / ELECTRONICE ---
    if (clean.contains('battery') || clean.contains('electronic')) {
      return {
        'title': 'DEȘEURI PERICULOASE',
        'color': Colors.redAccent.shade700,
        'icon': Icons.battery_alert_rounded,
        'advice': 'NU le arunca la gunoi! Conțin substanțe toxice.\nCaută cutiile de colectare din supermarketuri.',
        'bin': 'PUNCTE SPECIALE'
      };
    }

    // --- GUNOI MENAJER (TRASH) ---
    if (clean.contains('trash') || clean.contains('garbage') || clean.contains('waste')) {
      return {
        'title': 'MENAJER / MIXT',
        'color': const Color(0xFF424242), // Gri închis
        'icon': Icons.delete_outline_rounded,
        'advice': 'Deșeu care nu se poate recicla sau AI-ul nu l-a recunoscut clar.\nSe aruncă la gunoiul menajer.',
        'bin': 'PUBELA NEAGRĂ'
      };
    }

    // --- FALLBACK (Dacă chiar nu recunoaște nimic) ---
    return {
      'title': 'NECUNOSCUT',
      'color': Colors.blueGrey,
      'icon': Icons.help_outline_rounded,
      'advice': 'Nu am putut identifica obiectul ($clean).\nVerifică eticheta produsului.',
      'bin': 'VERIFICĂ MANUAL'
    };
  }

  @override
  Widget build(BuildContext context) {
    // 1. Preluăm argumentul trimis din ecranul anterior
    final String categoryArg = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'unknown';
    
    // 2. Obținem datele
    final info = getWasteInfo(categoryArg);
    final Color mainColor = info['color'];

    return Scaffold(
      // Fundal cu gradient subtil
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              mainColor.withOpacity(0.2), // Sus: culoare deschisă
              Colors.white,               // Jos: alb
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- APP BAR CUSTOM ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const Text(
                      "REZULTAT ANALIZĂ",
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black54,
                        letterSpacing: 1.2
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40), // Balansare spațiu
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- CONȚINUT PRINCIPAL ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      
                      // 1. Cerc Iconiță cu Efect de "Glow"
                      Container(
                        padding: const EdgeInsets.all(35),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: mainColor.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          info['icon'],
                          size: 100,
                          color: mainColor,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 2. Titlu Categorie
                      Text(
                        info['title'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32, // Ușor micșorat ca să încapă "BIODEGRADABIL"
                          fontWeight: FontWeight.w900,
                          color: mainColor,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 3. Eticheta Recipient
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: mainColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              info['bin'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 4. Cardul cu Sfaturi
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tips_and_updates, color: Colors.grey.shade700),
                                const SizedBox(width: 10),
                                Text(
                                  "CUM PROCEDĂM?",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Text(
                              info['advice'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.5,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // --- BUTONUL DE JOS ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined),
                        SizedBox(width: 10),
                        Text(
                          "SCANEAZĂ ALT OBIECT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}