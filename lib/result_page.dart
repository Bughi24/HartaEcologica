import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/badge_service.dart';
import 'models/badge_definitions.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  static const Map<String, String> _titleToFilter = {
    'plastic': 'plastic',
    'metal': 'metal',
    'hârtie': 'paper',
    'carton': 'paper',
    'sticlă': 'glass',
    'deșeuri periculoase': 'batteries',
  };

  bool canShowOnMap(String title) {
    return _titleToFilter.containsKey(title.toLowerCase());
  }

  Map<String, dynamic> getWasteInfo(String category) {
    String clean = category.trim().toLowerCase();

    if (clean.contains('organic') ||
        clean.contains('food') ||
        clean.contains('vegetable') ||
        clean.contains('fruit') ||
        clean.contains('biologic') ||
        clean.contains('compost')) {
      return {
        'title': 'BIODEGRADABIL',
        'color': const Color(0xFF795548),
        'icon': Icons.compost_rounded,
        'advice': 'Resturi de fructe, legume, zaț de cafea, coji de ouă.\nNU folosi pungi de plastic, doar biodegradabile!',
        'bin': 'PUBELA MARO'
      };
    }
    if (clean.contains('clothes') ||
        clean.contains('cloth') ||
        clean.contains('textile') ||
        clean.contains('fabric')) {
      return {
        'title': 'HAINE / TEXTILE',
        'color': Colors.purple,
        'icon': Icons.checkroom_rounded,
        'advice': 'Hainele bune se donează.\nCele rupte/uzate se duc la containerele speciale pentru textile.',
        'bin': 'CONTAINER TEXTILE'
      };
    }
    if (clean.contains('shoes') ||
        clean.contains('shoe') ||
        clean.contains('sneaker') ||
        clean.contains('boot')) {
      return {
        'title': 'ÎNCĂLȚĂMINTE',
        'color': Colors.deepPurple,
        'icon': Icons.hiking_rounded,
        'advice': 'Dacă sunt buni, donează-i! Altfel, se duc la containerele de haine.',
        'bin': 'CONTAINER TEXTILE'
      };
    }
    if (clean.contains('cardboard') || clean.contains('box')) {
      return {
        'title': 'CARTON',
        'color': const Color(0xFF1565C0),
        'icon': Icons.inventory_2_rounded,
        'advice': 'Pliază cutiile pentru a ocupa mai puțin spațiu.',
        'bin': 'PUBELA ALBASTRĂ'
      };
    }
    if (clean.contains('paper') ||
        clean.contains('newspaper') ||
        clean.contains('magazine')) {
      return {
        'title': 'HÂRTIE',
        'color': const Color(0xFF1976D2),
        'icon': Icons.description_rounded,
        'advice': 'Asigură-te că hârtia este curată și uscată.',
        'bin': 'PUBELA ALBASTRĂ'
      };
    }
    if (clean.contains('plastic') || clean.contains('bottle')) {
      return {
        'title': 'PLASTIC',
        'color': const Color(0xFFFFCA28),
        'icon': Icons.local_drink_rounded,
        'advice': 'Clătește recipientul și presează-l (zdrobește-l).',
        'bin': 'PUBELA GALBENĂ'
      };
    }
    if (clean.contains('metal') ||
        clean.contains('can') ||
        clean.contains('tin') ||
        clean.contains('aluminum')) {
      return {
        'title': 'METAL',
        'color': const Color(0xFFFFB300),
        'icon': Icons.settings_rounded,
        'advice': 'Doze de aluminiu, conserve. Trebuie să fie golite și clătite.',
        'bin': 'PUBELA GALBENĂ'
      };
    }
    if (clean.contains('glass') || clean.contains('jar')) {
      return {
        'title': 'STICLĂ',
        'color': const Color(0xFF43A047),
        'icon': Icons.wine_bar_rounded,
        'advice': 'Borcane și sticle. Spală-le înainte!',
        'bin': 'PUBELA VERDE / CLOPOT'
      };
    }
    if (clean.contains('battery') || clean.contains('electronic')) {
      return {
        'title': 'DEȘEURI PERICULOASE',
        'color': Colors.redAccent,
        'icon': Icons.battery_alert_rounded,
        'advice': 'NU le arunca la gunoi! Conțin substanțe toxice.',
        'bin': 'PUNCTE SPECIALE'
      };
    }

    return {
      'title': 'MENAJER / MIXT',
      'color': const Color(0xFF424242),
      'icon': Icons.delete_outline_rounded,
      'advice': 'Deșeu care nu se poate recicla. Se aruncă la gunoiul menajer.',
      'bin': 'PUBELA NEAGRĂ'
    };
  }

  @override
  void initState() {
    super.initState();
    // Folosim addPostFrameCallback pentru a rula după ce widget-ul e construit
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments;
      String categoryArg = 'unknown';
      String confidenceLabel = "N/A";

      if (args is String) {
        categoryArg = args;
      } else if (args is Map) {
        categoryArg = args['label']?.toString() ?? 'unknown';
        if (args['confidence'] != null) {
          confidenceLabel = "${(args['confidence'] * 100).toStringAsFixed(1)}%";
        }
      }

      final info = getWasteInfo(categoryArg);

      // Notificarea
      NotificationService.showNotification(
        "Obiect Identificat! ✅",
        "Am detectat ${info['title']} (Siguranță: $confidenceLabel)",
      );

      // Verificăm badge-uri noi
      final newBadges = await BadgeService.checkAndAwardBadges();
      if (newBadges.isNotEmpty && mounted) {
        for (final badge in newBadges) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _BadgeUnlockedDialog(badge: badge),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String categoryArg = 'unknown';
    String confidenceLabel = "N/A";

    if (args is String) {
      categoryArg = args;
    } else if (args is Map) {
      categoryArg = args['label']?.toString() ?? 'unknown';
      if (args['confidence'] != null) {
        confidenceLabel = "${(args['confidence'] * 100).toStringAsFixed(1)}%";
      }
    }

    final info = getWasteInfo(categoryArg);
    final Color mainColor = info['color'];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [mainColor.withOpacity(0.2), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Conținut scrollabil
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Icon principal
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
                        child: Icon(info['icon'], size: 100, color: mainColor),
                      ),

                      const SizedBox(height: 30),

                      // Titlu categorie
                      Text(
                        info['title'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: mainColor,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Badge pubela
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
                            ),
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

                      const SizedBox(height: 35),

                      // Buton hartă
                      if (canShowOnMap(info['title']))
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final String filterKey =
                                  _titleToFilter[info['title'].toLowerCase()] ?? '';
                              Navigator.pushNamed(context, '/map', arguments: filterKey);
                            },
                            icon: Icon(Icons.map_outlined, color: mainColor),
                            label: Text(
                              "VEZI PUBELE APROPIATE",
                              style: TextStyle(
                                color: mainColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: mainColor, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 25),

                      // Card sfaturi
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
                                const Text(
                                  "CUM PROCEDĂM?",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
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

              // Buton scanare
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
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

// ---------------------------------------------------------------------------
// Dialog afișat când se câștigă un badge nou
// ---------------------------------------------------------------------------

class _BadgeUnlockedDialog extends StatefulWidget {
  final BadgeDefinition badge;
  const _BadgeUnlockedDialog({required this.badge});

  @override
  State<_BadgeUnlockedDialog> createState() => _BadgeUnlockedDialogState();
}

class _BadgeUnlockedDialogState extends State<_BadgeUnlockedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade300, width: 3),
                  ),
                  child: Text(
                    widget.badge.emoji,
                    style: const TextStyle(fontSize: 56),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'BADGE DEBLOCAT!',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.badge.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.badge.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.badge.pointsRequired} puncte eco',
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'SUPER! 🎉',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}