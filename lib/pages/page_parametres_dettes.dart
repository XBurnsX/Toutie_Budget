import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:toutie_budget/models/dette.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';
import 'package:toutie_budget/widgets/month_picker.dart';
import 'package:toutie_budget/services/calcul_pret_service.dart';

class PageParametresDettes extends StatefulWidget {
  final Dette dette;

  const PageParametresDettes({super.key, required this.dette});

  @override
  State<PageParametresDettes> createState() => _PageParametresDettesState();
}

class _PageParametresDettesState extends State<PageParametresDettes> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs principaux
  final _tauxController = TextEditingController();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  final _montantMensuelController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _nombrePaiementsController = TextEditingController();
  final _paiementsEffectuesController = TextEditingController();

  // Simulateur
  final _simulateurTauxController = TextEditingController();
  final _simulateurPaiementController = TextEditingController();
  final _simulateurPrincipalController = TextEditingController();
  final _simulateurDureeController = TextEditingController();

  bool _montreSimulateur = false;
  double? _tauxCalcule;
  double? _paiementCalcule;
  double? _soldeRestantCalcule;
  double? _coutTotalCalcule;
  String? _erreurSimulateur;
  bool _afficherResultatsCalcul = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  void _chargerDonnees() {
    if (widget.dette.tauxInteret != null) {
      _tauxController.text = widget.dette.tauxInteret!.toStringAsFixed(2);
    }

    // Date de début (par défaut aujourd'hui)
    final dateDebut = widget.dette.dateDebut ?? DateTime.now();
    _dateDebutController.text = _formaterDate(dateDebut);

    if (widget.dette.dateFin != null) {
      _dateFinController.text = _formaterDate(widget.dette.dateFin!);
    }

    if (widget.dette.montantMensuel != null) {
      _montantMensuelController.text = widget.dette.montantMensuel!
          .toStringAsFixed(2);
    }

    if (widget.dette.prixAchat != null) {
      _prixAchatController.text = widget.dette.prixAchat!.toStringAsFixed(2);
    }

    if (widget.dette.nombrePaiements != null) {
      _nombrePaiementsController.text = widget.dette.nombrePaiements!
          .toString();
    }

    if (widget.dette.paiementsEffectues != null) {
      _paiementsEffectuesController.text = widget.dette.paiementsEffectues!
          .toString();
    } else {
      // Calculer automatiquement les paiements effectués
      _calculerPaiementsEffectues();
    }
  }

  void _calculerPaiementsEffectues() {
    final dateDebut = _parseDate(_dateDebutController.text);
    if (dateDebut != null) {
      final maintenant = DateTime.now();
      final mois =
          (maintenant.year - dateDebut.year) * 12 +
          (maintenant.month - dateDebut.month);
      final paiementsEffectues = mois > 0 ? mois : 1;
      _paiementsEffectuesController.text = paiementsEffectues.toString();
    }
  }

  String _formaterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de la dette'),
        actions: [
          IconButton(
            icon: Icon(_montreSimulateur ? Icons.calculate : Icons.science),
            onPressed: () {
              setState(() {
                _montreSimulateur = !_montreSimulateur;
                if (_montreSimulateur) {
                  _simulateurPrincipalController.text =
                      _prixAchatController.text;
                  _simulateurDureeController.text =
                      _nombrePaiementsController.text;
                  _calculerSimulateur('');
                }
              });
            },
            tooltip: _montreSimulateur
                ? 'Masquer simulateur'
                : 'Afficher simulateur',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_montreSimulateur) ...[
                _buildSimulateur(),
                const Divider(height: 32),
              ],
              _buildFormulaire(),
              const SizedBox(height: 16),
              _buildCalculsAutomatiques(),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _sauvegarder,
                  icon: const Icon(Icons.save),
                  label: const Text('Sauvegarder'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulateur() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Simulateur de prêt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _simulateurPrincipalController,
                    decoration: const InputDecoration(
                      labelText: 'Prix d\'achat (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _simulateurDureeController,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _simulateurTauxController,
                    decoration: const InputDecoration(
                      labelText: 'Taux APR (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerPaiement,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _simulateurPaiementController,
                    decoration: const InputDecoration(
                      labelText: 'Paiement mensuel (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _calculerSimulateur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tauxCalcule != null ||
                _paiementCalcule != null ||
                _erreurSimulateur != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _erreurSimulateur != null
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_erreurSimulateur != null)
                      Text(
                        _erreurSimulateur!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    if (_paiementCalcule != null)
                      Text(
                        'Paiement mensuel: \$${_paiementCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (_coutTotalCalcule != null)
                      Text(
                        'Coût total: \$${_coutTotalCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (_soldeRestantCalcule != null)
                      Text(
                        'Solde restant: \$${_soldeRestantCalcule!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _calculerSimulateur(String _) {
    setState(() {
      _tauxCalcule = null;
      _paiementCalcule = null;
      _soldeRestantCalcule = null;
      _coutTotalCalcule = null;
      _erreurSimulateur = null;
    });

    try {
      final principal = double.tryParse(_simulateurPrincipalController.text);
      final duree = int.tryParse(_simulateurDureeController.text);
      final taux = double.tryParse(_simulateurTauxController.text);
      final paiement = double.tryParse(_simulateurPaiementController.text);

      if (principal != null && duree != null && duree > 0) {
        if (taux != null) {
          // Calculer le paiement mensuel avec le taux donné
          final montantMensuel = CalculPretService.calculerPaiementMensuel(
            principal: principal,
            tauxAnnuel: taux,
            dureeMois: duree,
          );
          final coutTotal = CalculPretService.calculerCoutTotal(
            paiementMensuel: montantMensuel,
            dureeMois: duree,
          );
          setState(() {
            _paiementCalcule = montantMensuel;
            _coutTotalCalcule = coutTotal;
          });
        } else if (paiement != null) {
          // Calculer le taux avec le paiement donné
          final tauxEffectif = CalculPretService.calculerTauxEffectif(
            principal: principal,
            paiementMensuel: paiement,
            dureeMois: duree,
          );
          final coutTotal = CalculPretService.calculerCoutTotal(
            paiementMensuel: paiement,
            dureeMois: duree,
          );
          setState(() {
            _tauxCalcule = tauxEffectif;
            _coutTotalCalcule = coutTotal;
          });
        }
      }
    } catch (e) {
      setState(() {
        _erreurSimulateur = 'Erreur de calcul: $e';
      });
    }
  }

  void _calculerPaiement(String _) {
    _calculerSimulateur('');
  }

  Widget _buildFormulaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations principales',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Taux d'intérêt
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tauxController,
                        decoration: const InputDecoration(
                          labelText: 'Taux d\'intérêt annuel',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un taux d\'intérêt';
                          }
                          final taux = double.tryParse(value);
                          if (taux == null || taux < 0) {
                            return 'Veuillez entrer un taux valide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Prix d'achat
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prixAchatController,
                        decoration: const InputDecoration(
                          labelText: 'Prix d\'achat',
                          border: OutlineInputBorder(),
                          suffixText: '\$24',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un prix d\'achat';
                          }
                          final prix = double.tryParse(value);
                          if (prix == null || prix <= 0) {
                            return 'Veuillez entrer un prix valide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Durée du prêt
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombrePaiementsController,
                        decoration: const InputDecoration(
                          labelText: 'Durée du prêt',
                          border: OutlineInputBorder(),
                          suffixText: 'mois',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer la durée du prêt';
                          }
                          final mois = int.tryParse(value);
                          if (mois == null || mois <= 0) {
                            return 'Veuillez entrer une durée valide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Montant mensuel
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _montantMensuelController,
                        decoration: const InputDecoration(
                          labelText: 'Paiement mensuel',
                          border: OutlineInputBorder(),
                          suffixText: '\$24',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Paramètres avancés',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date de début (bouton)
                Row(
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 8),
                    const Text('Date de début :'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _parseDate(_dateDebutController.text) ??
                              DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _dateDebutController.text = _formaterDate(date);
                            _calculerPaiementsEffectues();
                          });
                        }
                      },
                      child: Text(_dateDebutController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nombre de paiements effectués
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paiementsEffectuesController,
                        decoration: const InputDecoration(
                          labelText: 'Paiements effectués',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculsAutomatiques() {
    print('DEBUG: _buildCalculsAutomatiques appelée');
    final prixAchat = double.tryParse(_prixAchatController.text);
    final tauxInteret = double.tryParse(_tauxController.text);
    final nombrePaiements = int.tryParse(_nombrePaiementsController.text);
    final paiementsEffectues = int.tryParse(_paiementsEffectuesController.text);
    final paiementMensuelSaisi = double.tryParse(
      _montantMensuelController.text,
    );
    print(
      'DEBUG: prixAchat=$prixAchat, tauxInteret=$tauxInteret, nombrePaiements=$nombrePaiements, paiementsEffectues=$paiementsEffectues, paiementMensuelSaisi=$paiementMensuelSaisi, _afficherResultatsCalcul=$_afficherResultatsCalcul',
    );
    double? montantMensuel;
    double? coutTotal;
    double? soldeRestant;
    double? interetsPayes;

    if (_afficherResultatsCalcul &&
        prixAchat != null &&
        tauxInteret != null &&
        nombrePaiements != null) {
      print('DEBUG: Bloc principal exécuté');
      montantMensuel = CalculPretService.calculerPaiementMensuel(
        principal: prixAchat,
        tauxAnnuel: tauxInteret,
        dureeMois: nombrePaiements,
      );
      coutTotal = CalculPretService.calculerCoutTotal(
        paiementMensuel: paiementMensuelSaisi ?? montantMensuel,
        dureeMois: nombrePaiements,
      );
      if (paiementsEffectues != null && paiementMensuelSaisi != null) {
        print('DEBUG: Bloc soldeRestant contrat exécuté');
        final paiementMensuelEffectif = paiementMensuelSaisi ?? montantMensuel;
        soldeRestant =
            coutTotal! - (paiementMensuelEffectif * paiementsEffectues);
        print(
          'DEBUG SOLDE CONTRAT: coutTotal=$coutTotal, paiementMensuel=$paiementMensuelEffectif, paiementsEffectues=$paiementsEffectues, soldeRestant=$soldeRestant',
        );
        final totalPaye = paiementMensuelEffectif * paiementsEffectues;
        final capitalRembourse = prixAchat - (soldeRestant ?? 0);
        interetsPayes = totalPaye - capitalRembourse;
      } else if (paiementsEffectues != null) {
        print('DEBUG: Bloc else if exécuté');
        soldeRestant = CalculPretService.calculerSoldeRestant(
          principal: prixAchat,
          tauxAnnuel: tauxInteret,
          dureeMois: nombrePaiements,
          paiementsEffectues: paiementsEffectues,
        );
        final totalPaye = montantMensuel * paiementsEffectues;
        final capitalRembourse = prixAchat - (soldeRestant ?? 0);
        interetsPayes = totalPaye - capitalRembourse;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Calculs automatiques',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _afficherResultatsCalcul = true;
                  // Calcul du montant mensuel et remplissage automatique du champ si vide
                  final prixAchat = double.tryParse(_prixAchatController.text);
                  final tauxInteret = double.tryParse(_tauxController.text);
                  final nombrePaiements = int.tryParse(
                    _nombrePaiementsController.text,
                  );
                  if (prixAchat != null &&
                      tauxInteret != null &&
                      nombrePaiements != null) {
                    final montantMensuel =
                        CalculPretService.calculerPaiementMensuel(
                          principal: prixAchat,
                          tauxAnnuel: tauxInteret,
                          dureeMois: nombrePaiements,
                        );
                    if ((_montantMensuelController.text.isEmpty ||
                            double.tryParse(_montantMensuelController.text) ==
                                null) &&
                        montantMensuel != null) {
                      _montantMensuelController.text = montantMensuel
                          .toStringAsFixed(2);
                    }
                  }
                });
              },
              icon: const Icon(Icons.calculate),
              label: const Text('Calculer le montant mensuel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (_afficherResultatsCalcul &&
                prixAchat != null &&
                tauxInteret != null &&
                nombrePaiements != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'DEBUG: prixAchat= ${prixAchat.toStringAsFixed(2)}, tauxInteret= ${tauxInteret.toStringAsFixed(2)}, paiementMensuel= ${paiementMensuelSaisi?.toStringAsFixed(2) ?? '-'}, paiementsEffectues= ${paiementsEffectues ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
              if (paiementMensuelSaisi != null)
                _buildResultatCalcul(
                  'Paiement mensuel saisi',
                  paiementMensuelSaisi.toStringAsFixed(2) + ' \$',
                )
              else if (montantMensuel != null)
                _buildResultatCalcul(
                  'Paiement mensuel (calculé)',
                  montantMensuel.toStringAsFixed(2) + ' \$',
                ),
              if (coutTotal != null)
                _buildResultatCalcul(
                  'Coût total',
                  coutTotal.toStringAsFixed(2) + ' \$',
                ),
              if (soldeRestant != null)
                _buildResultatCalcul(
                  'Solde restant',
                  soldeRestant.toStringAsFixed(2) + ' \$',
                ),
              if (interetsPayes != null)
                _buildResultatCalcul(
                  'Intérêts payés',
                  interetsPayes.toStringAsFixed(2) + ' \$',
                ),
            ] else ...[
              const Text(
                'Remplissez les champs puis cliquez sur "Calculer le montant mensuel" pour voir les résultats.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultatCalcul(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _sauvegarder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final detteModifiee = widget.dette.copyWith(
        tauxInteret: double.parse(_tauxController.text),
        dateDebut: _parseDate(_dateDebutController.text),
        dateFin: _parseDate(_dateFinController.text),
        montantMensuel: double.parse(_montantMensuelController.text),
        prixAchat: double.parse(_prixAchatController.text),
        nombrePaiements: int.parse(_nombrePaiementsController.text),
        paiementsEffectues: int.parse(_paiementsEffectuesController.text),
      );

      await DetteService().sauvegarderParametresDette(detteModifiee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  @override
  void dispose() {
    _tauxController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _montantMensuelController.dispose();
    _prixAchatController.dispose();
    _nombrePaiementsController.dispose();
    _paiementsEffectuesController.dispose();
    _simulateurTauxController.dispose();
    _simulateurPaiementController.dispose();
    _simulateurPrincipalController.dispose();
    _simulateurDureeController.dispose();
    super.dispose();
  }
}
