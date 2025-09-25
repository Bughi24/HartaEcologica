import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    // De exemplu, afișăm plastic ca rezultat simulat
    String category = 'Plastic';
    String advice = 'Aruncă în pubela galbenă!';

    return Scaffold(
      appBar: AppBar(title: Text('Rezultat')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Categorie: $category',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              advice,
              style: TextStyle(fontSize: 18, color: Colors.green[700]),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Înapoi la acasă'),
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
            ),
          ],
        ),
      ),
    );
  }
}
