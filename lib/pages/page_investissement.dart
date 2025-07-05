import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/compte.dart';
import '../models/action_investissement.dart';
import '../services/firebase_service.dart';
import '../services/investissement_service.dart';
import 'dart:async';

class PageInvestissement extends StatefulWidget {
  final Compte compte;

  const PageInvestissement({super.key, required this.compte});

  @override
  State<PageInvestissement> createState() => _PageInvestissementState();
}

class _PageInvestissementState extends State<PageInvestissement> {
  List<ActionInvestissement> _actions = [];
  double _cashDisponible = 0.0;
  double _valeurTotale = 0.0;
  double _dernierChangement = 0.0;
  bool _isLoading = true;
  List<FlSpot> _graphData = [];
  Timer? _autoUpdateTimer;

  // Performance
  double _performanceGlobale = 0.0;
  double _gainPerteTotal = 0.0;
  double _valeurInvestie = 0.0;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
    _chargerHistoriqueGraphique();
    _demarrerAutoUpdate();
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  void _demarrerAutoUpdate() {
    // Actualisation toutes les 6 minutes (360 secondes)
    _autoUpdateTimer = Timer.periodic(const Duration(minutes: 6), (timer) {
      _actualiserPrixAutomatiquement();
    });
  }

  Future<void> _actualiserPrixAutomatiquement() async {
    try {
      await InvestissementService().batchUpdatePrix(widget.compte.id);
      await _chargerDonnees();
      await _chargerHistoriqueGraphique();
    } catch (e) {
      // Erreur silencieuse pour l'auto-update
      print('Erreur auto-update: $e');
    }
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);
    try {
      final donnees =
          await InvestissementService().chargerDonneesCompte(widget.compte.id);
      final performance = await InvestissementService()
          .calculerPerformanceGlobale(widget.compte.id);

      if (mounted) {
        setState(() {
          _actions = List<ActionInvestissement>.from(donnees['actions'] ?? []);
          _cashDisponible = donnees['cash'] ?? 0.0;
          _valeurTotale = donnees['valeurTotale'] ?? 0.0;
          _dernierChangement = donnees['dernierChangement'] ?? 0.0;

          // Performance
          _performanceGlobale = performance['performancePourcentage'] ?? 0.0;
          _gainPerteTotal = performance['gainPerte'] ?? 0.0;
          _valeurInvestie = performance['valeurInvestie'] ?? 0.0;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _chargerHistoriqueGraphique() async {
    try {
      final historique =
          await InvestissementService().chargerHistorique(widget.compte.id);
      if (mounted) {
        setState(() {
          _graphData = historique.map<FlSpot>((point) {
            final x = point['x'] ?? 0.0;
            final y = point['y'] ?? 0.0;
            return FlSpot(x, y);
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _graphData = []);
      }
    }
  }

  void _ajouterTransaction() {
    print('🟢 Ajout d\'une transaction pour le compte UI: ' + widget.compte.id);
    showDialog(
      context: context,
      builder: (context) => _DialogAjoutTransaction(
        compteId: widget.compte.id,
        onTransactionAjoutee: () {
          _chargerDonnees();
          _chargerHistoriqueGraphique();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232526),
        elevation: 0,
        title: Text(widget.compte.nom),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildGraphique(),
                    _buildActionsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterTransaction,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF232526),
            const Color(0xFF414345),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Solde Total',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_valeurTotale.toStringAsFixed(2)} \$',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Performance globale
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPerformanceCard(
                'Performance',
                '${_performanceGlobale > 0 ? '+' : ''}${_performanceGlobale.toStringAsFixed(2)}%',
                _performanceGlobale > 0 ? Colors.green : Colors.red,
              ),
              _buildPerformanceCard(
                'Gain/Perte',
                '${_gainPerteTotal > 0 ? '+' : ''}${_gainPerteTotal.toStringAsFixed(2)} \$',
                _gainPerteTotal > 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
          if (_dernierChangement != 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _dernierChangement > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: _dernierChangement > 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_dernierChangement > 0 ? '+' : ''}${_dernierChangement.toStringAsFixed(2)} \$',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _dernierChangement > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(String titre, String valeur, Color couleur) {
    return Column(
      children: [
        Text(
          titre,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: couleur,
          ),
        ),
      ],
    );
  }

  Widget _buildGraphique() {
    if (_graphData.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF232526),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Aucune donnée historique disponible',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: _graphData.first.x,
          maxX: _graphData.last.x,
          minY:
              _graphData.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.95,
          maxY:
              _graphData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.05,
          lineBarsData: [
            LineChartBarData(
              spots: _graphData,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portefeuille',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          // Cash disponible
          if (_cashDisponible > 0)
            _buildActionCard(
              nom: 'Argent non placé',
              nombre: null,
              prixMoyen: null,
              valeurActuelle: _cashDisponible,
              variation: 0.0,
              isCash: true,
            ),
          // Actions
          ..._actions.map((action) {
            final performance =
                InvestissementService().calculerPerformanceAction(action);
            return _buildActionCard(
              nom: action.symbole,
              nombre: action.nombre,
              prixMoyen: action.prixMoyen,
              valeurActuelle: action.valeurActuelle,
              variation: action.variation,
              gainPerte: performance['gainPerte'],
              isCash: false,
              onTap: () => _ouvrirDetailsAction(action),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String nom,
    int? nombre,
    double? prixMoyen,
    required double valeurActuelle,
    required double variation,
    double? gainPerte,
    required bool isCash,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF232526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        onLongPress: isCash ? null : () => _confirmerSuppressionAction(nom),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (!isCash && nombre != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$nombre actions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isCash && prixMoyen != null) ...[
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Prix moy.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        '${prixMoyen.toStringAsFixed(2)} \$',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${valeurActuelle.toStringAsFixed(2)} \$',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (variation != 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            variation > 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: variation > 0 ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${variation > 0 ? '+' : ''}${variation.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: variation > 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (gainPerte != null && gainPerte != 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${gainPerte > 0 ? '+' : ''}${gainPerte.toStringAsFixed(2)} \$',
                        style: TextStyle(
                          fontSize: 10,
                          color: gainPerte > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirDetailsAction(ActionInvestissement action) {
    // TODO: Implémenter la page de détails de l'action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Détails de ${action.symbole} - À implémenter')),
    );
  }

  void _confirmerSuppressionAction(String symbole) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232526),
        title: const Text('Supprimer l\'action',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Voulez-vous vraiment supprimer l\'action "$symbole" et toutes ses transactions ?',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await InvestissementService().supprimerAction(widget.compte.id, symbole);
      await _chargerDonnees();
      await _chargerHistoriqueGraphique();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Action "$symbole" supprimée'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _DialogAjoutTransaction extends StatefulWidget {
  final String compteId;
  final VoidCallback onTransactionAjoutee;

  const _DialogAjoutTransaction({
    required this.compteId,
    required this.onTransactionAjoutee,
  });

  @override
  State<_DialogAjoutTransaction> createState() =>
      _DialogAjoutTransactionState();
}

class _DialogAjoutTransactionState extends State<_DialogAjoutTransaction> {
  final _formKey = GlobalKey<FormState>();
  final _symboleController = TextEditingController();
  final _nombreController = TextEditingController();
  final _prixController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _symboleController.dispose();
    _nombreController.dispose();
    _prixController.dispose();
    super.dispose();
  }

  Future<void> _ajouterTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final symbole = _symboleController.text.toUpperCase();
      final nombre = int.parse(_nombreController.text);
      final prix = double.parse(_prixController.text);

      await InvestissementService().ajouterTransaction(
        symbole: symbole,
        nombre: nombre,
        prix: prix,
        compteId: widget.compteId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTransactionAjoutee();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction ajoutée avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF232526),
      title: const Text(
        'Nouvelle Transaction',
        style: TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _symboleController,
              decoration: const InputDecoration(
                labelText: 'Symbole (ex: VFV)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un symbole';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre d\'actions',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nombre';
                }
                if (int.tryParse(value) == null) {
                  return 'Veuillez entrer un nombre valide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prixController,
              decoration: const InputDecoration(
                labelText: 'Prix par action (\$)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le prix';
                }
                if (double.tryParse(value) == null) {
                  return 'Veuillez entrer un prix valide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _ajouterTransaction,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}
