import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Assurez-vous d'avoir le package intl dans pubspec.yaml
import 'dart:math'; // Pour les calculs financiers

// --- Classe helper pour gérer les contrôleurs de dépenses fixes ---
class DepenseFixeController {
  final TextEditingController nom;
  final TextEditingController montant;

  DepenseFixeController({String nom = '', String montant = ''})
      : this.nom = TextEditingController(text: nom),
        this.montant = TextEditingController(text: montant);

  void dispose() {
    nom.dispose();
    montant.dispose();
  }
}

// --- Le Widget principal de la page ---
class PageDetailCarteCredit extends StatefulWidget {
  // Vous passerez l'ID de la carte ou l'objet carte ici
  // final String carteId;

  const PageDetailCarteCredit({super.key /*, required this.carteId */});

  @override
  State<PageDetailCarteCredit> createState() => _PageDetailCarteCreditState();
}

class _PageDetailCarteCreditState extends State<PageDetailCarteCredit> {
  // --- ====================================================== ---
  // --- Données d'état (à remplacer par vos vraies données) ---
  // --- ====================================================== ---
  final String _nomCarte = 'Visa Desjardins';
  double _soldeActuel = 6200.0;
  // On initialise la limite à 0 pour simuler la première ouverture
  double _limiteCredit = 0.0;
  double _paiementMinimum = 0.0;
  DateTime _dateEcheance = DateTime.now();

  // --- Contrôleurs pour le calculateur ---
  final _tauxInteretController = TextEditingController(text: '19.99');
  final _paiementMensuelController = TextEditingController();
  DateTime? _dateCible;

  // --- État pour les résultats des calculs ---
  String _resultatCalculTemps = '';
  String _resultatCalculPaiement = '';
  String _fraisInteretMensuel = '';

  // --- Logique pour les dépenses fixes ---
  List<DepenseFixeController> _depensesFixesControllers = [
    DepenseFixeController()
  ];

