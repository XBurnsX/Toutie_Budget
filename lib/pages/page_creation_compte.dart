import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/compte.dart';
import '../services/firebase_service.dart';

/// Page de création d'un nouveau compte bancaire, carte de crédit ou investissement
class PageCreationCompte extends StatefulWidget {
  const PageCreationCompte({Key? key}) : super(key: key);

  @override
  State<PageCreationCompte> createState() => _PageCreationCompteState();
}

class _PageCreationCompteState extends State<PageCreationCompte> {
  final _formKey = GlobalKey<FormState>();
  String _nom = '';
  String _type = 'Chèque';
  double _solde = 0.0;
  Color _couleur = Colors.green;

  final List<String> _types = [
    'Chèque',
    'Carte de crédit',
    'Dette',
    'Investissement',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Valider',
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final id = FirebaseFirestore.instance.collection('comptes').doc().id;
                final compte = Compte(
                  id: id,
                  nom: _nom,
                  type: _type,
                  solde: _solde,
                  couleur: _couleur.value,
                  pretAPlacer: _solde,
                  dateCreation: DateTime.now(),
                  estArchive: false,
                );
                await FirebaseService().ajouterCompte(compte);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: 50), // Espacement entre le titre et le premier champ
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nom du compte',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
                onSaved: (value) => _nom = value ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de compte',
                  border: OutlineInputBorder(),
                ),
                items: _types.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _type = value ?? 'Chèques';
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Solde initial',
                  border: OutlineInputBorder(),
                  suffixText: '\$',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Veuillez entrer un solde';
                  final solde = double.tryParse(value.replaceAll(',', '.'));
                  if (solde == null) return 'Veuillez entrer un nombre valide';
                  return null;
                },
                onSaved: (value) => _solde = double.tryParse(value!.replaceAll(',', '.')) ?? 0.0,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Couleur du compte :'),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () async {
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Choisir une couleur'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: _couleur,
                              onColorChanged: (color) => Navigator.of(context).pop(color),
                            ),
                          ),
                        ),
                      );
                      if (color != null) {
                        setState(() {
                          _couleur = color;
                        });
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: _couleur,
                      radius: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Générer un id unique pour le compte
                    final id = FirebaseFirestore.instance.collection('comptes').doc().id;
                    final compte = Compte(
                      id: id,
                      nom: _nom,
                      type: _type,
                      solde: _solde,
                      couleur: _couleur.value,
                      pretAPlacer: _solde, // Prêt à placer = solde initial à la création
                      dateCreation: DateTime.now(),
                      estArchive: false,
                    );
                    await FirebaseService().ajouterCompte(compte);
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Créer le compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
