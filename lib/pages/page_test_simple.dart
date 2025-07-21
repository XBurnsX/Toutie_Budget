// 📁 Chemin : lib/pages/page_test_simple.dart
// 📋 Description : Page de test simple pour diagnostiquer le freeze

import 'package:flutter/material.dart';

class PageTestSimple extends StatelessWidget {
  const PageTestSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Simple'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '✅ Connexion PocketBase réussie !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'L\'app fonctionne sans freeze',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