  @override
  void initState() {
    super.initState();
    // NOTE: Dans une vraie app, vous chargeriez les données de la carte ici.
    // Pour l'exemple, on vérifie si la configuration initiale a été faite.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSetup();
    });
    _calculerFraisInteretMensuel();
  }

  @override
  void dispose() {
    _tauxInteretController.dispose();
    _paiementMensuelController.dispose();
    for (var controller in _depensesFixesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- ====================================================== ---
  // --- Logique de Configuration et Mise à Jour ---
  // --- ====================================================== ---

  void _checkInitialSetup() {
    // Simule la vérification : si la limite est à 0, on considère que c'est la 1ère ouverture.
    if (_limiteCredit == 0.0) {
      _showInitialSetupDialog();
    }
  }

  void _showInitialSetupDialog() {
    final limiteController = TextEditingController();
    final paiementMinController = TextEditingController();
    final jourPaiementController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit remplir les infos
      builder: (context) {
        return AlertDialog(
          title: Text('Configurer la carte "$_nomCarte"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: limiteController,
                  decoration:
                      const InputDecoration(labelText: 'Limite de crédit (\$)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: paiementMinController,
                  decoration: const InputDecoration(
                      labelText: 'Paiement minimum requis (\$)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: jourPaiementController,
                  decoration:
                      const InputDecoration(labelText: 'Jour du paiement (1-28)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Sauvegarder les informations
                final double limite =
                    double.tryParse(limiteController.text) ?? 0.0;
                final double paiementMin =
                    double.tryParse(paiementMinController.text) ?? 0.0;
                final int jourPaiement =
                    int.tryParse(jourPaiementController.text) ?? 1;

                if (limite > 0 && paiementMin > 0) {
                  setState(() {
                    _limiteCredit = limite;
                    _paiementMinimum = paiementMin;

                    // Calcule la prochaine date d'échéance
                    final now = DateTime.now();
                    _dateEcheance = DateTime(now.year, now.month, jourPaiement);
                    if (_dateEcheance.isBefore(now)) {
                      _dateEcheance =
                          DateTime(now.year, now.month + 1, jourPaiement);
                    }
                  });
                  Navigator.of(context).pop();
                } else {
                  // Afficher une erreur si les champs sont invalides
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Veuillez remplir tous les champs correctement.')),
                  );
                }
              },
              child: const Text('Sauvegarder'),
            )
          ],
        );
      },
    );
  }

  // NOUVELLE FONCTION: Affiche un dialogue pour mettre à jour le solde
  void _showUpdateSoldeDialog() {
    final soldeController =
        TextEditingController(text: _soldeActuel.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mettre à jour le solde'),
          content: TextField(
            controller: soldeController,
            decoration:
                const InputDecoration(labelText: 'Nouveau solde actuel (\$)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final nouveauSolde = double.tryParse(soldeController.text);
                if (nouveauSolde != null) {
                  setState(() {
                    _soldeActuel = nouveauSolde;
                    // Recalculer les frais d'intérêt basés sur le nouveau solde
                    _calculerFraisInteretMensuel();
                  });
                  // NOTE: Ici, vous appelleriez votre service pour sauvegarder
                  // le nouveau solde dans Firebase.
                  // ex: _firebaseService.updateSoldeCarte(widget.carteId, nouveauSolde);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Mettre à jour'),
            ),
          ],
        );
      },
    );
  }

  // --- ====================================================== ---
  // --- Logique de Calcul ---
  // --- ====================================================== ---

  double get _totalDepensesFixes {
    return _depensesFixesControllers.fold(0.0, (sum, controller) {
      return sum + (double.tryParse(controller.montant.text) ?? 0.0);
    });
  }

  void _ajouterDepenseFixe() {
    setState(() {
      _depensesFixesControllers.add(DepenseFixeController());
    });
  }

  void _supprimerDepenseFixe(int index) {
    setState(() {
      _depensesFixesControllers[index].dispose();
      _depensesFixesControllers.removeAt(index);
    });
  }

  void _calculerFraisInteretMensuel() {
    final double tauxAnnuel =
        double.tryParse(_tauxInteretController.text) ?? 0.0;
    if (tauxAnnuel > 0) {
      final double interet = _soldeActuel * (tauxAnnuel / 100 / 12);
      setState(() {
        _fraisInteretMensuel =
            'Frais d\'intérêt mensuels estimés: \$${interet.toStringAsFixed(2)}';
      });
    }
  }

  // Scénario 1: Calcule le temps nécessaire pour rembourser avec un paiement fixe
  void _calculerTempsRemboursement() {
    final double tauxAnnuel =
        double.tryParse(_tauxInteretController.text) ?? 0.0;
    final double tauxMensuel = tauxAnnuel / 100 / 12;
    double paiementMensuel =
        double.tryParse(_paiementMensuelController.text) ?? 0.0;
    double soldeCourant = _soldeActuel;

    // Validation
    if (paiementMensuel <= (soldeCourant * tauxMensuel) + _totalDepensesFixes) {
      setState(() {
        _resultatCalculTemps =
            'Le paiement doit être supérieur aux intérêts et aux dépenses fixes.';
      });
      return;
    }

    int mois = 0;
    while (soldeCourant > 0) {
      if (mois > 1200) {
        // Sécurité pour éviter une boucle infinie
        _resultatCalculTemps = 'Durée > 100 ans.';
        setState(() {});
        return;
      }
      double interetMois = soldeCourant * tauxMensuel;
      soldeCourant += interetMois + _totalDepensesFixes - paiementMensuel;
      mois++;
    }

    DateTime dateFin =
        DateTime.now().add(Duration(days: (mois * 30.44).round()));
    setState(() {
      _resultatCalculTemps =
          'Payé en: ${DateFormat.yMMM('fr_CA').format(dateFin)} ($mois mois)';
    });
  }

  // Scénario 2: Calcule le paiement nécessaire pour une date cible
  void _calculerPaiementRequis() {
    if (_dateCible == null) {
      setState(() {
        _resultatCalculPaiement = 'Veuillez choisir une date cible.';
      });
      return;
    }

    final double tauxAnnuel =
        double.tryParse(_tauxInteretController.text) ?? 0.0;
    final double i = tauxAnnuel / 100 / 12; // Taux d'intérêt mensuel
    final int n =
        _dateCible!.difference(DateTime.now()).inDays ~/ 30; // Nombre de mois

    if (n <= 0) {
      setState(() {
        _resultatCalculPaiement = 'La date doit être dans le futur.';
      });
      return;
    }

    double paiementEstime = _soldeActuel / n; // Estimation de base
    for (int j = 0; j < 10; j++) {
      // Répéter pour affiner
      double soldeSimule = _soldeActuel;
      for (int k = 0; k < n; k++) {
        soldeSimule += soldeSimule * i + _totalDepensesFixes - paiementEstime;
      }
      paiementEstime += soldeSimule / n;
    }

    setState(() {
      _resultatCalculPaiement =
          'Paiement mensuel requis: \$${paiementEstime.toStringAsFixed(2)}';
    });
  }

  // --- ====================================================== ---
  // --- Widgets de Construction de l'UI ---
  // --- ====================================================== ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomCarte),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumeCarte(),
            const SizedBox(height: 24),
            _buildCalculateurRemboursement(),
          ],
        ),
      ),
    );
  }

  // --- Section Résumé de la carte ---
  Widget _buildResumeCarte() {
    double creditUtilise = _soldeActuel;
    double creditDisponible = _limiteCredit - _soldeActuel;
    double utilisationPourcentage =
        _limiteCredit > 0 ? creditUtilise / _limiteCredit : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Solde actuel',
                    style: Theme.of(context).textTheme.bodyMedium),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _showUpdateSoldeDialog, // Appel de la nouvelle fonction
                  tooltip: 'Mettre à jour le solde',
                )
              ],
            ),
            Text('\$${_soldeActuel.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Barre de progression
            Text(
                'Utilisation du crédit: \$${creditUtilise.toStringAsFixed(2)} / \$${_limiteCredit.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: utilisationPourcentage,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                  utilisationPourcentage > 0.8 ? Colors.red : Colors.blue),
            ),
            const SizedBox(height: 20),

            // Infos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCarte(
                    'Crédit dispo.', '\$${creditDisponible.toStringAsFixed(2)}'),
                _buildInfoCarte(
                    'Paiement min.', '\$${_paiementMinimum.toStringAsFixed(2)}'),
                _buildInfoCarte('Prochain paiement',
                    DateFormat.yMd('fr_CA').format(_dateEcheance)),
              ],
            ),
            // Commentaire pour l'objectif d'enveloppe
            // Pour créer un objectif: utiliser la valeur `_paiementMinimum` et `_dateEcheance`
            // pour alimenter votre système d'enveloppes/objectifs.
          ],
        ),
      ),
    );
  }

  // --- Section Calculateur ---
  Widget _buildCalculateurRemboursement() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Plan de remboursement',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            // Entrées
            TextField(
              controller: _tauxInteretController,
              decoration: const InputDecoration(
                  labelText: 'Taux d\'intérêt annuel (%)',
                  border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculerFraisInteretMensuel(),
            ),
            const SizedBox(height: 8),
            if (_fraisInteretMensuel.isNotEmpty)
              Text(_fraisInteretMensuel,
                  style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: 16),
            Text('Dépenses fixes mensuelles sur la carte',
                style: Theme.of(context).textTheme.titleSmall),
            ..._buildListeDepensesFixes(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
                onPressed: _ajouterDepenseFixe,
              ),
            ),
            const Divider(height: 24),

            // Scénario 1: "Si je paie X par mois"
            _buildScenarioCard(
                titre: 'Scénario 1: Payer un montant fixe',
                contenu: Column(
                  children: [
                    TextField(
                      controller: _paiementMensuelController,
                      decoration: const InputDecoration(
                          labelText: 'Je paie ce montant par mois (\$)',
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _calculerTempsRemboursement,
                      child: const Text('Calculer la date de fin'),
                    ),
                    if (_resultatCalculTemps.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_resultatCalculTemps,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                      ),
                  ],
                )),
            const SizedBox(height: 16),

            // Scénario 2: "Payer avant une date"
            _buildScenarioCard(
                titre: 'Scénario 2: Payer avant une date cible',
                contenu: Column(
                  children: [
                    ListTile(
                      title: Text(_dateCible == null
                          ? 'Choisir une date'
                          : DateFormat.yMMM('fr_CA').format(_dateCible!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 365)),
                          firstDate:
                              DateTime.now().add(const Duration(days: 30)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateCible = pickedDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _calculerPaiementRequis,
                      child: const Text('Calculer le paiement mensuel'),
                    ),
                    if (_resultatCalculPaiement.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_resultatCalculPaiement,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                      ),
                  ],
                )),
            // NOTE: Le scénario pour atteindre un % cible serait une variation du scénario 2.
            // Il faudrait calculer le solde cible (ex: 20% de 7000$ = 1400$) et utiliser ce montant
            // comme objectif final dans la simulation au lieu de 0.
          ],
        ),
      ),
    );
  }

  // --- ====================================================== ---
  // --- Widgets Helpers ---
  // --- ====================================================== ---

  List<Widget> _buildListeDepensesFixes() {
    return List.generate(_depensesFixesControllers.length, (index) {
      final controllerPair = _depensesFixesControllers[index];
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: controllerPair.nom,
                decoration: const InputDecoration(
                    hintText: 'Nom (ex: Assurance)',
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: controllerPair.montant,
                decoration: const InputDecoration(
                    hintText: 'Montant', border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _supprimerDepenseFixe(index),
              tooltip: 'Supprimer',
            ),
          ],
        ),
      );
    });
  }

  Widget _buildInfoCarte(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildScenarioCard({required String titre, required Widget contenu}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            contenu,
          ],
        ),
      ),
    );
  }
}
