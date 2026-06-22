import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/badge_definitions.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profil & Statistici",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final List<String> badgeIds =
              List<String>.from(userData?['badgeIds'] ?? []);
          final int totalScans = userData?['totalScans'] ?? 0;
          final int totalPoints = totalScans * 10;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('scans')
                .snapshots(),
            builder: (context, scanSnapshot) {
              final scanDocs = scanSnapshot.data?.docs ?? [];

              Map<String, int> categories = {};
              for (var doc in scanDocs) {
                String label =
                    ((doc.data() as Map<String, dynamic>)['category'] ?? (doc.data() as Map<String, dynamic>)['label'] ?? 'Altele').toString();
                categories[label] = (categories[label] ?? 0) + 1;
              }

              final impact = _calculateEcoImpact(categories);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // 1. BADGE-URI
                    _buildBadgeSection(context, badgeIds, totalPoints),

                    const SizedBox(height: 10),

                    // 2. GRAFIC
                    if (scanDocs.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 25),
                        child: Text(
                          "Analiza Reciclării",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPieChart(categories),
                      const SizedBox(height: 15),
                      _buildLegend(categories),
                      const SizedBox(height: 30),

                      // 3. IMPACT ECO
                      _buildImpactSection(impact),
                    ],

                    const SizedBox(height: 30),

                    _buildActivityChart(scanDocs),

                     const SizedBox(height: 30),

                    // 4. STATISTICI
                    _buildStatSection(totalScans, totalPoints),

                    const SizedBox(height: 20),

                    // 5. MENIU
                    _buildMenuSection(context),

                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // IMPACT ECO
  // ---------------------------------------------------------------------------

  // Mapare label brut AI → categorie
  String _normalizeLabel(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.contains('plastic') || r.contains('bottle')) return 'plastic';
    if (r.contains('metal') || r.contains('can') || r.contains('tin') || r.contains('aluminum')) return 'metal';
    if (r.contains('glass') || r.contains('jar')) return 'sticla';
    if (r.contains('cardboard') || r.contains('box')) return 'carton';
    if (r.contains('paper') || r.contains('newspaper') || r.contains('magazine')) return 'hartie';
    if (r.contains('organic') || r.contains('food') || r.contains('compost')) return 'organic';
    return 'altele';
  }

  Map<String, double> _calculateEcoImpact(Map<String, int> categories) {
    // Normalizăm fiecare cheie prin mapare label brut → categorie
    final Map<String, int> c = {};
    categories.forEach((key, value) {
      final normalized = _normalizeLabel(key);
      c[normalized] = (c[normalized] ?? 0) + value;
    });

    double co2 = ((c['plastic'] ?? 0) * 0.1) +
        ((c['metal'] ?? 0) * 0.2) +
        ((c['sticla'] ?? 0) * 0.15) +
        ((c['carton'] ?? 0) * 0.05) +
        ((c['hartie'] ?? 0) * 0.05);

    double water = ((c['hartie'] ?? 0) + (c['carton'] ?? 0)) * 0.5;

    double trees = ((c['hartie'] ?? 0) + (c['carton'] ?? 0)) * 0.005;

    return {'co2': co2, 'water': water, 'trees': trees};
  }

  Widget _buildImpactSection(Map<String, double> impact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 5, bottom: 15),
            child: Text(
              "Impactul Tău Asupra Mediului",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImpactItem(Icons.cloud_queue,
                    "${impact['co2']!.toStringAsFixed(1)} kg", "CO2 Salvat", Colors.lightBlue),
                _buildImpactItem(Icons.water_drop,
                    "${impact['water']!.toStringAsFixed(1)} L", "Apă Salvată", Colors.blue),
                _buildImpactItem(Icons.park,
                    "${impact['trees']!.toStringAsFixed(2)}", "Copaci Salvați", Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE-URI
  // ---------------------------------------------------------------------------

  Widget _buildBadgeSection(
    BuildContext context,
    List<String> badgeIds,
    int totalPoints,
  ) {
    final nextBadge = BadgeDefinitions.nextBadgeFor(totalPoints);
    final allBadges = BadgeDefinitions.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextBadge != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nextBadge.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Următor: ${nextBadge.title}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              nextBadge.description,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$totalPoints / ${nextBadge.pointsRequired}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: totalPoints / nextBadge.pointsRequired,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            "Realizări",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemCount: allBadges.length,
          itemBuilder: (context, index) {
            final badge = allBadges[index];
            final isEarned = totalPoints >= badge.pointsRequired;

            return GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) =>
                    _BadgeDetailDialog(badge: badge, isEarned: isEarned),
              ),
              child: Opacity(
                opacity: isEarned ? 1.0 : 0.3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isEarned
                            ? Colors.amber.shade50
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: isEarned
                            ? Border.all(color: Colors.amber.shade400, width: 2)
                            : null,
                        boxShadow: isEarned
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(badge.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isEarned ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const Divider(indent: 25, endIndent: 25, height: 30),
      ],
    );
  }

  Widget _buildPieChart(Map<String, int> categories) {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: _buildChartSections(categories),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(Map<String, int> categories) {
    final List<Color> colors = [
      Colors.yellow.shade600,
      Colors.blue.shade400,
      Colors.green.shade500,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    int index = 0;
    return categories.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 45,
        titleStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> categories) {
    final List<Color> colors = [
      Colors.yellow.shade600,
      Colors.blue.shade400,
      Colors.green.shade500,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    int index = 0;
    return Wrap(
      spacing: 15,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categories.keys.map((key) {
        final color = colors[index % colors.length];
        index++;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(key, style: const TextStyle(fontSize: 11)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatSection(int totalScans, int totalPoints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard("Total Scanări", totalScans.toString(), Colors.blue),
          const SizedBox(width: 15),
          _buildStatCard("Puncte Eco", totalPoints.toString(), Colors.orange),
        ],
      ),
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
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  List<BarChartGroupData> _getWeeklyBarGroups(List<QueryDocumentSnapshot> docs) {
  Map<int, int> dayCounts = {};
  DateTime now = DateTime.now();

  for (var doc in docs) {
    var data = doc.data() as Map<String, dynamic>;
    if (data['timestamp'] == null) continue;
    
    DateTime date = (data['timestamp'] as Timestamp).toDate();
    int dayDifference = now.difference(date).inDays;
    
    // Luăm doar scanările din ultimele 7 zile
    if (dayDifference < 7) {
      int weekDay = date.weekday; 
      dayCounts[weekDay] = (dayCounts[weekDay] ?? 0) + 1;
    }
  }

  return List.generate(7, (index) {
    // index 0..6 corespunde zilelor L..D 
    int day = index + 1; 
    return BarChartGroupData(
      x: day,
      barRods: [
        BarChartRodData(
          toY: (dayCounts[day] ?? 0).toDouble(),
          color: Colors.green.shade400,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )
      ],
    );
  });
}
Widget _buildActivityChart(List<QueryDocumentSnapshot> docs) {
  return Container(
    height: 180,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(horizontal: 25),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10)],
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Activitate Săptămânală", 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 15),
        Expanded(
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[value.toInt() - 1], 
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: _getWeeklyBarGroups(docs),
            ),
          ),
        ),
      ],
    ),
  );
}
 

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _buildProfileOption(Icons.history, "Istoric Complet",
            () => Navigator.pushNamed(context, '/history')),
        _buildProfileOption(Icons.leaderboard_rounded, "Vezi Clasament",
            () => Navigator.pushNamed(context, '/leaderboard')),
        _buildProfileOption(
          Icons.logout,
          "Deconectare",
          () => FirebaseAuth.instance.signOut(),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: isDestructive ? Colors.red : Colors.green.shade800),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
    );
  }
}



class _BadgeDetailDialog extends StatelessWidget {
  final BadgeDefinition badge;
  final bool isEarned;

  const _BadgeDetailDialog({required this.badge, required this.isEarned});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEarned ? Colors.amber.shade50 : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: isEarned
                    ? Border.all(color: Colors.amber.shade400, width: 2)
                    : null,
              ),
              child: Text(badge.emoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isEarned ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEarned
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                isEarned
                    ? '✅ Câștigat!'
                    : '🔒 Necesită ${badge.pointsRequired} puncte eco',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color:
                      isEarned ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ÎNCHIDE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}