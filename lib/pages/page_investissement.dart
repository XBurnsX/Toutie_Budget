import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/compte.dart';
import '../services/firebase_service.dart';
import '../services/investissement_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:toutie_budget/models/transaction_model.dart' as app_model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toutie_budget/widgets/numeric_keyboard.dart';

class CompteAReboursProchaineMAJ extends StatefulWidget {
  final InvestissementService investissementService;

  const CompteAReboursProchaineMAJ({
    super.key,
    required this.investissementService,
  });

  @override
  State<CompteAReboursProchaineMAJ> createState() =>
      _CompteAReboursProchaineMAJState();
}

class _CompteAReboursProchaineMAJState
    extends State<CompteAReboursProchaineMAJ> {
  Timer? _timer;
  String _tempsRestant = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // S'assurer que le widget est toujours à l'écran
        setState(() {
          _tempsRestant = widget.investissementService.getNextUpdateTime();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Prochaine MAJ: $_tempsRestant');
  }
}

class PageInvestissement extends StatefulWidget {
  final String compteId;

  const PageInvestissement({super.key, required this.compteId});

  @override
  State<PageInvestissement> createState() => _PageInvestissementState();
}

class _PageInvestissementState extends State<PageInvestissement> {
  final InvestissementService _investissementService = InvestissementService();
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic> _performanceCompte = {};
  final List<Map<String, dynamic>> _historiquePrix = [];
  bool _isLoading = true;
  Compte? _compte;

  // Variables pour le graphique
  List<List<Map<String, dynamic>>> _historiquePrixPourGraphique = [];
  List<app_model.Transaction> _transactionsPourGraphique = [];

  @override
  void initState() {
    super.initState();
    // Démarrer le service d'investissement pour les mises à jour automatiques
    _investissementService.startService();
    _chargerDonnees().then((_) => _checkPremiereOuverture());
  }

  @override
  void dispose() {
    // Arrêter le service d'investissement
    _investissementService.stopService();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger le compte
      final comptes = await _firebaseService.lireComptes().first;
      final compte = comptes.firstWhere((c) => c.id == widget.compteId,
          orElse: () => Compte(
                id: widget.compteId,
                nom: '',
                type: '',
                solde: 0.0,
                couleur: 0xFF2196F3,
                pretAPlacer: 0.0,
                dateCreation: DateTime.now(),
                estArchive: false,
              ));

      // Charger les actions
      final actions = await _investissementService.getActions(widget.compteId);

      // Ajouter les symboles des actions existantes à la queue de mise à jour
      final symbols =
          actions.map((action) => action['symbol'] as String).toList();
      _investissementService.addSymbolsToUpdateQueue(symbols);

      // Charger la performance globale
      final performance = await _investissementService
          .calculerPerformanceCompte(widget.compteId);

      // NOUVEAU : Charger les données pour le graphique
      final transactions =
          await _firebaseService.lireTransactions(widget.compteId).first;
      final historiques = await Future.wait(actions.map((a) =>
          _investissementService.getHistoriquePrix(a['symbol'], limit: 30)));

      // On sauvegarde le snapshot du jour si nécessaire
      await _investissementService
          .sauvegarderSnapshotJournalier(widget.compteId);

      // Initialiser les métadonnées si elles n'existent pas
      final metaDoc = await _firebaseService.firestore
          .collection('meta_investissement')
          .doc(widget.compteId)
          .get();

      if (!metaDoc.exists) {
        final stats = _investissementService.getStats();
        await _firebaseService.firestore
            .collection('meta_investissement')
            .doc(widget.compteId)
            .set({
          'requestsToday': stats['requestsToday'] ?? 0,
          'lastUpdate': DateTime.now().toIso8601String(),
          'prochaineMaj':
              DateTime.now().add(Duration(minutes: 10)).toIso8601String(),
          'pendingSymbols': stats['pendingSymbols'] ?? 0,
        });
      }

      setState(() {
        _compte = compte;
        _actions = actions;
        _performanceCompte = performance;

        // NOUVEAU : Sauvegarder les données du graphique dans l'état
        _transactionsPourGraphique = transactions;
        _historiquePrixPourGraphique = historiques;

        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement données: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkPremiereOuverture() async {
    if (_actions.isEmpty && (_compte?.pretAPlacer ?? 0) == 0) {
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) _showPopupPremiereOuverture();
    }
  }

  void _showPopupPremiereOuverture() {
    List<Map<String, dynamic>> actionsInit = [];
    final symbolController = TextEditingController();
    final quantiteController = TextEditingController();
    final prixController = TextEditingController();
    final cashController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Possédez-vous déjà des actions ?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ajoutez vos actions actuelles et le cash disponible.'),
                  SizedBox(height: 12),
                  ...actionsInit.map((a) => ListTile(
                        title: Text('${a['symbol']}'),
                        subtitle: Text(
                            'Quantité: ${a['quantite']} | Prix moyen: ${a['prix']}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() => actionsInit.remove(a));
                          },
                        ),
                      )),
                  Divider(),
                  TextField(
                    controller: symbolController,
                    decoration: InputDecoration(labelText: 'Symbole'),
                  ),
                  TextField(
                    controller: quantiteController,
                    decoration: InputDecoration(labelText: 'Quantité'),
                    readOnly: true,
                    onTap: () =>
                        _openNumericKeyboard(quantiteController, isMoney: true),
                  ),
                  TextField(
                    controller: prixController,
                    decoration: InputDecoration(labelText: 'Prix moyen (\$)'),
                    readOnly: true,
                    onTap: () =>
                        _openNumericKeyboard(prixController, isMoney: true),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final symbol = symbolController.text.trim().toUpperCase();
                      final quantite = double.tryParse(quantiteController.text
                              .replaceAll('\$', '')
                              .replaceAll(' ', '')
                              .replaceAll(',', '.')) ??
                          0;
                      final prix = double.tryParse(prixController.text
                              .replaceAll('\$', '')
                              .replaceAll(' ', '')
                              .replaceAll(',', '.')) ??
                          0;
                      if (symbol.isNotEmpty && quantite > 0 && prix > 0) {
                        setState(() {
                          actionsInit.add({
                            'symbol': symbol,
                            'quantite': quantite,
                            'prix': prix,
                          });
                          symbolController.clear();
                          quantiteController.clear();
                          prixController.clear();
                        });
                      }
                    },
                    child: Text('Ajouter action'),
                  ),
                  Divider(),
                  TextField(
                    controller: cashController,
                    decoration: InputDecoration(
                        labelText: 'Cash disponible initial (\$)'),
                    readOnly: true,
                    onTap: () =>
                        _openNumericKeyboard(cashController, isMoney: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Ignorer'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Créditer le cash saisi uniquement
                  final cashSaisi = double.tryParse(cashController.text
                          .replaceAll('\$', '')
                          .replaceAll(' ', '')
                          .replaceAll(',', '.')) ??
                      0;
                  if (cashSaisi > 0) {
                    await _firebaseService.firestore
                        .collection('comptes')
                        .doc(widget.compteId)
                        .update({'pretAPlacer': cashSaisi});
                  }
                  // Ajouter les actions directement (sans transaction d'achat)
                  for (final a in actionsInit) {
                    await _firebaseService.firestore.collection('actions').add({
                      'compteId': widget.compteId,
                      'symbol': a['symbol'],
                      'quantite': a['quantite'],
                      'prixAchat': a['prix'],
                      'dateAchat': DateTime.now().toIso8601String(),
                      'dateCreation': DateTime.now().toIso8601String(),
                    });
                  }
                  // Forcer la mise à jour pour TOUTES les nouvelles actions en une seule fois
                  if (actionsInit.isNotEmpty) {
                    await _investissementService.forcerMiseAJour();
                  }
                  Navigator.pop(context);
                  _chargerDonnees();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Portefeuille initialisé !')),
                  );
                },
                child: Text('Valider'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _ajouterAction() async {
    final symbolController = TextEditingController();
    final quantiteController = TextEditingController();
    final prixController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolController,
              decoration: InputDecoration(
                labelText: 'Symbole (ex: AAPL, RY.TO)',
                hintText: 'AAPL',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: quantiteController,
              decoration: InputDecoration(
                labelText: 'Quantité',
                hintText: '10',
              ),
              readOnly: true,
              onTap: () =>
                  _openNumericKeyboard(quantiteController, isMoney: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: prixController,
              decoration: InputDecoration(
                labelText: 'Prix d\'achat (\$)',
                hintText: '150.00',
              ),
              readOnly: true,
              onTap: () => _openNumericKeyboard(prixController, isMoney: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final symbol = symbolController.text.trim().toUpperCase();
                final quantite = double.tryParse(quantiteController.text
                        .replaceAll('\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')) ??
                    0;
                final prix = double.tryParse(prixController.text
                        .replaceAll('\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')) ??
                    0;

                if (symbol.isEmpty || quantite <= 0 || prix <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Veuillez remplir tous les champs correctement')),
                  );
                  return;
                }

                await _investissementService.ajouterAction(
                  compteId: widget.compteId,
                  symbol: symbol,
                  quantite: quantite,
                  prixAchat: prix,
                  dateAchat: DateTime.now(),
                );

                Navigator.pop(context);
                _chargerDonnees();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action $symbol ajoutée avec succès')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimerAction(
      String actionId, String symbol, double quantitePossedee) async {
    final prixController = TextEditingController();
    final quantiteController =
        TextEditingController(text: quantitePossedee.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vendre $symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quantité possédée: $quantitePossedee'),
            SizedBox(height: 16),
            TextField(
              controller: quantiteController,
              decoration: InputDecoration(
                labelText: 'Quantité à vendre',
                hintText: quantitePossedee.toString(),
              ),
              readOnly: true,
              onTap: () =>
                  _openNumericKeyboard(quantiteController, isMoney: true),
            ),
            SizedBox(height: 16),
            TextField(
              controller: prixController,
              decoration: InputDecoration(
                labelText: 'Prix de vente (\$)',
                hintText: '150.00',
              ),
              readOnly: true,
              onTap: () => _openNumericKeyboard(prixController, isMoney: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final prix = double.tryParse(prixController.text
                        .replaceAll('\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')) ??
                    0;
                final quantiteAVendre = double.tryParse(quantiteController.text
                        .replaceAll('\$', '')
                        .replaceAll(' ', '')
                        .replaceAll(',', '.')) ??
                    0;

                if (prix <= 0 || quantiteAVendre <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Veuillez entrer un prix et une quantité valides')),
                  );
                  return;
                }
                if (quantiteAVendre > quantitePossedee) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Vous ne pouvez pas vendre plus que la quantité possédée')),
                  );
                  return;
                }

                await _investissementService.supprimerAction(
                  actionId: actionId,
                  compteId: widget.compteId,
                  quantite: quantiteAVendre,
                  prixVente: prix,
                  dateVente: DateTime.now(),
                  quantiteRestante: quantitePossedee - quantiteAVendre,
                );

                Navigator.pop(context);
                _chargerDonnees();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action $symbol vendue avec succès')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            child: Text('Vendre'),
          ),
        ],
      ),
    );
  }

  Future<void> _forcerMiseAJour() async {
    try {
      await _investissementService.forcerMiseAJour();

      // Mettre à jour les métadonnées dans Firestore
      final stats = _investissementService.getStats();
      await _firebaseService.firestore
          .collection('meta_investissement')
          .doc(widget.compteId)
          .set({
        'requestsToday': stats['requestsToday'] ?? 0,
        'lastUpdate': DateTime.now().toIso8601String(),
        'prochaineMaj':
            DateTime.now().add(Duration(minutes: 10)).toIso8601String(),
      }, SetOptions(merge: true));

      _chargerDonnees();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour forcée effectuée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur mise à jour: $e')),
      );
    }
  }

  Future<void> _ajouterDividende() async {
    final montantController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedSymbol;
    final actions = _actions;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter un dividende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedSymbol,
              items: actions
                  .map<DropdownMenuItem<String>>(
                      (a) => DropdownMenuItem<String>(
                            value: a['symbol'] as String,
                            child: Text(a['symbol'] as String),
                          ))
                  .toList(),
              onChanged: (val) => selectedSymbol = val,
              decoration: InputDecoration(labelText: 'Symbole'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: montantController,
              decoration: InputDecoration(labelText: 'Montant reçu (\$)'),
              readOnly: true,
              onTap: () =>
                  _openNumericKeyboard(montantController, isMoney: true),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Text('Date : '),
                Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                      (context as Element).markNeedsBuild();
                    }
                  },
                  child: Text('Changer'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(montantController.text
                      .replaceAll('\$', '')
                      .replaceAll(' ', '')
                      .replaceAll(',', '.')) ??
                  0.0;
              if (selectedSymbol == null || montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Veuillez remplir tous les champs')),
                );
                return;
              }
              // Créer une transaction de dividende
              await _investissementService.ajouterDividende(
                compteId: widget.compteId,
                symbol: selectedSymbol!,
                montant: montant,
                date: selectedDate,
              );
              Navigator.pop(context);
              _chargerDonnees();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Dividende ajouté au cash disponible')),
              );
            },
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final stats = _investissementService.getStats();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Globale',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valeur investie'),
                    Text(
                      '\$${_performanceCompte['totalValeurAchat']?.toStringAsFixed(2) ?? '0.00'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Valeur actuelle'),
                    Text(
                      '\$${_performanceCompte['totalValeurActuelle']?.toStringAsFixed(2) ?? '0.00'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gain/Perte'),
                    Text(
                      '\$${_performanceCompte['totalGainPerte']?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        color: (_performanceCompte['totalGainPerte'] ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Performance'),
                    Text(
                      '${_performanceCompte['performanceGlobale']?.toStringAsFixed(2) ?? '0.00'}%',
                      style: TextStyle(
                        color:
                            (_performanceCompte['performanceGlobale'] ?? 0) >= 0
                                ? Colors.green
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actions: ${_performanceCompte['nombreActions'] ?? 0}'),
                Text(
                    'Avec prix: ${_performanceCompte['actionsAvecPrix'] ?? 0}'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('meta_investissement')
                      .doc(widget.compteId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final requestsToday =
                        snapshot.hasData && snapshot.data!.exists
                            ? (snapshot.data!.data()?['requestsToday'] ?? 0)
                            : (stats['requestsToday'] ?? 0);
                    return Text('Requêtes aujourd\'hui: $requestsToday/500');
                  },
                ),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('meta_investissement')
                      .doc(widget.compteId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return CompteAReboursProchaineMAJ(
                          investissementService: _investissementService);
                    }
                    final data = snapshot.data!.data()!;
                    final prochaineMaj = data['prochaineMaj'] != null
                        ? DateTime.tryParse(data['prochaineMaj'])
                        : null;
                    if (prochaineMaj == null) {
                      return CompteAReboursProchaineMAJ(
                          investissementService: _investissementService);
                    }
                    final now = DateTime.now();
                    final difference = prochaineMaj.difference(now);
                    if (difference.isNegative) {
                      return Text('Prochaine MAJ: Imminente');
                    }
                    final minutes = difference.inMinutes;
                    final seconds = difference.inSeconds % 60;
                    return Text('Prochaine MAJ: ${minutes}m ${seconds}s');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Fonction helper pour le cas où il n'y a pas d'historique
  Widget _buildGraphiqueAvecValeurActuelle() {
    final valeurActionsActuelle =
        _performanceCompte['totalValeurActuelle'] ?? 0.0;
    final cashDisponible = _compte?.pretAPlacer ?? 0.0;
    final valeurTotalePortefeuille = valeurActionsActuelle + cashDisponible;

    if (valeurTotalePortefeuille == 0.0) {
      return const SizedBox.shrink();
    }

    final List<FlSpot> spots = List.generate(
        30, (i) => FlSpot(i.toDouble(), valeurTotalePortefeuille));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution du portefeuille',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200, // Augmenter la hauteur pour les axes
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 500,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _getInterval(spots),
                        reservedSize: 60,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false, // Ligne droite pour le graphique plat
                      color: Colors.greenAccent,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.greenAccent.withOpacity(0.2),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            'Valeur actuelle\n${spot.y.toStringAsFixed(2)} \$',
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction helper pour calculer l'intervalle des axes Y
  double _getInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1000;

    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    if (range <= 0) return 1000;

    // Calculer un intervalle approprié
    if (range <= 100) return 50;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    if (range <= 5000) return 500;
    if (range <= 10000) return 1000;
    return 2000;
  }

  Widget _buildSoldeGraphique() {
    // On utilise un FutureBuilder pour lire l'historique sauvegardé dans Firestore
    return FutureBuilder<QuerySnapshot>(
      future: _firebaseService.firestore
          .collection('historique_portefeuille')
          .where('compteId', isEqualTo: widget.compteId)
          .orderBy('date',
              descending:
                  false) // Ordre chronologique croissant (plus ancien en premier)
          .limit(30)
          .get(),
      builder: (context, snapshot) {
        // Pendant le chargement de l'historique...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 200, // Hauteur fixe pour éviter les sauts d'interface
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // S'il n'y a pas d'historique du tout (ex: premier jour d'utilisation)
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // On affiche le graphique "plat" avec la valeur actuelle
          return _buildGraphiqueAvecValeurActuelle();
        }

        // On a un historique ! On prépare les points pour le graphique.
        final docs = snapshot.data!.docs
            .toList(); // Ordre chronologique (plus ancien à gauche, plus récent à droite)

        final List<FlSpot> spots = [];
        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          spots.add(FlSpot(i.toDouble(), (data['valeur'] as num).toDouble()));
        }

        // Le dernier point du graphique doit TOUJOURS être la valeur "live"
        final valeurActuelle = _performanceCompte['totalValeurActuelle'] ?? 0.0;
        final cash = _compte?.pretAPlacer ?? 0.0;
        final valeurTotaleAujourdhui = valeurActuelle + cash;

        // On vérifie que la date du dernier snapshot correspond à aujourd'hui avant de remplacer.
        final aujourdhuiKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (spots.isNotEmpty &&
            (docs.last.data() as Map<String, dynamic>)['date'] ==
                aujourdhuiKey) {
          spots[spots.length - 1] =
              FlSpot((spots.length - 1).toDouble(), valeurTotaleAujourdhui);
        }

        // CORRECTION : Si on n'a qu'un seul point, on en ajoute un deuxième pour créer une ligne visible
        if (spots.length == 1) {
          spots.add(FlSpot(1.0, spots[0].y)); // Même valeur, point suivant
        }

        // On retourne la carte finale avec le graphique
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Évolution du portefeuille',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200, // Augmenter la hauteur pour les axes
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval:
                            500, // Intervalle pour les lignes horizontales
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1, // Afficher toutes les dates
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() < docs.length) {
                                final data = docs[value.toInt()].data()
                                    as Map<String, dynamic>;
                                final dateStr = data['date'] as String;
                                // Afficher seulement le jour et le mois
                                final date = DateTime.parse(dateStr);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${date.day}/${date.month}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _getInterval(spots),
                            reservedSize: 60,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: spots.length >
                              2, // Désactiver la courbe si moins de 3 points
                          color: Colors.greenAccent,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: spots.length <=
                                2, // Afficher les points si peu de données
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.greenAccent,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.greenAccent.withOpacity(0.2),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              String dateStr = '';
                              if (index < docs.length) {
                                final data =
                                    docs[index].data() as Map<String, dynamic>;
                                dateStr = data['date'] as String;
                              }
                              return LineTooltipItem(
                                '${dateStr}\n${spot.y.toStringAsFixed(2)} \$',
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashDisponible() {
    final cash = _compte?.pretAPlacer ?? 0.0;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cash disponible',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              '\$${cash.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cash >= 0 ? Colors.green : Colors.red,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    final symbol = action['symbol'] as String;
    final quantite = (action['quantite'] as num).toDouble();
    final prixAchat = (action['prixAchat'] as num).toDouble();
    final actionId = action['id'] as String;

    return FutureBuilder<Map<String, dynamic>>(
      future: _investissementService.calculerPerformanceAction(
          symbol, quantite, prixAchat),
      builder: (context, snapshot) {
        final performance = snapshot.data ?? {};
        final prixActuel = performance['prixActuel'];
        final valeurActuelle = performance['valeurActuelle'] ?? 0.0;
        final gainPerte = performance['gainPerte'] ?? 0.0;
        final performancePercent = performance['performance'] ?? 0.0;
        final prixDisponible = performance['prixDisponible'] ?? false;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Row(
              children: [
                Text(
                  symbol,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                if (!prixDisponible)
                  Icon(Icons.warning, color: Colors.orange, size: 16),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quantité: $quantite'),
                if (prixDisponible) ...[
                  Text(
                      'Prix actuel: \$${prixActuel?.toStringAsFixed(2) ?? 'N/A'}'),
                  Text('Prix moyen: \$${prixAchat.toStringAsFixed(2)}'),
                ] else ...[
                  Text('Prix non disponible',
                      style: TextStyle(color: Colors.orange)),
                ],
              ],
            ),
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 100,
                maxWidth: 120,
                maxHeight: 70,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    '\$${valeurActuelle.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '\$${gainPerte.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: gainPerte >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Perf: ${performancePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color:
                          performancePercent >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            onLongPress: () => _supprimerAction(actionId, symbol, quantite),
          ),
        );
      },
    );
  }

  // Ajout de la fonction utilitaire pour ouvrir le clavier numérique personnalisé
  Future<void> _openNumericKeyboard(TextEditingController controller,
      {bool isMoney = false, bool showDecimal = true}) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => NumericKeyboard(
        controller: controller,
        isMoney: isMoney,
        showDecimal: showDecimal,
        showDone: true,
        onDone: () {
          Navigator.of(context).pop();
        },
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Investissement'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Ajouter un dividende',
            onPressed: _ajouterDividende,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _forcerMiseAJour,
            tooltip: 'Forcer mise à jour',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPerformanceCard(),
                        _buildSoldeGraphique(),
                        _buildCashDisponible(),
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text('Mes actions',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (_actions.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.trending_up,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Aucune action',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                SizedBox(height: 8),
                                Text(
                                    'Ajoutez votre première action en appuyant sur le bouton +',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        else
                          ...(_actions
                              .map((action) => _buildActionCard(action))
                              .toList()),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterAction,
        tooltip: 'Ajouter une action',
        child: Icon(Icons.add),
      ),
    );
  }
}
