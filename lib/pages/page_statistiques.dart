import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/theme_service.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/transaction_model.dart' as app_model;
import '../widgets/pie_chart_with_legend.dart';
import '../widgets/month_picker.dart';

/// Page d'affichage des statistiques financières
class PageStatistiques extends StatefulWidget {
  const PageStatistiques({super.key});

  @override
  State<PageStatistiques> createState() => _PageStatistiquesState();
}

class _PageStatistiquesState extends State<PageStatistiques>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  // Données de statistiques
  List<Compte> _comptes = [];
  List<Categorie> _categories = [];
  List<app_model.Transaction> _transactions = [];
  Map<String, double> _depensesParCategorie = {};
  Map<String, double> _revenusParSource = {};
  Map<String, double> _evolutionSoldes = {};
  Map<String, double> _utilisationEnveloppes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    // Charger les données
    final firebaseService = FirebaseService();

    // Écouter les comptes
    firebaseService.lireComptes().listen((comptes) {
      setState(() => _comptes = comptes);
    });

    // Écouter les catégories
    firebaseService.lireCategories().listen((categories) {
      setState(() => _categories = categories);
    });

    // Charger les transactions du mois sélectionné
    await _chargerTransactionsDuMois();

    setState(() => _isLoading = false);
  }

  Future<void> _chargerTransactionsDuMois() async {
    final firebaseService = FirebaseService();
    final debutMois = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final finMois = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    // Charger toutes les transactions et filtrer par mois
    _comptes.forEach((compte) async {
      firebaseService.lireTransactions(compte.id).listen((transactions) {
        final transactionsDuMois = transactions
            .where(
              (t) =>
                  t.date.isAfter(debutMois.subtract(const Duration(days: 1))) &&
                  t.date.isBefore(finMois.add(const Duration(days: 1))),
            )
            .toList();

        setState(() {
          _transactions.addAll(transactionsDuMois);
          _calculerStatistiques();
        });
      });
    });
  }

  void _calculerStatistiques() {
    _depensesParCategorie.clear();
    _revenusParSource.clear();
    _evolutionSoldes.clear();
    _utilisationEnveloppes.clear();

    // Calculer les dépenses par catégorie
    for (var transaction in _transactions) {
      if (transaction.type == app_model.TypeTransaction.depense) {
        final categorie = _trouverCategorieParEnveloppe(
          transaction.enveloppeId,
        );
        if (categorie != null) {
          _depensesParCategorie[categorie.nom] =
              (_depensesParCategorie[categorie.nom] ?? 0) + transaction.montant;
        }
      } else {
        // Revenus par source
        final source = transaction.tiers ?? 'Autre';
        _revenusParSource[source] =
            (_revenusParSource[source] ?? 0) + transaction.montant;
      }
    }

    // Calculer l'évolution des soldes
    for (var compte in _comptes) {
      _evolutionSoldes[compte.nom] = compte.solde;
    }

    // Calculer l'utilisation des enveloppes
    for (var categorie in _categories) {
      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.objectif > 0) {
          final pourcentage = (enveloppe.solde / enveloppe.objectif) * 100;
          _utilisationEnveloppes[enveloppe.nom] = pourcentage;
        }
      }
    }
  }

  Categorie? _trouverCategorieParEnveloppe(String? enveloppeId) {
    if (enveloppeId == null) return null;

    for (var categorie in _categories) {
      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.id == enveloppeId) {
          return categorie;
        }
      }
    }
    return null;
  }

  double get _totalDepenses =>
      _depensesParCategorie.values.fold(0.0, (sum, value) => sum + value);
  double get _totalRevenus =>
      _revenusParSource.values.fold(0.0, (sum, value) => sum + value);
  double get _soldeNet => _totalRevenus - _totalDepenses;
  double get _totalSoldes =>
      _comptes.fold(0.0, (sum, compte) => sum + compte.solde);
  double get _totalPretAPlacer =>
      _comptes.fold(0.0, (sum, compte) => sum + compte.pretAPlacer);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectionnerMois(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue d\'ensemble'),
            Tab(text: 'Dépenses'),
            Tab(text: 'Revenus'),
            Tab(text: 'Enveloppes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVueDensemble(),
                _buildDepenses(),
                _buildRevenus(),
                _buildEnveloppes(),
              ],
            ),
    );
  }

  Widget _buildVueDensemble() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCartesResume(),
          const SizedBox(height: 24),
          _buildGraphiqueEvolution(),
          const SizedBox(height: 24),
          _buildRepartitionComptes(),
        ],
      ),
    );
  }

  Widget _buildCartesResume() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCarteResume(
                'Revenus',
                _totalRevenus,
                Colors.green,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCarteResume(
                'Dépenses',
                _totalDepenses,
                Colors.red,
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCarteResume(
                'Solde Net',
                _soldeNet,
                _soldeNet >= 0 ? Colors.blue : Colors.orange,
                Icons.account_balance_wallet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCarteResume(
                'Total Soldes',
                _totalSoldes,
                Colors.purple,
                Icons.account_balance,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCarteResume(
    String titre,
    double montant,
    Color couleur,
    IconData icone,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: couleur, size: 20),
              const SizedBox(width: 8),
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat.currency(locale: 'fr_CA', symbol: '\$').format(montant)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphiqueEvolution() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Évolution des Soldes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _buildGraphiqueBatonnes()),
        ],
      ),
    );
  }

  Widget _buildGraphiqueBatonnes() {
    if (_evolutionSoldes.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final maxSolde = _evolutionSoldes.values.reduce((a, b) => a > b ? a : b);
    final minSolde = _evolutionSoldes.values.reduce((a, b) => a < b ? a : b);
    final range = maxSolde - minSolde;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _evolutionSoldes.length,
      itemBuilder: (context, index) {
        final compte = _evolutionSoldes.keys.elementAt(index);
        final solde = _evolutionSoldes[compte]!;
        final pourcentage = range > 0 ? (solde - minSolde) / range : 0.5;

        return Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    color: solde >= 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: pourcentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: solde >= 0
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.compact().format(solde),
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                compte.length > 8 ? '${compte.substring(0, 8)}...' : compte,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepartitionComptes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition par Comptes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._comptes.map((compte) => _buildLigneCompte(compte)),
        ],
      ),
    );
  }

  Widget _buildLigneCompte(Compte compte) {
    final pourcentage = _totalSoldes > 0
        ? (compte.solde / _totalSoldes) * 100
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(compte.couleur),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compte.nom,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${NumberFormat.currency(locale: 'fr_CA', symbol: '\$').format(compte.solde)} (${pourcentage.toStringAsFixed(1)}%)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (compte.pretAPlacer > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Prêt: ${NumberFormat.currency(locale: 'fr_CA', symbol: '\$').format(compte.pretAPlacer)}',
                style: const TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepenses() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGraphiqueDepenses(),
          const SizedBox(height: 24),
          _buildListeDepenses(),
        ],
      ),
    );
  }

  Widget _buildGraphiqueDepenses() {
    if (_depensesParCategorie.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF232526),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: const Center(child: Text('Aucune dépense ce mois-ci')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des Dépenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: PieChartWithLegend(
              contributions: _depensesParCategorie.entries.map((entry) {
                return Contribution(
                  compte: entry.key,
                  couleur: _getCouleurCategorie(entry.key),
                  montant: entry.value,
                );
              }).toList(),
              size: 200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeDepenses() {
    final depensesTriees = _depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détail par Catégorie',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...depensesTriees.map(
            (entry) => _buildLigneDepense(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneDepense(String categorie, double montant) {
    final pourcentage = _totalDepenses > 0
        ? (montant / _totalDepenses) * 100
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getCouleurCategorie(categorie),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categorie,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${NumberFormat.currency(locale: 'fr_CA', symbol: '\$').format(montant)} (${pourcentage.toStringAsFixed(1)}%)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: pourcentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getCouleurCategorie(categorie),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenus() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGraphiqueRevenus(),
          const SizedBox(height: 24),
          _buildListeRevenus(),
        ],
      ),
    );
  }

  Widget _buildGraphiqueRevenus() {
    if (_revenusParSource.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF232526),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: const Center(child: Text('Aucun revenu ce mois-ci')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sources de Revenus',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: PieChartWithLegend(
              contributions: _revenusParSource.entries.map((entry) {
                return Contribution(
                  compte: entry.key,
                  couleur: _getCouleurSource(entry.key),
                  montant: entry.value,
                );
              }).toList(),
              size: 200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeRevenus() {
    final revenusTries = _revenusParSource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détail par Source',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...revenusTries.map(
            (entry) => _buildLigneRevenu(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneRevenu(String source, double montant) {
    final pourcentage = _totalRevenus > 0 ? (montant / _totalRevenus) * 100 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getCouleurSource(source),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${NumberFormat.currency(locale: 'fr_CA', symbol: '\$').format(montant)} (${pourcentage.toStringAsFixed(1)}%)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: pourcentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getCouleurSource(source),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnveloppes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumeEnveloppes(),
          const SizedBox(height: 24),
          _buildListeEnveloppes(),
        ],
      ),
    );
  }

  Widget _buildResumeEnveloppes() {
    final enveloppesAvecObjectif = _categories
        .expand((cat) => cat.enveloppes)
        .where((env) => env.objectif > 0)
        .toList();

    final totalObjectifs = enveloppesAvecObjectif.fold(
      0.0,
      (sum, env) => sum + env.objectif,
    );
    final totalSoldes = enveloppesAvecObjectif.fold(
      0.0,
      (sum, env) => sum + env.solde,
    );
    final pourcentageGlobal = totalObjectifs > 0
        ? (totalSoldes / totalObjectifs) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Utilisation des Enveloppes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCarteResume(
                  'Total Objectifs',
                  totalObjectifs,
                  Colors.blue,
                  Icons.flag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCarteResume(
                  'Total Utilisé',
                  totalSoldes,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progression globale'),
                  Text('${pourcentageGlobal.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pourcentageGlobal / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  pourcentageGlobal > 100 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListeEnveloppes() {
    final enveloppesAvecObjectif = <MapEntry<String, double>>[];

    for (var categorie in _categories) {
      for (var enveloppe in categorie.enveloppes) {
        if (enveloppe.objectif > 0) {
          enveloppesAvecObjectif.add(
            MapEntry(
              '${categorie.nom} - ${enveloppe.nom}',
              enveloppe.solde / enveloppe.objectif * 100,
            ),
          );
        }
      }
    }

    enveloppesAvecObjectif.sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232526),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détail par Enveloppe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...enveloppesAvecObjectif.map(
            (entry) => _buildLigneEnveloppe(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneEnveloppe(String nom, double pourcentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  nom,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${pourcentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: pourcentage > 100 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pourcentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              pourcentage > 100 ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectionnerMois(BuildContext context) async {
    final mois = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int year = _selectedMonth.year;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.all(8),
              title: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          year--;
                        });
                      },
                    ),
                    Text(
                      '$year',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          year++;
                        });
                      },
                    ),
                  ],
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                child: SizedBox(
                  width: 320,
                  height: 260,
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(12, (i) {
                      final month = DateTime(year, i + 1);
                      final isSelected =
                          (month.year == _selectedMonth.year &&
                          month.month == _selectedMonth.month);
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(month);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white24,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat.MMM('fr_CA').format(month),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mois != null) {
      setState(() {
        _selectedMonth = mois;
        _transactions.clear();
      });
      await _chargerTransactionsDuMois();
    }
  }

  Color _getCouleurCategorie(String categorie) {
    final couleurs = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    final index = categorie.hashCode % couleurs.length;
    return couleurs[index];
  }

  Color _getCouleurSource(String source) {
    final couleurs = [
      Colors.green,
      Colors.blue,
      Colors.teal,
      Colors.indigo,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];

    final index = source.hashCode % couleurs.length;
    return couleurs[index];
  }
}
