import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toutie_budget/services/firebase_service.dart'; // Assurez-vous d'avoir le package intl dans pubspec.yaml
import 'dart:math'; // Pour les calculs financiers
import 'package:cloud_firestore/cloud_firestore.dart';
import 'page_ajout_transaction.dart';
import '../widgets/numeric_keyboard.dart';

// --- Classe helper pour gérer les contrôleurs de dépenses fixes ---
class DepenseFixeController {
  final TextEditingController nom;
  final TextEditingController montant;

  DepenseFixeController({String nom = '', String montant = ''})
      : nom = TextEditingController(text: nom),
        montant = TextEditingController(text: montant);

  void dispose() {
    nom.dispose();
    montant.dispose();
  }
}

// --- Le Widget principal de la page ---
class PageDetailCarteCredit extends StatefulWidget {
  final String? nomCarte;
  final double? soldeActuel;
  final double? limiteCredit;
  final double? paiementMinimum;
  final DateTime? dateEcheance;
  final String compteId;

  const PageDetailCarteCredit({
    super.key,
    this.nomCarte,
    this.soldeActuel,
    this.limiteCredit,
    this.paiementMinimum,
    this.dateEcheance,
    required this.compteId,
  });

  @override
  State<PageDetailCarteCredit> createState() => _PageDetailCarteCreditState();
}

class _PageDetailCarteCreditState extends State<PageDetailCarteCredit> {
  // --- ====================================================== ---
  // --- Données d'état (à remplacer par vos vraies données) ---
  // --- ====================================================== ---
  double _soldeActuel = 6200.0;
  // On initialise la limite à 0 pour simuler la première ouverture
  double _limiteCredit = 0.0;
  double _paiementMinimum = 0.0;
  DateTime _dateEcheance = DateTime.now();

  // --- Contrôleurs pour le calculateur ---
  final _tauxInteretController = TextEditingController(text: '19.99');
  final _paiementMensuelController = TextEditingController();
  final _pourcentageCibleController = TextEditingController();
  DateTime? _dateCible;

  // --- État pour les résultats des calculs ---
  String _resultatCalculTemps = '';
  String _resultatCalculPaiement = '';
  String _resultatCalculPourcentage = '';
  String _fraisInteretMensuel = '';

  // --- Logique pour les dépenses fixes ---
  List<DepenseFixeController> _depensesFixesControllers = [
    DepenseFixeController()
  ];

  // Variable pour suivre si c'est la première ouverture
  bool _isFirstTime = true;

  // Variable pour suivre s'il y a des modifications non sauvegardées
  bool _hasUnsavedChanges = false;

  // Ajout de la variable d'état pour le nom de la carte
  String _nomCarte = '';

  // Ajoute la variable d'état globale
  bool _rembourserDettesAssociees = false;

  @override
  void initState() {
    super.initState();
    _chargerDonneesCarteCredit();
    _calculerFraisInteretMensuel();
  }

