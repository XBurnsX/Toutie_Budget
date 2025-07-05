import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/transaction_model.dart' as app_model;
import '../services/cache_service.dart';

class PageStatistiques extends StatefulWidget {
  const PageStatistiques({super.key});

  @override
  State<PageStatistiques> createState() => _PageStatistiquesState();
}

class _PageStatistiquesState extends State<PageStatistiques> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  // Données statistiques
  List<MapEntry<String, double>> _topEnveloppes = [];
  List<MapEntry<String, double>> _topTiers = [];
  double _totalRevenus = 0.0;
  double _totalDepenses = 0.0;

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    setState(() {
      _isLoading = true;
    });

    final firebaseService = FirebaseService();

    // Utiliser le cache pour les comptes et catégories
    final comptes = await CacheService.getComptes(firebaseService);
    final categories = await CacheService.getCategories(firebaseService);

    final debutMois = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final finMois = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    Map<String, double> enveloppesUtilisation = {};
    Map<String, double> tiersUtilisation = {};
    double revenus = 0.0;
    double depenses = 0.0;

    // Parcourir toutes les transactions du mois
    for (var compte in comptes) {
      // Utiliser le cache pour les transactions
      final transactions =
          await CacheService.getTransactions(firebaseService, compte.id);

      for (var transaction in transactions) {
        if (transaction.date.isAfter(
              debutMois.subtract(const Duration(days: 1)),
            ) &&
            transaction.date.isBefore(finMois.add(const Duration(days: 1)))) {
          if (transaction.type == app_model.TypeTransaction.depense) {
            depenses += transaction.montant;

            // Trouver le nom de l'enveloppe pour les statistiques
            String enveloppeNom = 'Enveloppe inconnue';
            for (var categorie in categories) {
              for (var enveloppe in categorie.enveloppes) {
                if (enveloppe.id == transaction.enveloppeId) {
                  enveloppeNom = enveloppe.nom;
                  break;
                }
              }
            }

            enveloppesUtilisation[enveloppeNom] =
                (enveloppesUtilisation[enveloppeNom] ?? 0) +
                    transaction.montant;

            // Statistiques des tiers
            if (transaction.tiers != null && transaction.tiers!.isNotEmpty) {
              tiersUtilisation[transaction.tiers!] =
                  (tiersUtilisation[transaction.tiers!] ?? 0) +
                      transaction.montant;
            }
          } else {
            revenus += transaction.montant;
          }
        }
      }
    }

    // Trier et prendre le top 10
    final sortedEnveloppes = enveloppesUtilisation.entries
        .where((entry) => entry.key != 'Enveloppe inconnue')
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedTiers = tiersUtilisation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topEnveloppes = sortedEnveloppes.take(10).toList();
      _topTiers = sortedTiers.take(10).toList();
      _totalRevenus = revenus;
      _totalDepenses = depenses;
      _isLoading = false;
    });
  }

  Future<void> _selectionnerMois() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      _chargerStatistiques();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildStatistiquesContent(context);
  }

  Widget _buildStatistiquesContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Statistiques - ${DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth)}'),
        backgroundColor: const Color(0xFF18191A), // Couleur fixe
        foregroundColor: Colors.white, // Forcer la couleur du texte
        elevation: 0,
        surfaceTintColor:
            const Color(0xFF18191A), // Forcer la couleur de surface
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectionnerMois,
            tooltip: 'Choisir le mois',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerStatistiques,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de mois stylé
                    _buildSelecteurMois(),
                    const SizedBox(height: 24),

                    // Top 5 des enveloppes et tiers
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTopEnveloppes()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTopTiers()),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Revenus et Dépenses
                    _buildRevenusDepenses(),
                    const SizedBox(height: 32),

                    // Solde net et évolution
                    _buildSoldeNet(),
                    const SizedBox(height: 32),

                    // Graphique simple
                    _buildGraphiqueSimple(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSelecteurMois() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _selectionnerMois,
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Changer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEnveloppes() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top 5 Enveloppes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._topEnveloppes.map(
              (entry) =>
                  _buildTopItem(entry.key, entry.value, Icons.folder_special),
            ),
            if (_topEnveloppes.isEmpty)
              const Text(
                'Aucune dépense ce mois-ci',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTiers() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top 5 Tiers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._topTiers.map(
              (entry) => _buildTopItem(entry.key, entry.value, Icons.store),
            ),
            if (_topTiers.isEmpty)
              const Text(
                'Aucun tiers ce mois-ci',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItem(String nom, double montant, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)} \$',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenusDepenses() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: Theme.of(context).cardTheme.elevation ?? 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 40, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    'Revenus',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalRevenus.toStringAsFixed(2)} \$',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: Theme.of(context).cardTheme.elevation ?? 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.trending_down, size: 40, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Dépenses',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalDepenses.toStringAsFixed(2)} \$',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoldeNet() {
    final soldeNet = _totalRevenus - _totalDepenses;
    final isPositif = soldeNet >= 0;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: Theme.of(context).cardTheme.elevation ?? 2,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                isPositif ? Icons.account_balance : Icons.warning,
                size: 40,
                color: isPositif ? Colors.blue : Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                'Solde Net du Mois',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${soldeNet.toStringAsFixed(2)} \$',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isPositif
                    ? 'Félicitations ! Vous épargnez'
                    : 'Attention ! Déficit ce mois-ci',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphiqueSimple() {
    if (_totalRevenus == 0 && _totalDepenses == 0) {
      return const SizedBox.shrink();
    }

    final total = _totalRevenus + _totalDepenses;
    final pourcentageRevenus = _totalRevenus / total;

    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition Revenus/Dépenses',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Barre de progression
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade200,
              ),
              child: Row(
                children: [
                  if (pourcentageRevenus > 0)
                    Expanded(
                      flex: (_totalRevenus * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.horizontal(
                            left: const Radius.circular(10),
                            right: pourcentageRevenus >= 1
                                ? const Radius.circular(10)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                  if (_totalDepenses > 0)
                    Expanded(
                      flex: (_totalDepenses * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.horizontal(
                            left: pourcentageRevenus <= 0
                                ? const Radius.circular(10)
                                : Radius.zero,
                            right: const Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Légende
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Revenus (${(pourcentageRevenus * 100).toStringAsFixed(1)}%)',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dépenses (${((1 - pourcentageRevenus) * 100).toStringAsFixed(1)}%)',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PageStatistiquesWeb extends StatefulWidget {
  const PageStatistiquesWeb({super.key});

  @override
  State<PageStatistiquesWeb> createState() => _PageStatistiquesWebState();
}

class _PageStatistiquesWebState extends State<PageStatistiquesWeb> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  // Données statistiques
  List<MapEntry<String, double>> _topEnveloppes = [];
  List<MapEntry<String, double>> _topTiers = [];
  double _totalRevenus = 0.0;
  double _totalDepenses = 0.0;

  @override
  void initState() {
    super.initState();
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    setState(() => _isLoading = true);

    final firebaseService = FirebaseService();
    final debutMois = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final finMois = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    // Utiliser le cache pour les comptes et catégories
    final comptes = await CacheService.getComptes(firebaseService);
    final categories = await CacheService.getCategories(firebaseService);

    // Statistiques des enveloppes et tiers
    Map<String, double> enveloppesUtilisation = {};
    Map<String, double> tiersUtilisation = {};
    double revenus = 0.0;
    double depenses = 0.0;

    // Parcourir toutes les transactions du mois
    for (var compte in comptes) {
      // Utiliser le cache pour les transactions
      final transactions =
          await CacheService.getTransactions(firebaseService, compte.id);

      for (var transaction in transactions) {
        if (transaction.date.isAfter(
              debutMois.subtract(const Duration(days: 1)),
            ) &&
            transaction.date.isBefore(finMois.add(const Duration(days: 1)))) {
          if (transaction.type == app_model.TypeTransaction.depense) {
            depenses += transaction.montant;

            // Trouver le nom de l'enveloppe pour les statistiques
            String enveloppeNom = 'Enveloppe inconnue';
            for (var categorie in categories) {
              for (var enveloppe in categorie.enveloppes) {
                if (enveloppe.id == transaction.enveloppeId) {
                  enveloppeNom = enveloppe.nom;
                  break;
                }
              }
            }

            enveloppesUtilisation[enveloppeNom] =
                (enveloppesUtilisation[enveloppeNom] ?? 0) +
                    transaction.montant;

            // Statistiques des tiers
            if (transaction.tiers != null && transaction.tiers!.isNotEmpty) {
              tiersUtilisation[transaction.tiers!] =
                  (tiersUtilisation[transaction.tiers!] ?? 0) +
                      transaction.montant;
            }
          } else {
            revenus += transaction.montant;
          }
        }
      }
    }

    // Trier et prendre le top 10
    final sortedEnveloppes = enveloppesUtilisation.entries
        .where((entry) => entry.key != 'Enveloppe inconnue')
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedTiers = tiersUtilisation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topEnveloppes = sortedEnveloppes.take(10).toList();
      _topTiers = sortedTiers.take(10).toList();
      _totalRevenus = revenus;
      _totalDepenses = depenses;
      _isLoading = false;
    });
  }

  Future<void> _selectionnerMois() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      _chargerStatistiques();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _chargerStatistiques,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur de mois stylé
                  _buildSelecteurMois(),
                  const SizedBox(height: 24),

                  // Top 10 des enveloppes et tiers
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopEnveloppes()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTopTiers()),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Revenus et Dépenses
                  _buildRevenusDepenses(),
                  const SizedBox(height: 32),

                  // Solde net et évolution
                  _buildSoldeNet(),
                  const SizedBox(height: 32),

                  // Graphique simple
                  _buildGraphiqueSimple(),
                ],
              ),
            ),
          );
  }

  Widget _buildSelecteurMois() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _selectionnerMois,
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Changer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEnveloppes() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top 10 Enveloppes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._topEnveloppes.map(
              (entry) =>
                  _buildTopItem(entry.key, entry.value, Icons.folder_special),
            ),
            if (_topEnveloppes.isEmpty)
              const Text(
                'Aucune dépense ce mois-ci',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTiers() {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top 10 Tiers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._topTiers.map(
              (entry) => _buildTopItem(entry.key, entry.value, Icons.store),
            ),
            if (_topTiers.isEmpty)
              const Text(
                'Aucun tiers ce mois-ci',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItem(String nom, double montant, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)} \$',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenusDepenses() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: Theme.of(context).cardTheme.elevation ?? 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 40, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    'Revenus',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalRevenus.toStringAsFixed(2)} \$',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: Theme.of(context).cardTheme.elevation ?? 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.trending_down, size: 40, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Dépenses',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalDepenses.toStringAsFixed(2)} \$',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoldeNet() {
    final soldeNet = _totalRevenus - _totalDepenses;
    final isPositif = soldeNet >= 0;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: Theme.of(context).cardTheme.elevation ?? 2,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                isPositif ? Icons.account_balance : Icons.warning,
                size: 40,
                color: isPositif ? Colors.blue : Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                'Solde Net du Mois',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${soldeNet.toStringAsFixed(2)} \$',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isPositif
                    ? 'Félicitations ! Vous épargnez'
                    : 'Attention ! Déficit ce mois-ci',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: isPositif ? Colors.blue : Colors.orange,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphiqueSimple() {
    if (_totalRevenus == 0 && _totalDepenses == 0) {
      return const SizedBox.shrink();
    }

    final total = _totalRevenus + _totalDepenses;
    final pourcentageRevenus = _totalRevenus / total;

    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition Revenus/Dépenses',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),

            // Barre de progression
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade200,
              ),
              child: Row(
                children: [
                  if (pourcentageRevenus > 0)
                    Expanded(
                      flex: (_totalRevenus * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.horizontal(
                            left: const Radius.circular(10),
                            right: pourcentageRevenus >= 1
                                ? const Radius.circular(10)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                  if (_totalDepenses > 0)
                    Expanded(
                      flex: (_totalDepenses * 100).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.horizontal(
                            left: pourcentageRevenus <= 0
                                ? const Radius.circular(10)
                                : Radius.zero,
                            right: const Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Légende
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Revenus (${(pourcentageRevenus * 100).toStringAsFixed(1)}%)',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dépenses (${((1 - pourcentageRevenus) * 100).toStringAsFixed(1)}%)',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
