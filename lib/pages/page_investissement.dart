import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/compte.dart';
import '../models/action_investissement.dart';
import '../services/firebase_service.dart';
import '../services/investissement_service.dart';
import 'dart:async';
import '../widgets/ajout_transaction/bouton_sauvegarder.dart';
import 'package:intl/intl.dart';

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
  String _nextUpdateTime = '';
  Timer? _updateTimer;
  Compte? _compte;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
    _demarrerMiseAJourAutomatique();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _demarrerMiseAJourAutomatique() {
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _nextUpdateTime = _investissementService.getNextUpdateTime();
      });
    });
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

      // Charger la performance globale
      final performance = await _investissementService
          .calculerPerformanceCompte(widget.compteId);

      setState(() {
        _compte = compte;
        _actions = actions;
        _performanceCompte = performance;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement données: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: prixController,
              decoration: InputDecoration(
                labelText: 'Prix d\'achat (\$)',
                hintText: '150.00',
              ),
              keyboardType: TextInputType.number,
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
                final quantite = double.tryParse(quantiteController.text) ?? 0;
                final prix = double.tryParse(prixController.text) ?? 0;

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
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: prixController,
              decoration: InputDecoration(
                labelText: 'Prix de vente (\$)',
                hintText: '150.00',
              ),
              keyboardType: TextInputType.number,
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
                final prix = double.tryParse(prixController.text) ?? 0;
                final quantiteAVendre =
                    double.tryParse(quantiteController.text) ?? 0;

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
              keyboardType: TextInputType.number,
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
              final montant = double.tryParse(
                      montantController.text.replaceAll(',', '.')) ??
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
                Text(
                    'Requêtes aujourd\'hui: ${stats['requestsToday'] ?? 0}/500'),
                Text('Prochaine MAJ: $_nextUpdateTime'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoldeGraphique() {
    // Données fictives pour l'exemple (remplacer par l'historique Firestore si dispo)
    final List<double> soldeHistorique =
        List.generate(30, (i) => 900 + i * 4 + (i % 5) * 10);
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution du solde (30 jours)',
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < soldeHistorique.length; i++)
                          FlSpot(i.toDouble(), soldeHistorique[i]),
                      ],
                      isCurved: true,
                      color: Colors.greenAccent,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
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
                Text('Prix d\'achat: \$${prixAchat.toStringAsFixed(2)}'),
                if (prixDisponible) ...[
                  Text(
                      'Prix actuel: \$${prixActuel?.toStringAsFixed(2) ?? 'N/A'}'),
                  Text(
                    'Prix moyen: \$${prixAchat.toStringAsFixed(2)}',
                  ),
                ] else ...[
                  Text('Prix non disponible',
                      style: TextStyle(color: Colors.orange)),
                ],
              ],
            ),
            trailing: SizedBox(
              width: 90,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${valeurActuelle.toStringAsFixed(2)}',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    Text(
                      '\$${gainPerte.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: gainPerte >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Performance: ${performancePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color:
                            performancePercent >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onLongPress: () => _supprimerAction(actionId, symbol, quantite),
          ),
        );
      },
    );
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
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterAction,
        tooltip: 'Ajouter une action',
        child: Icon(Icons.add),
      ),
    );
  }
}
