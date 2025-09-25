import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 40),
              Text(
                'Trash Selector',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.3,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 3,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              Text(
                'Reciclează inteligent cu Trash Selector!',
                style: TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 40),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    buildOptionCard(
                      context,
                      icon: Icons.camera_alt,
                      iconColor: Colors.lightGreenAccent,
                      title: 'Scanează un deșeu',
                      route: '/scan',
                    ),
                    SizedBox(height: 30),
                    buildOptionCard(
                      context,
                      icon: Icons.map,
                      iconColor: Colors.cyanAccent,
                      title: 'Vezi harta reciclării',
                      route: '/map',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOptionCard(BuildContext context,
      {required IconData icon, required Color iconColor, required String title, required String route}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, route),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
          border: Border.all(color: Colors.white12, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical:22, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 36),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
            ],
          ),
      ),
    );
  }
}
