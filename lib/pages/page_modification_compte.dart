import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/compte.dart';
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';

/// Page de modification d'un compte existant
class PageModificationCompte extends StatefulWidget {
  final Compte compte;

  const PageModificationCompte({Key? key, required this.compte})
    : super(key: key);

  @override
  State<PageModificationCompte> createState() => _PageModificationCompteState();
}

class _PageModificationCompteState extends State<PageModificationCompte> {
  final _formKey = GlobalKey<FormState>();
  late String _nom;
  late String _type;
  late double _solde;
  late double _pretAPlacer;
  late Color _couleur;
  final _soldeController = TextEditingController();

  final List<String> _types = [
    'Chèque',
    'Carte de crédit',
    'Dette',
    'Investissement',
  ];

  @override
  void initState() {
    super.initState();
    _nom = widget.compte.nom;
    _type = widget.compte.type;
    _solde = widget.compte.solde;
    _pretAPlacer = widget.compte.pretAPlacer;
    _couleur = Color(widget.compte.couleur);
    _soldeController.text = _solde.toStringAsFixed(2);
  }

  void _calculerPretAPlacer() {
    // Calcul automatique : nouveau prêt à placer = ancien prêt à placer + (nouveau solde - ancien solde)
    _pretAPlacer = widget.compte.pretAPlacer + (_solde - widget.compte.solde);
  }

  void _ouvrirClavierNumerique() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericKeyboard(
        controller: _soldeController,
        onClear: () {
          setState(() {
            _soldeController.text = '';
            _solde = 0.0;
          });
        },
        onValueChanged: (value) {
          setState(() {
            _solde =
                double.tryParse(
                  value
                      .replaceAll('\$', '')
                      .replaceAll(' ', '')
                      .replaceAll(',', '.'),
                ) ??
                0.0;
          });
        },
        showDecimal: true,
      ),
    );
  }

  @override
  void dispose() {
    _soldeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le compte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Valider',
            onPressed: () async {
              if (_nom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un nom'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _calculerPretAPlacer(); // Calcul automatique avant sauvegarde
              await FirebaseService().updateCompte(widget.compte.id, {
                'nom': _nom,
                'type': _type,
                'solde': _solde,
                'pretAPlacer': _pretAPlacer,
                'couleur': _couleur.value,
              });
              Navigator.of(context).pop();
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
              const SizedBox(height: 50),
              TextFormField(
                initialValue: _nom,
                decoration: const InputDecoration(
                  labelText: 'Nom du compte',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Veuillez entrer un nom'
                    : null,
                onSaved: (value) => _nom = value ?? '',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de compte',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _type = value ?? 'Chèque';
                  });
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _ouvrirClavierNumerique(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Solde',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _soldeController.text.isEmpty
                                  ? '0.00'
                                  : _soldeController.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const Text('\$', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Section "Prêt à placer" supprimée - plus affichée dans l'interface
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Couleur du compte',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _couleur,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Choisir une couleur'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: _couleur,
                                    onColorChanged: (color) =>
                                        setState(() => _couleur = color),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Valider'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Changer'),
                        ),
                      ],
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
}
