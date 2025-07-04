import 'package:flutter/material.dart';
import '../models/categorie.dart';
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';
import '../themes/dropdown_theme_extension.dart';

class PageSetObjectif extends StatefulWidget {
  final Enveloppe enveloppe;
  final Categorie categorie;
  const PageSetObjectif({
    super.key,
    required this.enveloppe,
    required this.categorie,
  });

  @override
  State<PageSetObjectif> createState() => _PageSetObjectifState();
}

class _PageSetObjectifState extends State<PageSetObjectif> {
  late TextEditingController _controller;
  String? _errorText;
  String _objectifType = 'mois'; // Ajout de la variable d'état
  DateTime? _selectedDate;
  int? _objectifJour;
  DateTime? _bihebdoStartDate; // Date de départ pour le cycle bi-hebdo
  // Liste fixe des jours de la semaine (1 = lundi, 7 = dimanche)
  static const List<String> _joursSemaine = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  double _currentObjectif = 0.0; // Variable pour suivre l'objectif actuel
  String? _montantOriginal;

  @override
  void initState() {
    super.initState();
    _currentObjectif =
        widget.enveloppe.objectif; // Initialiser avec l'objectif existant
    _controller = TextEditingController(
      text: _currentObjectif > 0 ? _currentObjectif.toStringAsFixed(2) : '',
    );
    _objectifJour = widget.enveloppe.objectifJour;
    _bihebdoStartDate = widget.enveloppe.dateDernierAjout;
    // Définir le type d'objectif basé sur l'enveloppe existante
    if (_currentObjectif > 0) {
      switch (widget.enveloppe.frequenceObjectif) {
        case 'mensuel':
          _objectifType = 'mois';
          break;
        case 'bihebdo':
          _objectifType = '2sem';
          _bihebdoStartDate ??= DateTime.now();
          break;
        default:
          _objectifType = 'date';
      }

      if (widget.enveloppe.objectifDate != null) {
        _selectedDate = DateTime.tryParse(widget.enveloppe.objectifDate!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openNumericKeyboard() {
    // Sauvegarder la valeur actuelle et réinitialiser le contrôleur
    setState(() {
      _montantOriginal = _controller.text;
      _controller.text = '0.00';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericKeyboard(
        controller: _controller,
        onClear: () {
          setState(() {
            _controller.text = '';
          });
        },
        onValueChanged: (value) {
          setState(() {
            // Mettre à jour l'affichage en temps réel
          });
        },
        showDecimal: true,
      ),
    ).whenComplete(() {
      // Si l'utilisateur ferme sans entrer de valeur, restaurer la valeur originale
      if (_controller.text == '0.00' || _controller.text.isEmpty) {
        setState(() {
          _controller.text = _montantOriginal ?? '';
        });
      }
    });
  }

  void _valider() async {
    // Nettoyer le montant du symbole $ et des espaces
    String montantTexte = _controller.text.trim();
    montantTexte = montantTexte.replaceAll('\$', '').replaceAll(' ', '');
    final value = double.tryParse(montantTexte.replaceAll(',', '.'));

    if (value == null || value <= 0) {
      setState(() {
        _errorText = 'Veuillez entrer un montant valide (> 0)';
      });
      return;
    }
    final updatedEnv = Enveloppe(
      id: widget.enveloppe.id,
      nom: widget.enveloppe.nom,
      solde: widget.enveloppe.solde,
      objectif: value,
      objectifDate: _objectifType == 'date' && _selectedDate != null
          ? _selectedDate!.toIso8601String()
          : null,
      depense: widget.enveloppe.depense,
      archivee: widget.enveloppe.archivee,
      provenanceCompteId: widget.enveloppe.provenanceCompteId,
      frequenceObjectif: _objectifType == 'mois'
          ? 'mensuel'
          : _objectifType == '2sem'
              ? 'bihebdo'
              : 'date',
      dateDernierAjout: _objectifType == '2sem'
          ? _bihebdoStartDate ?? widget.enveloppe.dateDernierAjout
          : widget.enveloppe.dateDernierAjout,
      objectifJour: _objectifJour,
    );
    // Mise à jour de la liste d'enveloppes dans la catégorie
    final updatedEnvs = widget.categorie.enveloppes
        .map((e) => e.id == updatedEnv.id ? updatedEnv : e)
        .toList();
    final updatedCat = Categorie(
      id: widget.categorie.id,
      nom: widget.categorie.nom,
      enveloppes: updatedEnvs,
    );
    await FirebaseService().ajouterCategorie(updatedCat);

    // Mettre à jour l'objectif local pour que l'affichage change
    setState(() {
      _currentObjectif = value;
    });

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Définir un objectif'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Objectif pour l\'enveloppe :',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              widget.enveloppe.nom,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _objectifType = 'mois';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _objectifType == 'mois'
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey[800],
                      foregroundColor:
                          _objectifType == 'mois' ? Colors.black : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                    child: const Text('Mois'),
                  ),
                ),
                // Bouton "2 semaines"
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _objectifType = '2sem';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _objectifType == '2sem'
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey[800],
                      foregroundColor:
                          _objectifType == '2sem' ? Colors.black : Colors.white,
                    ),
                    child: const Text('2 semaines'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _objectifType = 'date';
                        _selectedDate ??= DateTime.now();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _objectifType == 'date'
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey[800],
                      foregroundColor:
                          _objectifType == 'date' ? Colors.black : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    child: const Text('Date Fixe'),
                  ),
                ),
              ],
            ),
            if (_objectifType == 'date') ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(
                      const Duration(days: 365 * 10),
                    ),
                    locale: const Locale('fr', 'CA'),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                            : 'Choisir une date',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Sélecteur jour/mois pour objectif mensuel
            if (_objectifType == 'mois') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Jour du mois :',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _objectifJour,
                    dropdownColor: Theme.of(context).dropdownColor,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    hint: const Text(
                      'Jour',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: List.generate(31, (i) => i + 1)
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text(day.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _objectifJour = val;
                      });
                    },
                  ),
                ],
              ),
            ],
            // Sélecteur du jour de la semaine pour objectif bihebdo
            if (_objectifType == '2sem') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Premier jour du cycle :',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _bihebdoStartDate ?? DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('fr', 'CA'),
                      );
                      if (picked != null) {
                        setState(() {
                          _bihebdoStartDate = picked;
                        });
                      }
                    },
                    child: Text(
                      _bihebdoStartDate != null
                          ? '${_bihebdoStartDate!.day.toString().padLeft(2, '0')}/${_bihebdoStartDate!.month.toString().padLeft(2, '0')}/${_bihebdoStartDate!.year}'
                          : 'Choisir la date',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Jour de la semaine :',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _objectifJour,
                    dropdownColor: Theme.of(context).dropdownColor,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    hint: const Text(
                      'Jour',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: List.generate(7, (i) => i + 1)
                        .map(
                          (weekday) => DropdownMenuItem(
                            value: weekday,
                            child: Text(_joursSemaine[weekday - 1]),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _objectifJour = val;
                      });
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              readOnly: true,
              onTap: _openNumericKeyboard,
              decoration: InputDecoration(
                labelText: 'Montant de l\'objectif (en \$)',
                errorText: _errorText,
                border: OutlineInputBorder(),
              ),
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _valider,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  _currentObjectif > 0
                      ? 'Modifier l\'objectif'
                      : 'Enregistrer l\'objectif',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
