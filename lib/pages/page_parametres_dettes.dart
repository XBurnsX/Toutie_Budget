import 'package:flutter/material.dart';
import 'package:toutie_budget/models/dette.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';
import 'package:toutie_budget/services/calcul_pret_service.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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

  // Nouveaux contrôleurs et clés pour les paiements passés
  final _formKeyPaiementsPasses = GlobalKey<FormState>();
  final _nombrePaiementsPassesController = TextEditingController(text: '1');
  final _montantPaiementPasseController = TextEditingController();
  DateTime _datePaiementPasse = DateTime.now();
  bool _afficherSectionPaiementsPasses = false;
  Key _paiementsPassesKey = UniqueKey();

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
  Map<String, double?> calculs = {};
  bool _isUpdatingFromDate = false;

  // Total des paiements réellement enregistrés dans les transactions
  double _totalRemboursements = 0.0;
  double _totalAssocie = 0.0;
  double _totalCompte = 0.0;
  double? _soldeFirestore;

  late Dette _detteActuelle;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _detteListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _txListener;

  void _calculerEtMettrAJour() {
    final resultats = _calculerValeursPret();
    setState(() {
      calculs = resultats;
    });
  }

  @override
  void initState() {
    super.initState();
    _detteActuelle = widget.dette;
    _chargerDonnees();
    _nombrePaiementsController.addListener(_onParametresChanges);
    _dateDebutController.addListener(_onParametresChanges);
    _dateFinController.addListener(_onParametresChanges);
    _tauxController.addListener(_onParametresChanges);
    _prixAchatController.addListener(_onParametresChanges);
    _montantMensuelController.addListener(_onParametresChanges);
    _paiementsEffectuesController.addListener(_onParametresChanges);

    _detteListener = FirebaseFirestore.instance
        .collection('dettes')
        .doc(widget.dette.id)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      setState(() {
        _detteActuelle = Dette.fromMap(data);
        _soldeFirestore = _detteActuelle.solde;
        _paiementsEffectuesController.text =
            (_detteActuelle.paiementsEffectues ?? 0).toString();
      });
    });

    void updateAssocie(QuerySnapshot<Map<String, dynamic>> snapshot) {
      double total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final typeMvt = data['typeMouvement'] as String?;
        if (typeMvt == 'remboursementEffectue' ||
            typeMvt == 'remboursementRecu') {
          total += montant;
        }
      }
      _totalAssocie = total;
      setState(() {
        _totalRemboursements = _totalAssocie + _totalCompte;
        _calculerEtMettrAJour();
      });
    }

    _txListener = FirebaseFirestore.instance
        .collection('transactions')
        .where('compteDePassifAssocie', isEqualTo: widget.dette.id)
        .snapshots()
        .listen(updateAssocie);

    FirebaseFirestore.instance
        .collection('transactions')
        .where('compteId', isEqualTo: widget.dette.id)
        .snapshots()
        .listen((snapshot) {
      double total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final typeMvt = data['typeMouvement'] as String?;
        if (typeMvt == 'remboursementEffectue' ||
            typeMvt == 'remboursementRecu') {
          total += montant;
        }
      }
      _totalCompte = total;
      setState(() {
        _totalRemboursements = _totalAssocie + _totalCompte;
        _calculerEtMettrAJour();
      });
    });
  }

  void _chargerDonnees() {
    if (_detteActuelle.tauxInteret != null) {
      _tauxController.text = _detteActuelle.tauxInteret!.toStringAsFixed(2);
    }

    final dateDebut = _detteActuelle.dateDebut ?? DateTime.now();
    _dateDebutController.text = _formaterDate(dateDebut);

    if (_detteActuelle.dateFin != null) {
      _dateFinController.text = _formaterDate(_detteActuelle.dateFin!);
    } else {
      _calculerDateFinParDefaut();
    }

    if (_detteActuelle.montantMensuel != null &&
        _detteActuelle.montantMensuel! > 0) {
      _montantMensuelController.text =
          _detteActuelle.montantMensuel!.toStringAsFixed(2);
    } else {
      // S'il n'y a pas de paiement mensuel, on le calcule
      final prixAchat = _toDouble(_prixAchatController.text);
      final tauxInteret = _toDouble(_tauxController.text);
      final dureeMois = int.tryParse(_nombrePaiementsController.text);

      if (prixAchat != null &&
          tauxInteret != null &&
          dureeMois != null &&
          dureeMois > 0) {
        final montantMensuel = CalculPretService.calculerPaiementMensuel(
          principal: prixAchat,
          tauxAnnuel: tauxInteret,
          dureeMois: dureeMois,
        );
        _montantMensuelController.text = montantMensuel.toStringAsFixed(2);
      }
    }

    if (_detteActuelle.prixAchat != null && _detteActuelle.prixAchat! > 0) {
      _prixAchatController.text = _detteActuelle.prixAchat!.toStringAsFixed(2);
    } else {
      // Si aucun prix d'achat n'est défini, on utilise le montant initial comme base
      _prixAchatController.text =
          _detteActuelle.montantInitial.toStringAsFixed(2);
    }

    if (_detteActuelle.nombrePaiements != null) {
      _nombrePaiementsController.text =
          _detteActuelle.nombrePaiements!.toString();
    }

    if (_detteActuelle.paiementsEffectues != null) {
      _paiementsEffectuesController.text =
          _detteActuelle.paiementsEffectues!.toString();
    } else {
      _calculerPaiementsEffectues();
    }

    _calculerEtMettrAJour(); // On fait un seul calcul initial
  }

  void _calculerPaiementsEffectues() {
    final dateDebut = _parseDate(_dateDebutController.text);
    if (dateDebut != null) {
      final maintenant = DateTime.now();
      final mois = (maintenant.year - dateDebut.year) * 12 +
          (maintenant.month - dateDebut.month);
      final paiementsEffectues = mois > 0 ? mois : 1;
      _paiementsEffectuesController.text = paiementsEffectues.toString();
    }
  }

  void _onParametresChanges() {
    if (_isUpdatingFromDate) {
      // Si la mise à jour vient du sélecteur de date, on recalcule seulement les valeurs
      // sans toucher à la date de fin elle-même pour éviter une boucle.
      setState(() {
        _calculerEtMettrAJour();
      });
      return;
    }

    _calculerDateFinParDefaut(); // Met à jour la date de fin si la durée change

    setState(() {
      _calculerEtMettrAJour(); // On met à jour les calculs à chaque changement
    });
  }

  void _calculerDateFinParDefaut() {
    final dateDebut = _parseDate(_dateDebutController.text);
    final dureeMois = int.tryParse(_nombrePaiementsController.text);

    if (dateDebut != null && dureeMois != null && dureeMois > 0) {
      final dateFin = DateTime(
        dateDebut.year,
        dateDebut.month + dureeMois - 1,
        dateDebut.day,
      );
      if (_dateFinController.text != _formaterDate(dateFin)) {
        setState(() {
          _dateFinController.text = _formaterDate(dateFin);
          // ON NE RECALCULE PAS LE PAIEMENT ICI
        });
      }
    }
  }

  void _recalculerPaiementMensuel() {
    // Logique ultra-simplifiée, comme demandé.
    // Solde restant (tel qu'affiché) / nombre de mois restants.

    final calculs = _calculerValeursPret();
    final soldeRestant = calculs['solde'];

    if (soldeRestant == null || soldeRestant <= 0) {
      _montantMensuelController.text = '0.00';
      return;
    }

    final dateFin = _parseDate(_dateFinController.text);
    if (dateFin == null) return;

    final dateDebutCalcul = DateTime.now();
    if (!dateFin.isAfter(dateDebutCalcul)) {
      _montantMensuelController.text = soldeRestant.toStringAsFixed(2);
      return;
    }

    // Calculer le nombre de mois restants, en incluant le mois actuel.
    int nombreMoisRestants = (dateFin.year - dateDebutCalcul.year) * 12 +
        dateFin.month -
        dateDebutCalcul.month +
        1;

    if (nombreMoisRestants <= 0) {
      nombreMoisRestants = 1;
    }

    final nouveauPaiementMensuel = soldeRestant / nombreMoisRestants;

    _montantMensuelController.text = nouveauPaiementMensuel.toStringAsFixed(2);
  }

  Future<void> _selectionnerDateFin() async {
    final dateDebut = _parseDate(_dateDebutController.text);
    if (dateDebut == null) return;

    final dureeMois = int.tryParse(_nombrePaiementsController.text);
    if (dureeMois == null || dureeMois <= 0) return;

    final dateFinMaximale = DateTime(
      dateDebut.year,
      dateDebut.month + dureeMois - 1,
      dateDebut.day,
    );

    final nouvelleDateFin = await showDatePicker(
      context: context,
      initialDate: _parseDate(_dateFinController.text) ?? dateFinMaximale,
      firstDate: dateDebut.add(const Duration(days: 1)),
      lastDate: dateFinMaximale,
    );

    if (nouvelleDateFin != null) {
      _isUpdatingFromDate = true;
      setState(() {
        _dateFinController.text = _formaterDate(nouvelleDateFin);
        // La durée du prêt est fixe. On ne modifie que la date de fin et on recalcule le paiement.
        _recalculerPaiementMensuel();
      });
      _isUpdatingFromDate = false;
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
      body: _montreSimulateur
          ? Center(
              child: Transform.translate(
                offset: const Offset(0, -150),
                child: SingleChildScrollView(child: _buildSimulateur()),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormulaire(),
                    const SizedBox(height: 16),
                    _buildCalculsAutomatiques(),
                    const SizedBox(height: 24),
                    _buildPaiementsPassesSection(),
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
                    readOnly: true,
                    onTap: () => _ouvrirClavierNumerique(
                      _simulateurPrincipalController,
                      isMoney: true,
                    ),
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
                    readOnly: true,
                    onTap: () => _ouvrirClavierNumerique(
                      _simulateurDureeController,
                      showDecimal: false,
                      isMoney: false,
                    ),
                    onChanged: _calculerSimulateur,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _simulateurTauxController,
                    decoration: const InputDecoration(
                      labelText: 'Taux APR (%)',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () => _ouvrirClavierNumerique(
                      _simulateurTauxController,
                      isMoney: false,
                    ),
                    onChanged: _calculerPaiement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tauxCalcule != null ||
                _paiementCalcule != null ||
                _erreurSimulateur != null) ...[
              Center(
                child: Container(
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
      final principal = _toDouble(_simulateurPrincipalController.text);
      final duree = int.tryParse(_simulateurDureeController.text);
      final taux = double.tryParse(_simulateurTauxController.text);
      final paiement = _toDouble(_simulateurPaiementController.text);

      if (principal != null && duree != null && duree > 0) {
        if (taux != null) {
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
                        readOnly: true,
                        onTap: () => _ouvrirClavierNumerique(
                          _tauxController,
                          isMoney: false,
                        ),
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prixAchatController,
                        decoration: const InputDecoration(
                          labelText: 'Prix d\'achat (\$)',
                          border: OutlineInputBorder(),
                          suffixText: '\$ ',
                        ),
                        readOnly: true,
                        onTap: () => _ouvrirClavierNumerique(
                          _prixAchatController,
                          isMoney: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un prix d\'achat';
                          }
                          final prix = _toDouble(value);
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
                        readOnly: true,
                        onTap: () => _ouvrirClavierNumerique(
                          _nombrePaiementsController,
                          showDecimal: false,
                          isMoney: false,
                        ),
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
                          initialDate: _parseDate(_dateDebutController.text) ??
                              DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _dateDebutController.text = _formaterDate(date);
                          });
                        }
                      },
                      child: Text(_dateDebutController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.event_available),
                    const SizedBox(width: 8),
                    const Text('Date de fin :'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _selectionnerDateFin,
                      child: Text(
                        _dateFinController.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paiementsEffectuesController,
                        decoration: const InputDecoration(
                          labelText: 'Paiements effectués (automatique)',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
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
    final calculs = _calculerValeursPret();

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
            _buildResultatCalcul(
              'Paiement mensuel (calculé)',
              '${calculs['montantMensuel']?.toStringAsFixed(2) ?? '0.00'} \$',
            ),
            _buildResultatCalcul(
              'Coût total',
              '${calculs['coutTotal']?.toStringAsFixed(2) ?? '0.00'} \$',
            ),
            _buildResultatCalcul(
              'Solde restant',
              '${calculs['solde']?.toStringAsFixed(2) ?? '0.00'} \$',
            ),
            _buildResultatCalcul(
              'Intérêts payés',
              '${calculs['interetsPayes']?.toStringAsFixed(2) ?? '0.00'} \$',
            ),
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

    final dateDebut = _parseDate(_dateDebutController.text);
    final dateFin = _parseDate(_dateFinController.text);
    final dureeMoisMax = int.tryParse(_nombrePaiementsController.text) ?? 0;
    if (dateDebut != null && dateFin != null && dureeMoisMax > 0) {
      final dateFinMax = DateTime(
        dateDebut.year,
        dateDebut.month + dureeMoisMax - 1,
        dateDebut.day,
      );
      if (dateFin.isAfter(dateFinMax)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La date de fin dépasse la durée du prêt.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      final calculs = _calculerValeursPret();
      final coutTotalCalcule = calculs['coutTotal'];
      final interetsPayesCalcules = calculs['interetsPayes'];
      final montantMensuelCalcule = calculs['montantMensuel'];

      final totalRemboursements = _calculerTotalRemboursementsHistorique();
      double? nouveauSolde;
      if (coutTotalCalcule != null) {
        nouveauSolde = coutTotalCalcule - totalRemboursements;
      } else {
        nouveauSolde = _detteActuelle.montantInitial - totalRemboursements;
      }
      nouveauSolde = (nouveauSolde < 0) ? 0 : nouveauSolde;

      final ancienSolde = _detteActuelle.solde;

      final detteModifiee = _detteActuelle.copyWith(
        tauxInteret: _toDouble(_tauxController.text) ?? 0,
        dateDebut: _parseDate(_dateDebutController.text),
        dateFin: _parseDate(_dateFinController.text),
        montantMensuel: montantMensuelCalcule,
        prixAchat: _toDouble(_prixAchatController.text) ?? 0,
        coutTotal: coutTotalCalcule,
        interetsPayes: interetsPayesCalcules,
        nombrePaiements: int.tryParse(_nombrePaiementsController.text),
        paiementsEffectues: int.tryParse(_paiementsEffectuesController.text),
        solde: nouveauSolde,
      );

      await DetteService().sauvegarderDetteManuelleComplet(detteModifiee);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés avec succès!')),
      );

      if (mounted) {
        Navigator.of(context)
            .pop(true); // Indique qu'une modification a eu lieu
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    }
  }

  void _enregistrerPaiementsPasses() async {
    if (_formKeyPaiementsPasses.currentState!.validate()) {
      final nombrePaiements =
          int.tryParse(_nombrePaiementsPassesController.text);
      final montantParPaiement =
          _toDouble(_montantPaiementPasseController.text);

      if (nombrePaiements != null && montantParPaiement != null) {
        // 1. Calculer le nouveau solde de manière simple et directe
        final calculsActuels = _calculerValeursPret();
        final coutTotal = calculsActuels['coutTotal'];
        if (coutTotal == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur: Coût total non calculé.'),
            backgroundColor: Colors.red,
          ));
          return;
        }
        final totalPaiementsPasses = nombrePaiements * montantParPaiement;
        final nouveauSolde = coutTotal - totalPaiementsPasses;

        // 2. Préparer la liste des transactions pour l'historique
        final List<MouvementDette> nouveauxMouvements = [];
        final dateDebut =
            _parseDate(_dateDebutController.text) ?? DateTime.now();

        for (int i = 0; i < nombrePaiements; i++) {
          final dateMouvement =
              DateTime(dateDebut.year, dateDebut.month + i, dateDebut.day);
          nouveauxMouvements.add(MouvementDette(
            id: 'passe_${DateTime.now().millisecondsSinceEpoch}_$i',
            montant: -montantParPaiement, // Montant individuel
            type: widget.dette.type == 'dette'
                ? 'remboursement_effectue'
                : 'remboursement_recu',
            date: dateMouvement,
            note: 'Paiement passé #${i + 1} enregistré',
          ));
        }

        // 3. Calculer le nouveau total de paiements effectués
        final paiementsActuels = widget.dette.paiementsEffectues ?? 0;
        final nouveauCompteurPaiements = paiementsActuels + nombrePaiements;

        try {
          // 4. Appeler la nouvelle méthode du service
          await DetteService().enregistrerPaiementsPasses(
            widget.dette.id,
            nouveauSolde < 0 ? 0 : nouveauSolde,
            nouveauCompteurPaiements,
            nouveauxMouvements,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiements passés enregistrés avec succès'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _nombrePaiementsPassesController.text = '1';
            _montantPaiementPasseController.clear();
            _afficherSectionPaiementsPasses = false;
            _paiementsPassesKey =
                UniqueKey(); // Force le rebuild du ExpansionTile
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPaiementsPassesSection() {
    if (!widget.dette.estManuelle || widget.dette.archive) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        child: ExpansionTile(
          key: _paiementsPassesKey,
          title: const Text('Enregistrer des paiements passés',
              style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: _afficherSectionPaiementsPasses,
          onExpansionChanged: (expanded) {
            setState(() {
              _afficherSectionPaiementsPasses = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKeyPaiementsPasses,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombrePaiementsPassesController,
                      decoration: const InputDecoration(
                          labelText: 'Nombre de paiements déjà effectués',
                          border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () => _ouvrirClavierNumerique(
                        _nombrePaiementsPassesController,
                        showDecimal: false,
                        isMoney: false,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nombre';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _montantPaiementPasseController,
                      decoration: const InputDecoration(
                          labelText: 'Montant par paiement',
                          border: OutlineInputBorder(),
                          suffixText: '\$'),
                      readOnly: true,
                      onTap: () => _ouvrirClavierNumerique(
                        _montantPaiementPasseController,
                        isMoney: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        if (_toDouble(value) == null ||
                            _toDouble(value)! <= 0) {
                          return 'Veuillez entrer un montant valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.date_range),
                        const SizedBox(width: 8),
                        const Text('Date du dernier paiement:'),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _datePaiementPasse,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _datePaiementPasse = date;
                              });
                            }
                          },
                          child: Text(_formaterDate(_datePaiementPasse)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _enregistrerPaiementsPasses,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les paiements'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double?> _calculerValeursPret() {
    final prixAchat = _toDouble(_prixAchatController.text);
    final tauxInteret = _toDouble(_tauxController.text);
    final paiementMensuelSaisi = _toDouble(_montantMensuelController.text);

    final dateDebut = _parseDate(_dateDebutController.text);
    final dateFin = _parseDate(_dateFinController.text);
    int? dureeMois;
    if (dateDebut != null && dateFin != null && dateFin.isAfter(dateDebut)) {
      dureeMois = (dateFin.year - dateDebut.year) * 12 +
          dateFin.month -
          dateDebut.month +
          1;
    }

    double? montantMensuel;
    double? coutTotal;
    double? solde;
    double? interetsPayes;

    if (prixAchat != null &&
        tauxInteret != null &&
        dureeMois != null &&
        dureeMois > 0) {
      montantMensuel = CalculPretService.calculerPaiementMensuel(
        principal: prixAchat,
        tauxAnnuel: tauxInteret,
        dureeMois: dureeMois,
      );

      if (widget.dette.coutTotal != null) {
        coutTotal = widget.dette.coutTotal;
      } else {
        coutTotal = CalculPretService.calculerCoutTotal(
          paiementMensuel: montantMensuel,
          dureeMois: dureeMois,
        );
      }

      final totalRemboursements = _calculerTotalRemboursementsHistorique();
      if (coutTotal != null) {
        solde = coutTotal - totalRemboursements;
      } else {
        solde = _detteActuelle.montantInitial - totalRemboursements;
      }
      solde = (solde < 0) ? 0 : solde;

      if (_detteActuelle.interetsPayes != null) {
        interetsPayes = _detteActuelle.interetsPayes;
      } else {
        final tauxMensuel = tauxInteret / 100 / 12;
        double soldeSimule = prixAchat;
        double interetsSimules = 0.0;
        double remboursementsRestants = totalRemboursements;

        while (remboursementsRestants > 0 && soldeSimule > 0) {
          final interetMensuel = soldeSimule * tauxMensuel;
          final paiementEffectif = remboursementsRestants >= montantMensuel
              ? montantMensuel
              : remboursementsRestants;

          if (paiementEffectif <= interetMensuel) {
            interetsSimules += paiementEffectif;
          } else {
            interetsSimules += interetMensuel;
            soldeSimule -= (paiementEffectif - interetMensuel);
          }

          remboursementsRestants -= paiementEffectif;
        }

        interetsPayes = interetsSimules;
      }
    }

    return {
      'montantMensuel': montantMensuel,
      'coutTotal': coutTotal,
      'solde': solde,
      'interetsPayes': interetsPayes,
      'paiementMensuelSaisi': paiementMensuelSaisi,
    };
  }

  double _calculerTotalRemboursementsHistorique() {
    double total = 0.0;
    for (final mouvement in _detteActuelle.historique) {
      if (mouvement.type == 'remboursement_recu' ||
          mouvement.type == 'remboursement_effectue') {
        total += mouvement.montant.abs();
      }
    }
    return total;
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

  double? _toDouble(String text) {
    final sanitized = text.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  @override
  void dispose() {
    _nombrePaiementsController.removeListener(_onParametresChanges);
    _dateDebutController.removeListener(_onParametresChanges);
    _dateFinController.removeListener(_onParametresChanges);
    _tauxController.removeListener(_onParametresChanges);
    _prixAchatController.removeListener(_onParametresChanges);
    _montantMensuelController.removeListener(_onParametresChanges);
    _paiementsEffectuesController.removeListener(_onParametresChanges);

    _detteListener?.cancel();
    _txListener?.cancel();

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

    _nombrePaiementsPassesController.dispose();
    _montantPaiementPasseController.dispose();

    super.dispose();
  }

  void _ouvrirClavierNumerique(
    TextEditingController controller, {
    bool showDecimal = true,
    bool isMoney = true,
  }) {
    final valeurOriginale = controller.text;
    controller.text = isMoney ? '0.00' : '0';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: NumericKeyboard(
            controller: controller,
            showDecimal: showDecimal,
            isMoney: isMoney,
            onClear: () {
              setState(() {
                controller.clear();
              });
            },
          ),
        );
      },
    ).whenComplete(() {
      final valeurActuelle = controller.text;
      if ((isMoney && (valeurActuelle == '0.00' || valeurActuelle.isEmpty)) ||
          (!isMoney && (valeurActuelle == '0' || valeurActuelle.isEmpty))) {
        setState(() {
          controller.text = valeurOriginale;
        });
      }
    });
  }
}
