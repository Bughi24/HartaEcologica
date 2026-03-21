import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FUNDAL MODERN (Natură / Prospețime)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7), Color(0xFF4CAF50)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // 2. ELEMENTE DE DESIGN (Cercuri decorative)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),

          // 3. CONȚINUTUL PRINCIPAL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  
                  // Salut și Titlu
                  const Text(
                    'Salutare! 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Harta Ecologică',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20), // Verde închis
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Află cum și unde să reciclezi folosind\nInteligența Artificială.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green.shade900.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 50),

                  // CARDS (Butoanele de navigare)
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildGlassCard(
                          context: context,
                          title: 'Scanează Deșeu',
                          subtitle: 'AI-ul îți spune cum să-l reciclezi',
                          icon: Icons.document_scanner_rounded,
                          color: const Color(0xFF2E7D32),
                          route: '/scan',
                        ),
                        const SizedBox(height: 20),
                        _buildGlassCard(
                          context: context,
                          title: 'Harta Reciclării',
                          subtitle: 'Găsește pubele în apropierea ta',
                          icon: Icons.map_rounded,
                          color: const Color(0xFF1565C0), // Albastru
                          route: '/map',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET PERSONALIZAT: Card modern stil "Glassmorphism"
  Widget _buildGlassCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85), // Efect translucid
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Iconița cu fundal colorat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            
            // Textul cardului
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Săgeata
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}