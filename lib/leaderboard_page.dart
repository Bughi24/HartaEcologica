import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Top Eroi Eco", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.green.shade800,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('totalScans', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Încă nu există date în clasament."));
          }

          final topUsers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: topUsers.length,
            itemBuilder: (context, index) {
              final userData = topUsers[index].data() as Map<String, dynamic>;
              final String email = userData['email'] ?? "Anonim";
              final String displayName = email.contains('@') 
                 ? email.split('@')[0].toUpperCase() 
                 : email.toUpperCase();
              final int scans = userData['totalScans'] ?? 0;
          
              bool isTop3 = index < 3;

              return Card(
                elevation: isTop3 ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRankColor(index),
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    displayName.toUpperCase(),
                    style: TextStyle(
                      fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                      color: isTop3 ? Colors.green.shade900 : Colors.black87,
                    ),
                  ),
                  subtitle: Text("${scans * 10} puncte acumulate"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$scans",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.recycling, color: Colors.green, size: 16),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Aur
    if (index == 1) return const Color(0xFFC0C0C0); // Argint
    if (index == 2) return const Color(0xFFCD7F32); // Bronz
    return Colors.green.shade300; // Restul
  }
}