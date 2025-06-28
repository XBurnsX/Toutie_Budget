import 'package:flutter/material.dart';

/// Page d'affichage des statistiques financières
class PageStatistiques extends StatelessWidget {
  const PageStatistiques({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Statistiques',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

