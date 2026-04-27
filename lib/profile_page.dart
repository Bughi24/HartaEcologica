import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil & Statistici", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('scans')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          int totalScans = docs.length;

          // Calculăm datele pentru Grafic
          Map<String, int> categories = {};
          for (var doc in docs) {
            String label = (doc.data() as Map<String, dynamic>)['label'] ?? 'Altele';
            categories[label] = (categories[label] ?? 0) + 1;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // 1. SECȚIUNEA GRAFIC (Dacă există date)
                if (totalScans > 0) ...[
                  const Text("Analiza Reciclării", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildChartSections(categories),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildLegend(categories),
                ],

                const SizedBox(height: 40),

                // 2. CARDURILE DE STATISTICI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildStatCard("Total Scanări", totalScans.toString(), Colors.blue),
                      const SizedBox(width: 15),
                      _buildStatCard("Puncte Eco", (totalScans * 10).toString(), Colors.orange),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 3. MENIU OPȚIUNI (Aici legăm pagina de History)
                _buildProfileOption(Icons.history, "Istoric Complet", () {
                  Navigator.pushNamed(context, '/history'); // Te trimite la pagina ta de istoric
                }),
                _buildProfileOption(Icons.leaderboard_rounded, "Vezi Clasament", () {
                  Navigator.pushNamed(context, '/leaderboard');
                }),
                _buildProfileOption(Icons.info_outline, "Despre Aplicație", () {
                   _showAboutDialog(context);
                }),
                
                const Divider(height: 50, indent: 25, endIndent: 25),

                // BUTON LOGOUT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Deconectare", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- METODE AJUTĂTOARE ---

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("TrashSelector AI"),
        content: const Text("Creat pentru gestionarea inteligentă a deșeurilor folosind AI.\n\nProiect Licență 2026"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(Map<String, int> categories) {
    final List<Color> colors = [Colors.yellow, Colors.blue, Colors.green, Colors.orange, Colors.purple];
    int index = 0;
    return categories.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 50,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> categories) {
    final List<Color> colors = [Colors.yellow, Colors.blue, Colors.green, Colors.orange, Colors.purple];
    int index = 0;
    return Wrap(
      spacing: 15,
      children: categories.keys.map((key) {
        final color = colors[index % colors.length];
        index++;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 5),
            Text(key, style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade800),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
    );
  }
}