  @override
  void dispose() {
    _tauxInteretController.dispose();
    _paiementMensuelController.dispose();
    _pourcentageCibleController.dispose();
    for (var controller in _depensesFixesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

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

  // --- ====================================================== ---
  // --- Logique de Configuration et Mise à Jour ---
  // --- ====================================================== ---

  void _checkInitialSetup() {
    // Vérifie si la configuration initiale a été faite
    // Si les variables d'état locales ne sont pas configurées, on affiche le dialogue
    if ((_limiteCredit == 0.0 || _paiementMinimum == 0.0) && _isFirstTime) {
      _showInitialSetupDialog();
      _isFirstTime = false; // Marquer que ce n'est plus la première fois
    }
  }

  void _showInitialSetupDialog() {
    // Utiliser directement les variables d'état locales
    final limiteController = TextEditingController(
        text: _limiteCredit > 0 ? _limiteCredit.toStringAsFixed(0) : '');
    final paiementMinController = TextEditingController(
        text: _paiementMinimum > 0 ? _paiementMinimum.toStringAsFixed(2) : '');
    final jourPaiementController = TextEditingController(
        text: _dateEcheance != null ? _dateEcheance.day.toString() : '');

    showDialog(
      context: context,
      barrierDismissible: true, // Permettre de fermer le dialogue
      builder: (context) {
        return AlertDialog(
          title: Text('Configurer ${widget.nomCarte ?? 'la carte de crédit'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configurez les paramètres de votre carte de crédit pour des calculs précis.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: limiteController,
                  decoration:
                      const InputDecoration(labelText: 'Limite de crédit (\$)'),
                  readOnly: true,
                  onTap: () =>
                      _openNumericKeyboard(limiteController, isMoney: true),
                ),
                TextField(
                  controller: paiementMinController,
                  decoration: const InputDecoration(
                      labelText: 'Paiement minimum requis (\$)'),
                  readOnly: true,
                  onTap: () => _openNumericKeyboard(paiementMinController,
                      isMoney: true),
                ),
                TextField(
                  controller: jourPaiementController,
                  decoration: const InputDecoration(
                      labelText: 'Jour du paiement (1-28)'),
                  readOnly: true,
                  onTap: () => _openNumericKeyboard(jourPaiementController,
                      showDecimal: false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Nettoyer et parser les valeurs
                final String limiteText = limiteController.text
                    .replaceAll('\$', '')
                    .replaceAll(' ', '')
                    .replaceAll(',', '.')
                    .trim();
                final String paiementMinText = paiementMinController.text
                    .replaceAll('\$', '')
                    .replaceAll(' ', '')
                    .replaceAll(',', '.')
                    .trim();
                final String jourPaiementText =
                    jourPaiementController.text.replaceAll(' ', '').trim();

                final double limite = double.tryParse(limiteText) ?? 0.0;
                final double paiementMin =
                    double.tryParse(paiementMinText) ?? 0.0;
                final int jourPaiement = int.tryParse(jourPaiementText) ?? 1;

                if (limite > 0 &&
                    paiementMin > 0 &&
                    jourPaiement >= 1 &&
                    jourPaiement <= 28) {
                  // Calcule la prochaine date d'échéance
                  final now = DateTime.now();
                  final dateEcheance =
                      DateTime(now.year, now.month, jourPaiement);
                  final dateEcheanceFinale = dateEcheance.isBefore(now)
                      ? DateTime(now.year, now.month + 1, jourPaiement)
                      : dateEcheance;

                  // Sauvegarder dans Firebase
                  try {
                    await FirebaseService().setCarteCredit(
                      widget.compteId,
                      {
                        'nom': _nomCarte,
                        'soldeActuel': _soldeActuel,
                        'limiteCredit': limite,
                        'paiementMinimum': paiementMin,
                        'dateEcheance': dateEcheanceFinale.toIso8601String(),
                        'type': 'Carte de crédit',
                        'tauxInteret':
                            double.tryParse(_tauxInteretController.text) ?? 0.0,
                        'depensesFixes': _depensesFixesControllers
                            .map((controller) => {
                                  'nom': controller.nom.text,
                                  'montant': double.tryParse(
                                          controller.montant.text) ??
                                      0.0,
                                })
                            .toList(),
                        'rembourserDettesAssociees': _rembourserDettesAssociees,
                      },
                    );
                  } catch (e) {
                    print('Erreur lors de la sauvegarde: $e');
                  }

                  setState(() {
                    // Mettre à jour les variables d'état locales
                    _limiteCredit = limite;
                    _paiementMinimum = paiementMin;
                    _dateEcheance = dateEcheanceFinale;
                  });
                  _markAsModified();

                  // Afficher un message de succès
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Configuration sauvegardée avec succès')),
                    );
                  }

                  Navigator.of(context).pop();
                } else {
                  // Afficher une erreur spécifique selon le problème
                  String messageErreur =
                      'Veuillez remplir tous les champs correctement.';

                  if (limite <= 0) {
                    messageErreur =
                        'La limite de crédit doit être supérieure à 0.';
                  } else if (paiementMin <= 0) {
                    messageErreur =
                        'Le paiement minimum doit être supérieur à 0.';
                  } else if (jourPaiement < 1 || jourPaiement > 28) {
                    messageErreur =
                        'Le jour de paiement doit être entre 1 et 28.';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(messageErreur)),
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

  // Méthode helper pour marquer qu'il y a des modifications
  void _markAsModified() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // Fonction pour sauvegarder toutes les modifications
  void _sauvegarderModifications() async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Sauvegarder dans Firebase
      await FirebaseService().setCarteCredit(
        widget.compteId,
        {
          'nom': _nomCarte,
          'soldeActuel': _soldeActuel,
          'limiteCredit': _limiteCredit,
          'paiementMinimum': _paiementMinimum,
          'dateEcheance': _dateEcheance.toIso8601String(),
          'type': 'Carte de crédit',
          'tauxInteret': double.tryParse(_tauxInteretController.text) ?? 0.0,
          'depensesFixes': _depensesFixesControllers
              .map((controller) => {
                    'nom': controller.nom.text,
                    'montant': double.tryParse(controller.montant.text) ?? 0.0,
                  })
              .toList(),
          'rembourserDettesAssociees': _rembourserDettesAssociees,
        },
      );

      // Fermer l'indicateur de chargement
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Marquer qu'il n'y a plus de modifications non sauvegardées
      setState(() {
        _hasUnsavedChanges = false;
      });

      // Afficher un message de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modifications sauvegardées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Afficher un message d'erreur
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NOUVELLE FONCTION: Affiche un dialogue pour mettre à jour le solde
  void _showUpdateSoldeDialog() {
    final soldeController =
        TextEditingController(text: _soldeActuel.toStringAsFixed(2));
    final paiementMinController =
        TextEditingController(text: _paiementMinimum.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Mettre à jour le solde'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: soldeController,
                    decoration: const InputDecoration(
                        labelText: 'Nouveau solde actuel (\$)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paiementMinController,
                    decoration: const InputDecoration(
                        labelText: 'Paiement mensuel minimum (\$)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nouveauSolde = double.tryParse(soldeController.text);
                    final nouveauPaiementMin =
                        double.tryParse(paiementMinController.text);
                    if (nouveauSolde != null) {
                      setStateDialog(() {
                        _soldeActuel = nouveauSolde;
                        if (nouveauPaiementMin != null) {
                          _paiementMinimum = nouveauPaiementMin;
                        }
                      });
                      _markAsModified();
                      // Sauvegarder le nouveau solde dans Firebase
                      try {
                        await FirebaseService().setCarteCredit(
                          widget.compteId,
                          {
                            'nom': _nomCarte,
                            'soldeActuel': nouveauSolde,
                            'type': 'Carte de crédit',
                            if (nouveauPaiementMin != null)
                              'paiementMinimum': nouveauPaiementMin,
                          },
                        );
                      } catch (e) {
                        print('Erreur lors de la sauvegarde du solde: $e');
                      }
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Mettre à jour'),
                ),
              ],
            );
          },
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
    _markAsModified();
  }

  void _supprimerDepenseFixe(int index) {
    setState(() {
      _depensesFixesControllers[index].dispose();
      _depensesFixesControllers.removeAt(index);
    });
    _markAsModified();
  }

  void _calculerFraisInteretMensuel() {
    final double tauxAnnuel =
        double.tryParse(_tauxInteretController.text) ?? 0.0;
    if (tauxAnnuel > 0) {
      final double soldeActuel = _soldeActuel;
      final double interet = soldeActuel * (tauxAnnuel / 100 / 12);
      setState(() {
        _fraisInteretMensuel =
            'Frais d\'intérêt mensuels: \$${interet.toStringAsFixed(2)}';
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

    final double S = _soldeActuel;
    final double D = _totalDepensesFixes;

    double paiementEstime;
    if (i == 0) {
      paiementEstime = (S / n) + D;
    } else {
      paiementEstime = (S * i * pow(1 + i, n)) / (pow(1 + i, n) - 1) + D;
    }

    setState(() {
      _resultatCalculPaiement =
          'Paiement mensuel requis: \$${paiementEstime.toStringAsFixed(2)}';
    });
  }

  // Scénario 3: Calcule le paiement pour atteindre un pourcentage cible
  void _calculerPaiementPourcentage() {
    final double pourcentageCible =
        double.tryParse(_pourcentageCibleController.text) ?? 0.0;
    if (pourcentageCible <= 0 || pourcentageCible >= 100) {
      setState(() {
        _resultatCalculPourcentage = 'Le pourcentage doit être entre 0 et 100.';
      });
      return;
    }

    final double limiteCredit = _limiteCredit;
    if (limiteCredit <= 0) {
      setState(() {
        _resultatCalculPourcentage = 'Veuillez configurer la limite de crédit.';
      });
      return;
    }

    final double soldeActuel = _soldeActuel;
    final double soldeCible = limiteCredit * (pourcentageCible / 100);
    final double montantARembourser = soldeActuel - soldeCible;

    if (montantARembourser <= 0) {
      setState(() {
        _resultatCalculPourcentage =
            'Le solde actuel (\$${soldeActuel.toStringAsFixed(0)}) est déjà inférieur à l\'objectif (\$${soldeCible.toStringAsFixed(0)}).';
      });
      return;
    }

    if (_dateCible == null) {
      setState(() {
        _resultatCalculPourcentage = 'Veuillez choisir une date cible.';
      });
      return;
    }

    final double tauxAnnuel =
        double.tryParse(_tauxInteretController.text) ?? 0.0;
    final double i = tauxAnnuel / 100 / 12; // Taux d'intérêt mensuel
    int n = _dateCible!.difference(DateTime.now()).inDays ~/ 30;
    if (n <= 0) {
      setState(() {
        _resultatCalculPourcentage = 'La date doit être dans le futur.';
      });
      return;
    }

    // Calcul itératif pour trouver le paiement mensuel requis
    double paiementEstime = montantARembourser / n;
    for (int j = 0; j < 10; j++) {
      double soldeSimule = soldeActuel;
      for (int k = 0; k < n; k++) {
        soldeSimule += soldeSimule * i + _totalDepensesFixes - paiementEstime;
      }
      paiementEstime += (soldeSimule - soldeCible) / n;
    }

    final String dateInfo =
        ' d\'ici ${DateFormat.yMMM('fr_CA').format(_dateCible!)}';

    setState(() {
      _resultatCalculPourcentage =
          'Pour atteindre $pourcentageCible% (\$${soldeCible.toStringAsFixed(0)})$dateInfo, '
          'paiement mensuel requis: \$${paiementEstime.toStringAsFixed(2)}';
    });
  }

  // --- ====================================================== ---
  // --- Widgets de Construction de l'UI ---
  // --- ====================================================== ---
  @override
  Widget build(BuildContext context) {
    final nomCarte = widget.nomCarte ?? 'Ma carte de crédit';
    final soldeActuel = widget.soldeActuel ?? _soldeActuel;
    // Utiliser les variables d'état locales si elles sont configurées, sinon les données du widget
    final limiteCredit = _limiteCredit;
    final paiementMinimum = _paiementMinimum > 0
        ? _paiementMinimum
        : (widget.paiementMinimum ?? 0.0);
    final dateEcheance = _limiteCredit > 0
        ? _dateEcheance
        : (widget.dateEcheance ?? DateTime.now().add(const Duration(days: 15)));

    double creditUtilise = soldeActuel;
    double creditDisponible = limiteCredit - soldeActuel;
    double utilisationPourcentage =
        limiteCredit > 0 ? creditUtilise / limiteCredit : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(nomCarte),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: _hasUnsavedChanges ? Colors.orange : null,
            ),
            tooltip: _hasUnsavedChanges
                ? 'Sauvegarder les modifications (non sauvegardées)'
                : 'Sauvegarder les modifications',
            onPressed: _sauvegarderModifications,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurer la carte',
            onPressed: _showInitialSetupDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumeCarte(
                soldeActuel,
                limiteCredit,
                paiementMinimum,
                dateEcheance,
                creditUtilise,
                creditDisponible,
                utilisationPourcentage),
            const SizedBox(height: 24),
            _buildCalculateurRemboursement(soldeActuel),
          ],
        ),
      ),
    );
  }

  // --- Section Résumé de la carte ---
  Widget _buildResumeCarte(
      double soldeActuel,
      double limiteCredit,
      double paiementMinimum,
      DateTime dateEcheance,
      double creditUtilise,
      double creditDisponible,
      double utilisationPourcentage) {
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
                  onPressed:
                      _showUpdateSoldeDialog, // Appel de la nouvelle fonction
                  tooltip: 'Mettre à jour le solde',
                )
              ],
            ),
            Text('\$${soldeActuel.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Barre de progression
            Text(
                'Utilisation du crédit: \$${creditUtilise.toStringAsFixed(2)} / \$${limiteCredit.toStringAsFixed(2)}'),
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
                _buildInfoCarte('Crédit dispo.',
                    '\$${creditDisponible.toStringAsFixed(2)}'),
                _buildInfoCarte(
                    'Paiement min.', '\$${paiementMinimum.toStringAsFixed(2)}'),
                _buildInfoCarte('Prochain paiement',
                    DateFormat.yMd('fr_CA').format(dateEcheance)),
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
  Widget _buildCalculateurRemboursement(double soldeActuel) {
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
              onChanged: (_) {
                _calculerFraisInteretMensuel();
                _markAsModified();
              },
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
            // Case à cocher juste en dessous des dépenses fixes
            CheckboxListTile(
              value: _rembourserDettesAssociees,
              onChanged: (val) {
                setState(() => _rembourserDettesAssociees = val ?? false);
              },
              title: const Text(
                  'Voulez-vous aussi rembourser vos autres dettes associées (Accord D, etc.) ?'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Payez maintenant !'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EcranAjoutTransactionRefactored(
                      comptesExistants: [_nomCarte],
                      nomTiers: _nomCarte,
                      typeRemboursement: 'remboursement_effectue',
                      montantSuggere: _paiementMinimum,
                    ),
                  ),
                );
              },
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
                      onChanged: (_) => _markAsModified(),
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
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateCible = pickedDate;
                          });
                          _markAsModified();
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
            const SizedBox(height: 16),

            // Scénario 3: "Atteindre un pourcentage cible"
            _buildScenarioCard(
                titre: 'Scénario 3: Atteindre un pourcentage d\'utilisation',
                contenu: Column(
                  children: [
                    TextField(
                      controller: _pourcentageCibleController,
                      decoration: const InputDecoration(
                          labelText: 'Pourcentage cible (ex: 20 pour 20%)',
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _markAsModified(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _calculerPaiementPourcentage,
                      child: const Text('Calculer le paiement mensuel'),
                    ),
                    if (_resultatCalculPourcentage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_resultatCalculPourcentage,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                      ),
                  ],
                )),
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
                onChanged: (_) => _markAsModified(),
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
                onChanged: (_) => _markAsModified(),
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
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.5),
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

  Future<void> _chargerDonneesCarteCredit() async {
    final doc = await FirebaseFirestore.instance
        .collection('comptes')
        .doc(widget.compteId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nomCarte = data['nom'] ?? widget.nomCarte ?? '';
        _soldeActuel = (data['soldeActuel'] as num?)?.toDouble() ?? 0.0;
        _limiteCredit = (data['limiteCredit'] as num?)?.toDouble() ?? 0.0;
        _paiementMinimum = (data['paiementMinimum'] as num?)?.toDouble() ?? 0.0;
        _dateEcheance = data['dateEcheance'] != null
            ? DateTime.tryParse(data['dateEcheance']) ?? DateTime.now()
            : DateTime.now();
        _tauxInteretController.text =
            (data['tauxInteret'] as num?)?.toString() ?? '';
        // Chargement des dépenses fixes
        final depenses = (data['depensesFixes'] as List<dynamic>?) ?? [];
        _depensesFixesControllers = depenses.map((d) {
          return DepenseFixeController(
            nom: d['nom'] ?? '',
            montant: d['montant']?.toString() ?? '',
          );
        }).toList();
        if (_depensesFixesControllers.isEmpty) {
          _depensesFixesControllers = [DepenseFixeController()];
        }
        _rembourserDettesAssociees = data['rembourserDettesAssociees'] ?? false;
      });
    } else {
      setState(() {
        _nomCarte = widget.nomCarte ?? '';
        _soldeActuel = 0.0;
        _limiteCredit = 0.0;
        _paiementMinimum = 0.0;
        _dateEcheance = DateTime.now();
        _tauxInteretController.text = '';
        _depensesFixesControllers = [DepenseFixeController()];
      });
    }
    _checkInitialSetup(); // <-- APPEL ICI, APRÈS le chargement Firestore
  }
}
