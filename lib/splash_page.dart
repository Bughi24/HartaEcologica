import 'package:flutter/material.dart';
import 'dart:async';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  // Controller pentru gestionarea ciclului de viață al animației
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // Configurarea animației de intrare (Fade-In)
    // Durata de 2 secunde oferă o tranziție lină pentru elementele grafice
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Curba de accelerație naturală
    );

    // Simularea procesului de inițializare (ex: Handshake cu serverul Firebase)
    Timer(const Duration(seconds: 3), () {
      // Verificare critică: Ne asigurăm că widget-ul este încă montat în arborele de randare
      // pentru a preveni erori de tip "Memory Leak" sau apeluri pe componente distruse.
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/'); // Tranziție către modulul principal
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Eliberarea resurselor grafice alocate
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Element de Identitate Vizuală (Logo Vectorial)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade50, // Fundal subtil
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
                child: Icon(Icons.recycling, size: 100, color: Colors.green.shade800),
              ),
              
              const SizedBox(height: 30),

              // Titlul Aplicației
              const Text(
                "Harta Ecologică",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 1.2
                ),
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                "Sistem Inteligent de Monitorizare",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic
                ),
              ),

              const SizedBox(height: 60),

              // Indicator de Activitate (Feedback Vizual pentru utilizator)
              // Sugerează că aplicația încarcă resurse (AI, Hărți)
              const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}