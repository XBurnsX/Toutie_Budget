import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/compte.dart';
import '../widgets/numeric_keyboard.dart';
import '../themes/dropdown_theme_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/firebase_service.dart';

/// Page de modification d'un compte existant
class PageModificationCompte extends StatefulWidget {
  final Compte compte;

  const PageModificationCompte({super.key, required this.compte});

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
  final _pretAPlacerController = TextEditingController();

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
    _pretAPlacerController.text = _pretAPlacer.toStringAsFixed(2);
  }

  void _calculerPretAPlacer() {
    // Le calcul automatique est maintenant désactivé.
    // _pretAPlacer = widget.compte.pretAPlacer + (_solde - widget.compte.solde);
  }

  void _ouvrirClavierNumerique({required bool pourPretAPlacer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericKeyboard(
        controller: pourPretAPlacer ? _pretAPlacerController : _soldeController,
        onClear: () {
          setState(() {
            if (pourPretAPlacer) {
              _pretAPlacerController.text = '';
              _pretAPlacer = 0.0;
            } else {
              _soldeController.text = '';
              _solde = 0.0;
            }
          });
        },
        onValueChanged: (value) {
          setState(() {
            final double parsedValue = double.tryParse(
                  value
                      .replaceAll('\$', '')
                      .replaceAll(' ', '')
                      .replaceAll(',', '.'),
                ) ??
                0.0;
            if (pourPretAPlacer) {
              _pretAPlacer = parsedValue;
            } else {
              _solde = parsedValue;
            }
          });
        },
        showDecimal: true,
      ),
    );
  }

  @override
  void dispose() {
    _soldeController.dispose();
    _pretAPlacerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifier le compte'),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildModificationCompteContent(context),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le compte'),
        elevation: 0,
      ),
      body: _buildModificationCompteContent(context),
    );
  }

  Widget _buildModificationCompteContent(BuildContext context) {
    return Padding(
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
              onChanged: (value) => setState(() => _nom = value),
            ),
            const SizedBox(height: 16),
            if (_type != 'Investissement')
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: Theme.of(context).dropdownColor,
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
            if (_type != 'Investissement') const SizedBox(height: 16),
            if (_type != 'Investissement')
              GestureDetector(
                onTap: () => _ouvrirClavierNumerique(pourPretAPlacer: false),
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
            if (_type == 'Investissement')
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 16),
                child: Text(
                  'Le solde global d\'un compte investissement est calculé automatiquement (actions + cash disponible). Seul le cash disponible est modifiable ici.',
                  style: TextStyle(color: Colors.orange[700], fontSize: 13),
                ),
              ),
            GestureDetector(
              onTap: () => _ouvrirClavierNumerique(pourPretAPlacer: true),
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
                          Text(
                            _type == 'Investissement'
                                ? 'Cash disponible'
                                : 'Prêt à placer',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pretAPlacerController.text.isEmpty
                                ? '0.00'
                                : _pretAPlacerController.text,
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  if (_type == 'Investissement') {
                    FocusScope.of(context).unfocus();
                    print(
                        'Valeur brute du champ pretAPlacer : \'${_pretAPlacerController.text}\'');
                    final pretAPlacerValue = double.tryParse(
                            _pretAPlacerController.text
                                .replaceAll(RegExp(r'[^0-9.,-]'), '')
                                .replaceAll(',', '.')) ??
                        0.0;
                    print('Mise à jour pretAPlacer : $pretAPlacerValue');
                    await FirebaseService()
                        .firestore
                        .collection('comptes')
                        .doc(widget.compte.id)
                        .update({
                      'pretAPlacer': pretAPlacerValue,
                      'nom': _nom,
                      'couleur': _couleur.value,
                    });
                  } else {
                    await FirebaseService()
                        .firestore
                        .collection('comptes')
                        .doc(widget.compte.id)
                        .update({
                      'solde': double.tryParse(
                              _soldeController.text.replaceAll(',', '.')) ??
                          0.0,
                      'pretAPlacer': double.tryParse(_pretAPlacerController.text
                              .replaceAll(',', '.')) ??
                          0.0,
                      'nom': _nom,
                      'type': _type,
                      'couleur': _couleur.value,
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}
