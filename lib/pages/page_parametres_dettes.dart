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

  // Total des paiements réellement enregistrés dans les transactions
  double _totalRemboursements = 0.0;
  double _totalAssocie = 0.0;
  double _totalCompte = 0.0;
  double? _soldeFirestore;

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
    _chargerDonnees();
    // Ajouter des listeners pour la mise à jour automatique des calculs
    _nombrePaiementsController.addListener(_onParametresChanges);
    _dateDebutController.addListener(_onParametresChanges);
    _dateFinController.addListener(_onParametresChanges);
    _tauxController.addListener(_onParametresChanges);
    _prixAchatController.addListener(_onParametresChanges);
    _montantMensuelController.addListener(_onParametresChanges);
    _paiementsEffectuesController.addListener(_onParametresChanges);

    // Écouter en temps réel les modifications du document dette pour mettre à jour
    _detteListener = FirebaseFirestore.instance
        .collection('dettes')
        .doc(widget.dette.id)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;
          final data = snapshot.data();
          if (data == null) return;
          final paiements = (data['paiementsEffectues'] as num?)?.toInt() ?? 0;
          _soldeFirestore = (data['solde'] as num?)?.toDouble();

          if (_paiementsEffectuesController.text != paiements.toString()) {
            setState(() {
              _paiementsEffectuesController.text = paiements.toString();
            });
          }
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
    if (widget.dette.tauxInteret != null) {
      _tauxController.text = widget.dette.tauxInteret!.toStringAsFixed(2);
    }

    // Date de début (par défaut aujourd'hui)
    final dateDebut = widget.dette.dateDebut ?? DateTime.now();
    _dateDebutController.text = _formaterDate(dateDebut);

    if (widget.dette.dateFin != null) {
      _dateFinController.text = _formaterDate(widget.dette.dateFin!);
    } else {
      _calculerDateFinParDefaut();
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
      _calculerPaiementsEffectues();
    }

    // Calculs initiaux après chargement
    _onParametresChanges();
    _calculerEtMettrAJour();
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

  void _onParametresChanges() {
    // Fonction centrale qui recalcule tout ce qui doit l'être
    _calculerDateFinParDefaut();

    // Vérifier que la date de fin courante ne dépasse pas la durée maximale
    final dateDebut = _parseDate(_dateDebutController.text);
    final dureeMois = int.tryParse(_nombrePaiementsController.text);
    final dateFinMax = (dateDebut != null && dureeMois != null && dureeMois > 0)
        ? DateTime(
            dateDebut.year,
            dateDebut.month + dureeMois - 1,
            dateDebut.day,
          )
        : null;

    final dateFinCourante = _parseDate(_dateFinController.text);

    if (dateFinMax != null &&
        dateFinCourante != null &&
        dateFinCourante.isAfter(dateFinMax)) {
      // Remettre la date au maximum autorisé
      setState(() {
        _dateFinController.text = _formaterDate(dateFinMax);
      });
    }

    // Mettre à jour les calculs et l'interface utilisateur
    setState(() {
      _calculerEtMettrAJour();
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
          _recalculerPaiementMensuel();
        });
      }
    }
  }

  void _recalculerPaiementMensuel() {
    final prixAchat = _toDouble(_prixAchatController.text);
    final tauxInteret = _toDouble(_tauxController.text);
    final dateDebut = _parseDate(_dateDebutController.text);
    final dateFin = _parseDate(_dateFinController.text);

    if (prixAchat != null &&
        tauxInteret != null &&
        dateDebut != null &&
        dateFin != null) {
      final nouvelleDureeMois =
          (dateFin.year - dateDebut.year) * 12 +
          dateFin.month -
          dateDebut.month +
          1;

      if (nouvelleDureeMois > 0) {
        final nouveauPaiementMensuel =
            CalculPretService.calculerPaiementMensuel(
              principal: prixAchat,
              tauxAnnuel: tauxInteret,
              dureeMois: nouvelleDureeMois,
            );
        _montantMensuelController.text = nouveauPaiementMensuel.toStringAsFixed(
          2,
        );
      }
    }
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
      setState(() {
        _dateFinController.text = _formaterDate(nouvelleDateFin);
        _recalculerPaiementMensuel();
        // Déclencher la mise à jour des calculs automatiques
      });
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
                // Prix d'achat
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
                          suffixText: '\$',
                        ),
                        readOnly: true,
                        onTap: () => _ouvrirClavierNumerique(
                          _montantMensuelController,
                          isMoney: true,
                        ),
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
                          });
                        }
                      },
                      child: Text(_dateDebutController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date de fin
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
                // Nombre de paiements effectués
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
            ElevatedButton.icon(
              onPressed: () {
                // Calcul du montant mensuel et remplissage automatique du champ
                final prixAchat = _toDouble(_prixAchatController.text);
                final tauxInteret = _toDouble(_tauxController.text);
                final dateDebut = _parseDate(_dateDebutController.text);
                final dateFin = _parseDate(_dateFinController.text);

                if (prixAchat != null &&
                    tauxInteret != null &&
                    dateDebut != null &&
                    dateFin != null &&
                    prixAchat > 0 &&
                    tauxInteret >= 0 &&
                    dateFin.isAfter(dateDebut)) {
                  final dureeMois =
                      (dateFin.year - dateDebut.year) * 12 +
                      dateFin.month -
                      dateDebut.month +
                      1;

                  final montantMensuel =
                      CalculPretService.calculerPaiementMensuel(
                        principal: prixAchat,
                        tauxAnnuel: tauxInteret,
                        dureeMois: dureeMois,
                      );

                  setState(() {
                    _montantMensuelController.text = montantMensuel
                        .toStringAsFixed(2);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paiement mensuel calculé automatiquement'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez remplir tous les champs requis'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.calculate),
              label: const Text('Calculer le paiement mensuel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox.shrink(),
            ),
            if (calculs['paiementMensuelSaisi'] != null)
              _buildResultatCalcul(
                'Paiement mensuel saisi',
                '${calculs['paiementMensuelSaisi']!.toStringAsFixed(2)} \$',
              )
            else if (calculs['montantMensuel'] != null)
              _buildResultatCalcul(
                'Paiement mensuel (calculé)',
                '${calculs['montantMensuel']!.toStringAsFixed(2)} \$',
              ),
            if (calculs['coutTotal'] != null)
              _buildResultatCalcul(
                'Coût total',
                '${calculs['coutTotal']!.toStringAsFixed(2)} \$',
              ),
            if (calculs['solde'] != null)
              _buildResultatCalcul(
                'Solde restant',
                '${calculs['solde']!.toStringAsFixed(2)} \$',
              ),
            if (calculs['interetsPayes'] != null)
              _buildResultatCalcul(
                'Intérêts payés',
                '${calculs['interetsPayes']!.toStringAsFixed(2)} \$',
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

    // Validation supplémentaire : la date de fin ne doit pas dépasser la durée max
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
      // Calculer le nouveau solde avec coutTotal - totalTransactions
      final calculs = _calculerValeursPret();
      final coutTotalCalcule = calculs['coutTotal'];
      final interetsPayesCalcules = calculs['interetsPayes'];

      double? nouveauSolde;
      if (coutTotalCalcule != null) {
        // Calculer le nouveau solde : coutTotal - transactions
        final soldeCalcule = coutTotalCalcule - _totalRemboursements;
        nouveauSolde = soldeCalcule < 0 ? 0 : soldeCalcule;
      } else {
        // Fallback si pas de coût total
        nouveauSolde = _calculerValeursPret()['solde'];
      }

      final ancienSolde = widget.dette.solde;

      // Créer l'objet Dette complet avec toutes les informations à jour
      final detteModifiee = widget.dette.copyWith(
        tauxInteret: _toDouble(_tauxController.text) ?? 0,
        dateDebut: _parseDate(_dateDebutController.text),
        dateFin: _parseDate(_dateFinController.text),
        montantMensuel: _toDouble(_montantMensuelController.text) ?? 0,
        prixAchat: _toDouble(_prixAchatController.text) ?? 0,
        coutTotal: coutTotalCalcule, // Stocker le coût total avec intérêts
        interetsPayes: interetsPayesCalcules, // Stocker les intérêts payés
        nombrePaiements: int.tryParse(_nombrePaiementsController.text),
        paiementsEffectues: int.tryParse(_paiementsEffectuesController.text),
        solde: nouveauSolde, // On met à jour le solde ici pour la sauvegarde
      );

      // Appeler la méthode de sauvegarde unifiée
      await DetteService().sauvegarderDetteManuelleComplet(detteModifiee);

      // Si le solde a changé, créer une transaction d'ajustement
      if (nouveauSolde != null && ancienSolde != nouveauSolde) {
        final montantAjustement = ancienSolde - nouveauSolde;
        await FirebaseService().creerTransactionAjustementSoldeDette(
          detteId: widget.dette.id,
          nomCompte: widget.dette.nomTiers, // ou le nom du compte si différent
          montantAjustement: montantAjustement,
        );
      }

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

  Map<String, double?> _calculerValeursPret() {
    final prixAchat = _toDouble(_prixAchatController.text);
    final tauxInteret = _toDouble(_tauxController.text);
    final paiementMensuelSaisi = _toDouble(_montantMensuelController.text);

    final dateDebut = _parseDate(_dateDebutController.text);
    final dateFin = _parseDate(_dateFinController.text);
    int? dureeMois;
    if (dateDebut != null && dateFin != null && dateFin.isAfter(dateDebut)) {
      dureeMois =
          (dateFin.year - dateDebut.year) * 12 +
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

      // Calculer le coût total
      if (widget.dette.coutTotal != null) {
        coutTotal = widget.dette.coutTotal;
      } else {
        // Calculer pour compatibilité avec anciennes dettes
        coutTotal = CalculPretService.calculerCoutTotal(
          paiementMensuel: montantMensuel,
          dureeMois: dureeMois,
        );
      }

      // Utiliser TOUJOURS le solde Firebase pour l'affichage
      solde = _soldeFirestore;

      // Utiliser les intérêts payés stockés dans Firebase si disponibles
      if (widget.dette.interetsPayes != null) {
        interetsPayes = widget.dette.interetsPayes;
      } else {
        // Sinon calculer pour compatibilité avec anciennes dettes
        if (_totalRemboursements > 0) {
          final tauxMensuel = tauxInteret / 100 / 12;
          double soldeSimule = prixAchat;
          double interetsSimules = 0.0;

          // Simuler chaque paiement pour calculer les intérêts réels
          double remboursementsRestants = _totalRemboursements;

          while (remboursementsRestants > 0 && soldeSimule > 0) {
            final interetMensuel = soldeSimule * tauxMensuel;
            final paiementEffectif = remboursementsRestants >= montantMensuel
                ? montantMensuel
                : remboursementsRestants;

            if (paiementEffectif <= interetMensuel) {
              // Paiement ne couvre que les intérêts (ou moins)
              interetsSimules += paiementEffectif;
            } else {
              // Paiement couvre intérêts + capital
              interetsSimules += interetMensuel;
              soldeSimule -= (paiementEffectif - interetMensuel);
            }

            remboursementsRestants -= paiementEffectif;
          }

          interetsPayes = interetsSimules;
        } else {
          interetsPayes = 0;
        }
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

  // Nouvelle fonction : convertit un texte (ex. « 12.34 $ ») en double
  double? _toDouble(String text) {
    // Supprime tout caractère qui n'est pas chiffre, point ou signe moins
    final sanitized = text.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
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
    // Retirer tous les listeners
    _nombrePaiementsController.removeListener(_onParametresChanges);
    _dateDebutController.removeListener(_onParametresChanges);
    _dateFinController.removeListener(_onParametresChanges);
    _tauxController.removeListener(_onParametresChanges);
    _prixAchatController.removeListener(_onParametresChanges);
    _montantMensuelController.removeListener(_onParametresChanges);
    _paiementsEffectuesController.removeListener(_onParametresChanges);

    // Annuler l'abonnement Firestore
    _detteListener?.cancel();
    _txListener?.cancel();
    super.dispose();
  }

  // Ajout d'une fonction utilitaire pour ouvrir le clavier numérique personnalisé
  void _ouvrirClavierNumerique(
    TextEditingController controller, {
    bool showDecimal = true,
    bool isMoney = true,
  }) {
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
          ),
        );
      },
    );
  }
}
