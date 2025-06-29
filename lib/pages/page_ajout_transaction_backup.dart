import 'package:flutter/material.dart';
import '../models/transaction_model.dart'
    show TypeTransaction, TypeMouvementFinancier;
import '../models/transaction_model.dart' as app_model;
import '../models/compte.dart'; // pour charger les comptes
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/argent_service.dart';
import '../services/dette_service.dart';
import '../models/dette.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fractionnement_model.dart';
import '../widgets/modale_fractionnement.dart';

class EcranAjoutTransaction extends StatefulWidget {
  final List<String> comptesExistants;
  final app_model.Transaction? transactionExistante;
  final bool modeModification;
  final VoidCallback? onTransactionSaved; // <-- Ajout du callback
  const EcranAjoutTransaction({
    super.key,
    required this.comptesExistants,
    this.transactionExistante,
    this.modeModification = false,
    this.onTransactionSaved, // <-- Ajout du paramètre
  });

  @override
  State<EcranAjoutTransaction> createState() => _EcranAjoutTransactionState();
}

class _EcranAjoutTransactionState extends State<EcranAjoutTransaction> {
  // --- Variables d'état ---
  app_model.TypeTransaction _typeSelectionne =
      app_model.TypeTransaction.depense;
  final TextEditingController _montantController = TextEditingController(
    text: '0.00',
  );
  final FocusNode _montantFocusNode = FocusNode();
  final TextEditingController _payeController = TextEditingController();
  String? _enveloppeSelectionnee;
  String? _compteSelectionne;
  DateTime _dateSelectionnee = DateTime.now();
  String? _marqueurSelectionne;
  final TextEditingController _noteController = TextEditingController();
  app_model.TypeMouvementFinancier _typeMouvementSelectionne =
      app_model.TypeMouvementFinancier.depenseNormale;

  List<Compte> _listeComptesAffichables = [];
  List<Compte> _comptesFirebase = []; // pour inclure prêts à placer
  List<String> _listeTiersConnus = [];

  // Pour les enveloppes dynamiques
  List<Map<String, dynamic>> _categoriesFirebase = [];
  List<String> _listeMarqueurs = ['Aucun', 'Important', 'À vérifier'];

  // Variables pour le fractionnement
  bool _estFractionnee = false;
  TransactionFractionnee? _transactionFractionnee;

  // Fonction utilitaire pour obtenir la couleur du compte d'origine d'une enveloppe
  Color _getCouleurCompteEnveloppe(Map<String, dynamic> enveloppe) {
    // D'abord essayer avec les provenances multi-comptes
    final List<dynamic>? provenances = enveloppe['provenances'];
    if (provenances != null && provenances.isNotEmpty) {
      // Prendre le compte avec le plus gros montant
      var provenance = provenances.reduce(
        (a, b) => (a['montant'] as num) > (b['montant'] as num) ? a : b,
      );
      final compteId = provenance['compte_id'] as String;
      final compte = _comptesFirebase.firstWhere(
        (c) => c.id == compteId,
        orElse: () => _comptesFirebase.first,
      );
      return Color(compte.couleur);
    }

    // Fallback avec l'ancien système de provenance unique
    final String? provenanceCompteId = enveloppe['provenance_compte_id'];
    if (provenanceCompteId != null && provenanceCompteId.isNotEmpty) {
      final compte = _comptesFirebase.firstWhere(
        (c) => c.id == provenanceCompteId,
        orElse: () => _comptesFirebase.first,
      );
      return Color(compte.couleur);
    }

    // Couleur par défaut si aucune provenance
    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _chargerComptesFirebase();
    _chargerTiersConnus();
    _chargerCategoriesFirebase();
    // Préremplissage si modification
    if (widget.transactionExistante != null) {
      final t = widget.transactionExistante!;
      _typeSelectionne = t.type;
      _typeMouvementSelectionne = t.typeMouvement;
      _montantController.text = t.montant.toStringAsFixed(2);
      _payeController.text = t.tiers ?? '';
      _compteSelectionne = t.compteId;
      _dateSelectionnee = t.date;
      _enveloppeSelectionnee = t.enveloppeId;
      _marqueurSelectionne = t.marqueur;
      _noteController.text = t.note ?? '';
    }
  }

  Future<void> _chargerCategoriesFirebase() async {
    final service = FirebaseService();
    final categories = await service.lireCategories().first;
    setState(() {
      _categoriesFirebase = categories
          .map(
            (cat) => {
              'id': cat.id,
              'nom': cat.nom,
              'enveloppes': cat.enveloppes.map((env) => env.toMap()).toList(),
            },
          )
          .toList();
    });
  }

  Future<void> _chargerTiersConnus() async {
    final service = FirebaseService();
    final liste = await service.lireTiers();
    setState(() {
      _listeTiersConnus = liste;
      _listeTiersConnus.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
      print(
        "_listeTiersConnus initialisée depuis Firebase: $_listeTiersConnus",
      );
    });
  }

  Future<void> _chargerComptesFirebase() async {
    final service = FirebaseService();
    final comptes = await service.lireComptes().first;
    setState(() {
      // Trier pour placer les comptes de type 'Chèque' en premier, puis par nom
      final sorted = List<Compte>.from(comptes);
      sorted.sort((a, b) {
        const targetType = 'Chèque';
        if (a.type == targetType && b.type != targetType) return -1;
        if (a.type != targetType && b.type == targetType) return 1;
        return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
      });
      _comptesFirebase = sorted;
      _mettreAJourListeComptesAffichables();
    });
  }

  void _mettreAJourListeComptesAffichables() {
    // Afficher seulement les comptes Chèque et Carte de crédit pour tous les types de transactions
    // Garder les objets Compte complets au lieu des noms seulement
    _listeComptesAffichables = _comptesFirebase
        .where((c) => c.type == 'Chèque' || c.type == 'Carte de crédit')
        .toList();
  }

  @override
  void dispose() {
    print("--- ECRAN DISPOSE ---");
    _montantController.dispose();
    _montantFocusNode.dispose();
    _payeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- Fonction _libellePourTypeMouvement (INCHANGÉE PAR RAPPORT À VOTRE VERSION PRÉCÉDENTE) ---
  String _libellePourTypeMouvement(TypeMouvementFinancier type) {
    switch (type) {
      case TypeMouvementFinancier.depenseNormale:
        return 'Dépense';
      case TypeMouvementFinancier.revenuNormal:
        return 'Revenu';
      case app_model.TypeMouvementFinancier.pretAccorde:
        return 'Prêt accordé (Sortie)';
      case TypeMouvementFinancier.remboursementRecu:
        return 'Remboursement reçu (Entrée)';
      case TypeMouvementFinancier.detteContractee:
        return 'Dette contractée (Entrée)';
      case TypeMouvementFinancier.remboursementEffectue:
        return 'Remboursement effectué (Sortie)';
      // Ajoutez d'autres cas si nécessaire, en vous assurant qu'ils existent dans l'enum
      default:
        // Pour être sûr, retournez le nom de l'enum si non mappé, ou un texte d'erreur
        print(
          "AVERTISSEMENT: Libellé non trouvé pour TypeMouvementFinancier.$type",
        );
        return type.name; // Retourne le nom de l'enum (ex: 'investissement')
    }
  }

  // --- NOUVELLE FONCTION _definirNomCompteDette ---
  // (Placée ici, avant les méthodes _build... ou avant onPressed du bouton Sauvegarder)
  Future<String?> _definirNomCompteDette(
    String nomPreteurInitial,
    double montantInitialTransaction,
  ) async {
    String nomCompteDette = "Prêt Personnel";
    String nomPreteur = nomPreteurInitial.trim();

    if (nomPreteur.isNotEmpty) {
      nomCompteDette += " : $nomPreteur";
    } else {
      if (!mounted) return null; // Vérification pour les opérations asynchrones
      final bool? continuerSansNom = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Nom du prêteur non spécifié'),
            content: const Text(
              'Aucun nom de prêteur n\'a été spécifié. '
              'Voulez-vous nommer le compte de dette "Prêt Personnel Générique" ?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Annuler'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text('Utiliser "Prêt Personnel Générique"'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        },
      );

      if (continuerSansNom == true) {
        nomCompteDette = "Prêt Personnel Générique";
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opération de dette annulée : nom du prêteur requis ou générique refusé.',
              ),
            ),
          );
        }
        return null;
      }
    }
    print('Nom du compte de dette déterminé : $nomCompteDette');
    return nomCompteDette;
  }

  // Nouvelle méthode pour créer ou récupérer le compte de prêt/dette
  Future<String?> _creerOuRecupererComptePret(
    String nomTiers,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final firebaseService = FirebaseService(); // Déclarer l'instance ici

      // Déterminer le nom du compte selon le type de mouvement
      String nomCompte;
      String typeCompte;
      double soldeInitial;

      if (typeMouvement == app_model.TypeMouvementFinancier.detteContractee) {
        nomCompte = "Prêt Personnel";
        if (nomTiers.trim().isNotEmpty) {
          nomCompte += " : ${nomTiers.trim()}";
        } else {
          nomCompte = "Prêt Personnel Générique";
        }
        typeCompte = "Dette";
        soldeInitial = -montant; // Négatif car c'est une dette
      } else if (typeMouvement ==
          app_model.TypeMouvementFinancier.pretAccorde) {
        nomCompte = "Prêt accordé";
        if (nomTiers.trim().isNotEmpty) {
          nomCompte += " : ${nomTiers.trim()}";
        } else {
          nomCompte = "Prêt accordé Générique";
        }
        typeCompte = "Prêt à placer";
        soldeInitial = montant; // Positif car c'est un prêt accordé
      } else {
        // Pour les remboursements, chercher le compte existant
        return await _rechercherComptePretExistant(nomTiers, typeMouvement);
      }

      // Vérifier si un compte similaire existe déjà
      final compteExistant = await _rechercherComptePretExistant(
        nomTiers,
        typeMouvement,
      );
      if (compteExistant != null) {
        return compteExistant;
      }

      // Créer un nouveau compte
      final compteId = FirebaseFirestore.instance
          .collection('comptes')
          .doc()
          .id;

      final nouveauCompte = Compte(
        id: compteId,
        userId: user.uid,
        nom: nomCompte,
        type: typeCompte,
        solde: soldeInitial,
        couleur:
            typeMouvement == app_model.TypeMouvementFinancier.detteContractee
            ? 0xFFE53935
            : 0xFF4CAF50, // Rouge pour dettes, vert pour prêts
        pretAPlacer:
            typeMouvement == app_model.TypeMouvementFinancier.pretAccorde
            ? montant
            : 0.0,
        dateCreation: DateTime.now(),
        estArchive: false,
        dateSuppression: null,
      );

      await firebaseService.ajouterCompte(nouveauCompte);
      return compteId;
    } catch (e) {
      print('Erreur lors de la création du compte de prêt: $e');
      return null;
    }
  }

  // Méthode pour rechercher un compte de prêt existant
  Future<String?> _rechercherComptePretExistant(
    String nomTiers,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      String typeCompteRecherche;
      if (typeMouvement == app_model.TypeMouvementFinancier.detteContractee ||
          typeMouvement ==
              app_model.TypeMouvementFinancier.remboursementEffectue) {
        typeCompteRecherche = "Dette";
      } else {
        typeCompteRecherche = "Prêt à placer";
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('comptes')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: typeCompteRecherche)
          .where('estArchive', isEqualTo: false)
          .get();

      // Chercher un compte dont le nom contient le nom du tiers
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final nomCompte = data['nom'] as String? ?? '';

        if (nomTiers.trim().isNotEmpty &&
            nomCompte.toLowerCase().contains(nomTiers.trim().toLowerCase())) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Erreur lors de la recherche du compte de prêt: $e');
      return null;
    }
  }

  // --- MÉTHODES POUR LE FRACTIONNEMENT ---
  void _ouvrirModaleFractionnement() async {
    final double montant =
        double.tryParse(_montantController.text.replaceAll(',', '.')) ?? 0.0;

    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord entrer un montant valide.'),
        ),
      );
      return;
    }

    // Obtenir toutes les enveloppes pour la modale
    final List<Map<String, dynamic>> toutesEnveloppes = [];
    for (var cat in _categoriesFirebase) {
      final List<dynamic> enveloppes = cat['enveloppes'] ?? [];
      for (var env in enveloppes) {
        toutesEnveloppes.add({
          'id': env['id'],
          'nom': env['nom'],
          'categorieNom': cat['nom'],
          'solde': env['solde'] ?? 0.0,
          'provenances': env['provenances'],
          'provenance_compte_id': env['provenance_compte_id'],
          'comptes': _comptesFirebase
              .map((c) => {'id': c.id, 'nom': c.nom, 'couleur': c.couleur})
              .toList(),
        });
      }
    }

    print('DEBUG: showModalBottomSheet - montant = ' + montant.toString());
    print(
      'DEBUG: showModalBottomSheet - enveloppes = ' +
          toutesEnveloppes.length.toString(),
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        print('DEBUG: builder showModalBottomSheet appelé');
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ModaleFractionnement(
            montantTotal: montant,
            enveloppes: toutesEnveloppes,
            onConfirmer: (TransactionFractionnee transactionFractionnee) {
              print('DEBUG: onConfirmer appelé dans ModaleFractionnement');
              setState(() {
                _estFractionnee = true;
                _transactionFractionnee = transactionFractionnee;
              });
            },
          ),
        );
      },
    );
    print('DEBUG: showModalBottomSheet terminé');
  }

  void _supprimerFractionnement() {
    setState(() {
      _estFractionnee = false;
      _transactionFractionnee = null;
    });
  }

  Widget _buildSectionFractionnement() {
    if (!_estFractionnee) {
      return Container();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.call_split, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Transaction fractionnée',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _supprimerFractionnement,
                  icon: const Icon(Icons.close, color: Colors.red),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._transactionFractionnee!.sousItems
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.description,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.montant.toStringAsFixed(2)} \$',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            const Divider(),
            Row(
              children: [
                const Text(
                  'Total :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_transactionFractionnee!.montantTotal.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Méthodes _build... ---
  // _buildSelecteurTypeTransaction() - (INCHANGÉE PAR RAPPORT À VOTRE VERSION PRÉCÉDENTE)
  Widget _buildSelecteurTypeTransaction() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color selectorBackgroundColor = isDark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final Color selectedOptionColor = isDark
        ? Colors.black54
        : Colors.blueGrey[700]!;
    final Color unselectedTextColor = isDark
        ? Colors.grey[400]!
        : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        color: selectorBackgroundColor,
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildOptionType(
            TypeTransaction.depense,
            '- Dépense',
            selectedOptionColor,
            unselectedTextColor,
          ),
          _buildOptionType(
            TypeTransaction.revenu,
            '+ Revenu',
            selectedOptionColor,
            unselectedTextColor,
          ),
        ],
      ),
    );
  }

  // _buildOptionType() - (INCHANGÉE, ASSUREZ-VOUS D'UTILISER .estDepense/.estRevenu)
  Widget _buildOptionType(
    TypeTransaction type,
    String libelle,
    Color selectedBackgroundColor,
    Color unselectedTextColor,
  ) {
    final estSelectionne = _typeSelectionne == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _typeSelectionne = type;
            if (type == TypeTransaction.depense) {
              if (!_typeMouvementSelectionne.estDepense) {
                _typeMouvementSelectionne =
                    TypeMouvementFinancier.depenseNormale;
              }
            } else {
              // TypeTransaction.revenu
              if (!_typeMouvementSelectionne.estRevenu) {
                _typeMouvementSelectionne = TypeMouvementFinancier.revenuNormal;
              }
            }
            print(
              "Sélecteur D/R changé: _typeSelectionne: $_typeSelectionne, _typeMouvementSelectionne: $_typeMouvementSelectionne",
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: estSelectionne
                ? selectedBackgroundColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: Text(
            libelle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: estSelectionne ? Colors.white : unselectedTextColor,
              fontWeight: estSelectionne ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // _buildChampMontant() - (MODIFIÉE pour gérer le fractionnement)
  // Ouvre le clavier numérique custom
  void _openNumericKeyboard() {
    // Si la transaction est fractionnée, demander confirmation avant de réinitialiser
    if (_estFractionnee) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modifier le montant'),
          content: const Text(
            'Modifier le montant va supprimer le fractionnement actuel. Voulez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _estFractionnee = false;
                  _transactionFractionnee = null;
                });
                _ouvrirClavierNumerique();
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    } else {
      _ouvrirClavierNumerique();
    }
  }

  void _ouvrirClavierNumerique() {
    showModalBottomSheet(
      context: context,
      builder: (_) => NumericKeyboard(
        controller: _montantController,
        onClear: () {
          setState(() => _montantController.text = '0.00');
        },
        showDecimal: true,
      ),
    );
  }

  Widget _buildChampMontant() {
    // Utilise un rouge vif pour le montant des dépenses
    final Color couleurMontant = _typeSelectionne == TypeTransaction.depense
        ? const Color(0xFF8A0707) // Rouge vif (Red A400)
        : Colors.greenAccent[300] ?? Colors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: TextField(
        controller: _montantController,
        readOnly: true,
        onTap: _openNumericKeyboard,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: couleurMontant,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '0.00',
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  // _buildSectionInformationsCles() - (MODIFIÉE pour le Dropdown des comptes et le onChanged du Type Mouvement)
  Widget _buildSectionInformationsCles() {
    final cardColor =
        Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]!
            : Colors.white);
    final cardShape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));

    return Card(
      color: cardColor,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: <Widget>[
            // --- CHAMP TYPE MOUVEMENT (onChanged simplifié) ---
            _buildChampDetail(
              icone: Icons.compare_arrows,
              libelle: 'Transaction',
              widgetContenu: DropdownButtonFormField<TypeMouvementFinancier>(
                value: _typeMouvementSelectionne,
                items: TypeMouvementFinancier.values.map((
                  TypeMouvementFinancier type,
                ) {
                  return DropdownMenuItem<TypeMouvementFinancier>(
                    value: type,
                    child: Text(
                      _libellePourTypeMouvement(type),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (TypeMouvementFinancier? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _typeMouvementSelectionne = newValue;
                      if (newValue.estDepense) {
                        _typeSelectionne = TypeTransaction.depense;
                      } else if (newValue.estRevenu) {
                        _typeSelectionne = TypeTransaction.revenu;
                      }
                      // Réinitialiser le compte sélectionné si on change de type
                      if (newValue != TypeMouvementFinancier.detteContractee &&
                          _compteSelectionne != null &&
                          _compteSelectionne!.startsWith("Prêt Personnel")) {
                        _compteSelectionne = null;
                      }
                      // Mettre à jour la liste des comptes affichables selon le nouveau type
                      _mettreAJourListeComptesAffichables();
                      print(
                        "Dropdown Type Mouvement changé: $_typeMouvementSelectionne, _typeSelectionne: $_typeSelectionne",
                      );
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Type de mouvement',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 10.0,
                  ),
                ),
                isExpanded: true,
              ),
            ),
            _buildSeparateurDansCarte(),
            _buildChampDetail(
              icone: Icons.person_outline,
              libelle:
                  _typeMouvementSelectionne ==
                      TypeMouvementFinancier.detteContractee
                  ? 'Prêteur'
                  : 'Tiers',
              widgetContenu: Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final String texteSaisi = textEditingValue.text;

                  if (textEditingValue.text.isEmpty) {
                    return _listeTiersConnus;
                  }

                  final suggestionsStandard = _listeTiersConnus.where((
                    String option,
                  ) {
                    return option.toLowerCase().contains(
                      texteSaisi.toLowerCase(),
                    );
                  });

                  // Vérifier si le texte saisi existe déjà exactement (insensible à la casse) dans la liste
                  bool existeDeja = _listeTiersConnus.any(
                    (String option) =>
                        option.toLowerCase() == texteSaisi.toLowerCase(),
                  );

                  // Si le texte saisi n'est pas vide ET n'existe pas déjà, ajouter l'option "Ajouter : ..."
                  if (texteSaisi.isNotEmpty && !existeDeja) {
                    // Crée une nouvelle liste modifiable à partir des suggestions et ajoute l'option "Ajouter"
                    // On met l'option "Ajouter" en premier pour plus de visibilité, ou en dernier selon la préférence.
                    return <String>[
                      'Ajouter : $texteSaisi',
                      ...suggestionsStandard,
                    ];
                  } else {
                    // Sinon, retourner seulement les suggestions standard
                    return suggestionsStandard;
                  }
                },
                fieldViewBuilder:
                    (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Synchronisation avec _payeController
                      if (_payeController.text.isNotEmpty &&
                          fieldTextEditingController.text !=
                              _payeController.text) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted)
                            fieldTextEditingController.text =
                                _payeController.text;
                        });
                      }
                      fieldTextEditingController.addListener(() {
                        if (mounted &&
                            _payeController.text !=
                                fieldTextEditingController.text) {
                          _payeController.text =
                              fieldTextEditingController.text;
                        }
                      });

                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          hintText:
                              _typeMouvementSelectionne ==
                                  TypeMouvementFinancier.detteContractee
                              ? 'Nom du prêteur'
                              : 'Payé à / Reçu de',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 10.0,
                          ),
                        ),
                        onSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                onSelected: (String selection) async {
                  final String prefixeAjout = "Ajouter : ";
                  if (selection.startsWith(prefixeAjout)) {
                    final String nomAAjouter = selection.substring(
                      prefixeAjout.length,
                    );
                    print('ACTION: Ajouter un nouveau tiers "$nomAAjouter"');
                    _payeController.text = nomAAjouter;
                    if (!_listeTiersConnus.any(
                      (t) => t.toLowerCase() == nomAAjouter.toLowerCase(),
                    )) {
                      setState(() {
                        _listeTiersConnus.add(nomAAjouter);
                        _listeTiersConnus.sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                        print(
                          "_listeTiersConnus mise à jour avec le nouveau tiers: $_listeTiersConnus",
                        );
                      });
                      // Sauvegarde sur Firebase
                      await FirebaseService().ajouterTiers(nomAAjouter);
                    }
                  } else {
                    _payeController.text = selection;
                  }
                  setState(() {});
                  FocusScope.of(context).unfocus();
                },
                // Optionnel: Personnaliser l'apparence des options
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                        ), // Limite la hauteur de la liste
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildSeparateurDansCarte(),

            _buildChampDetail(
              icone: Icons.account_balance_wallet_outlined,
              // Le libellé peut changer dynamiquement
              libelle:
                  _typeMouvementSelectionne ==
                      TypeMouvementFinancier.detteContractee
                  ? 'Vers Compte Actif' // Libellé spécifique pour les dettes
                  : 'Compte', // Libellé normal
              widgetContenu: DropdownButtonFormField<String>(
                value: _compteSelectionne,
                items: _listeComptesAffichables.map((Compte compte) {
                  return DropdownMenuItem<String>(
                    value: compte.id,
                    child: Row(
                      children: [
                        // Cercle coloré avec la couleur du compte
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(compte.couleur),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Afficher le nom du compte au lieu de l'id
                        Expanded(
                          child: Text(
                            compte.nom,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _compteSelectionne = newValue;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Sélectionner un compte', // Texte d'aide si rien n'est sélectionné
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 10.0,
                  ),
                ),
                isExpanded: true,
              ),
            ),
            _buildSeparateurDansCarte(),

            // ... (Vos autres champs: Date, Enveloppe, Marqueur, Note - INCHANGÉS)
            // Exemple pour Date:
            _buildChampDetail(
              icone: Icons.calendar_today_outlined,
              libelle: 'Date',
              widgetContenu: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _dateSelectionnee,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _dateSelectionnee) {
                    setState(() {
                      _dateSelectionnee = picked;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 10.0,
                  ),
                  child: Text(
                    "${_dateSelectionnee.toLocal()}".split(
                      ' ',
                    )[0], // Format YYYY-MM-DD
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            _buildSeparateurDansCarte(),

            // Condition pour afficher le champ Enveloppe
            if (_typeMouvementSelectionne ==
                    TypeMouvementFinancier.depenseNormale ||
                _typeMouvementSelectionne ==
                    TypeMouvementFinancier.revenuNormal) ...[
              _buildChampDetail(
                icone: Icons.label_outline,
                libelle: 'Enveloppe',
                widgetContenu: DropdownButtonFormField<String>(
                  value: _enveloppeSelectionnee,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        "Aucune",
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                    // Prêts à placer dynamiques selon les comptes, mais seulement si ce n'est PAS une dépense
                    ...(_typeSelectionne != TypeTransaction.depense &&
                            _compteSelectionne != null
                        ? _comptesFirebase
                              .where(
                                (c) =>
                                    c.pretAPlacer > 0 &&
                                    c.id == _compteSelectionne,
                              )
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: 'pret_${c.id}',
                                  child: Text(
                                    '${c.nom} : Prêt à placer ${c.pretAPlacer.toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList()
                        : []),
                    // Enveloppes classiques filtrées selon le compte sélectionné si dépense
                    ..._categoriesFirebase
                        .expand((cat) => (cat['enveloppes'] as List))
                        .where((env) {
                          final solde =
                              (env['solde'] as num?)?.toDouble() ?? 0.0;
                          if (_typeSelectionne == TypeTransaction.depense &&
                              _compteSelectionne != null) {
                            // Gestion multi-provenances
                            if (env['provenances'] != null &&
                                (env['provenances'] as List).isNotEmpty) {
                              return (env['provenances'] as List).any(
                                    (prov) =>
                                        prov['compte_id'] == _compteSelectionne,
                                  ) ||
                                  solde == 0;
                            }
                            // Gestion ancienne provenance unique
                            if (env['provenance_compte_id'] != null) {
                              return env['provenance_compte_id'] ==
                                      _compteSelectionne ||
                                  solde == 0;
                            }
                            // Sinon, ne pas afficher sauf si solde == 0
                            return solde == 0;
                          }
                          // Sinon (revenu ou pas de compte sélectionné), tout afficher
                          return true;
                        })
                        .map<DropdownMenuItem<String>>((env) {
                          final solde =
                              (env['solde'] as num?)?.toDouble() ?? 0.0;
                          final couleurCompte = _getCouleurCompteEnveloppe(env);

                          return DropdownMenuItem<String>(
                            value: env['id'],
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    env['nom'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${solde.toStringAsFixed(2)} \$',
                                  style: TextStyle(
                                    color: couleurCompte,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                  ],
                  onChanged: (String? newValue) =>
                      setState(() => _enveloppeSelectionnee = newValue),
                  decoration: InputDecoration(
                    hintText: 'Optionnel',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 10.0,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
              _buildSeparateurDansCarte(),
            ],

            _buildChampDetail(
              icone: Icons.flag_outlined,
              libelle: 'Marqueur',
              widgetContenu: DropdownButtonFormField<String>(
                value:
                    _marqueurSelectionne ??
                    _listeMarqueurs
                        .first, // Assurer une valeur par défaut non nulle
                items: _listeMarqueurs.map((String marqueur) {
                  return DropdownMenuItem<String>(
                    value: marqueur,
                    child: Text(marqueur),
                  );
                }).toList(),
                onChanged: (String? newValue) =>
                    setState(() => _marqueurSelectionne = newValue),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 10.0,
                  ),
                ),
                isExpanded: true,
              ),
            ),
            _buildSeparateurDansCarte(),

            _buildChampDetail(
              icone: Icons.notes_outlined,
              libelle: 'Note',
              widgetContenu: TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Optionnel',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 10.0,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, // Permet plusieurs lignes
              ),
              alignementVerticalIcone: CrossAxisAlignment.start,
            ),
          ],
        ),
      ),
    );
  }

  // _buildChampDetail() - (Peut-être ajouter un paramètre pour l'alignement de l'icône si besoin)
  Widget _buildChampDetail({
    required IconData icone,
    required String libelle,
    required Widget widgetContenu,
    CrossAxisAlignment alignementVerticalIcone = CrossAxisAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: alignementVerticalIcone,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              right: 16.0,
              top: 2.0,
            ), // Léger ajustement pour l'icône
            child: Icon(
              icone,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          Expanded(
            flex: 2, // Donne plus de place au libellé si nécessaire
            child: Text(libelle, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3, // Donne plus de place au contenu
            child: Align(
              alignment: Alignment.centerRight,
              child: widgetContenu,
            ),
          ),
        ],
      ),
    );
  }

  // _buildSeparateurDansCarte() - (INCHANGÉE)
  Widget _buildSeparateurDansCarte() {
    // Correction de l'utilisation de withOpacity (déprécié)
    return Divider(
      height: 1,
      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
    );
  }

  // --- Méthode build() avec le bouton Sauvegarder MODIFIÉE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter Transaction'),
        // actions: [IconButton(icon: Icon(Icons.save), onPressed: _sauvegarderTransaction)], // Si vous aviez un bouton save ici
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSelecteurTypeTransaction(),
            _buildChampMontant(),
            _buildSectionInformationsCles(),

            // Section fractionnement
            _buildSectionFractionnement(),

            const SizedBox(height: 20),

            // Bouton Fractionner - seulement pour les dépenses normales
            if (_typeMouvementSelectionne ==
                    TypeMouvementFinancier.depenseNormale &&
                !_estFractionnee)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: _ouvrirModaleFractionnement,
                  icon: const Icon(Icons.call_split),
                  label: const Text('Fractionner'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.blue),
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // --- BOUTON SAUVEGARDER (LOGIQUE MODIFIÉE) ---
            ElevatedButton(
              onPressed:
                  (_payeController.text.trim().isEmpty ||
                      // Il faut soit une enveloppe, soit un fractionnement
                      (!_estFractionnee &&
                          !(_typeMouvementSelectionne ==
                                  TypeMouvementFinancier.pretAccorde ||
                              _typeMouvementSelectionne ==
                                  TypeMouvementFinancier.remboursementRecu ||
                              _typeMouvementSelectionne ==
                                  TypeMouvementFinancier.detteContractee ||
                              _typeMouvementSelectionne ==
                                  TypeMouvementFinancier
                                      .remboursementEffectue) &&
                          (_enveloppeSelectionnee == null ||
                              _enveloppeSelectionnee!.isEmpty)))
                  ? null // Désactive le bouton si la condition n'est pas remplie
                  : () async {
                      final double montant =
                          double.tryParse(
                            _montantController.text.replaceAll(',', '.'),
                          ) ??
                          0.0;
                      final String tiersTexte = _payeController.text.trim();
                      if (montant <= 0) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez entrer un montant valide.',
                              ),
                            ),
                          );
                        return;
                      }
                      if (_compteSelectionne == null ||
                          _compteSelectionne!.isEmpty) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez sélectionner le compte de destination.',
                              ),
                            ),
                          );
                        return;
                      }

                      // Validation spécifique pour les transactions fractionnées
                      if (_estFractionnee && _transactionFractionnee != null) {
                        if (!_transactionFractionnee!.estValide) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le fractionnement n\'est pas valide. Vérifiez que la somme des sous-items égale le montant total.',
                                ),
                              ),
                            );
                          return;
                        }
                      }

                      final compte = _comptesFirebase.firstWhere(
                        (c) => c.id == _compteSelectionne,
                        orElse: () => throw Exception(
                          'Aucun compte correspondant trouvé pour l\'id sélectionné.',
                        ),
                      );
                      final argentService = ArgentService();
                      final detteService = DetteService();
                      final firebaseService = FirebaseService();
                      final String transactionId = DateTime.now()
                          .millisecondsSinceEpoch
                          .toString();
                      final DateTime now = DateTime.now();
                      String? detteId;
                      final user = FirebaseAuth.instance.currentUser;

                      // --- LOGIQUE SELON LE TYPE DE MOUVEMENT ---
                      try {
                        print('DEBUG: Début de la logique de sauvegarde...');
                        // Calculer estFractionneeFinal pour toutes les sections
                        final bool estFractionneeFinal =
                            _estFractionnee &&
                            _transactionFractionnee != null &&
                            _transactionFractionnee!.sousItems.isNotEmpty;
                        print(
                          'DEBUG: estFractionneeFinal = $estFractionneeFinal',
                        );

                        if (widget.modeModification &&
                            widget.transactionExistante != null) {
                          print('DEBUG: Mode modification détecté...');
                          // Mise à jour de la transaction existante
                          final user = FirebaseAuth.instance.currentUser;
                          final nouvelleTransaction = app_model.Transaction(
                            id: widget.transactionExistante!.id,
                            userId: user?.uid ?? '',
                            type: _typeSelectionne,
                            typeMouvement: _typeMouvementSelectionne,
                            montant: montant,
                            tiers: tiersTexte,
                            compteId: compte.id,
                            compteDePassifAssocie: null,
                            date: _dateSelectionnee,
                            enveloppeId: estFractionneeFinal
                                ? null
                                : _enveloppeSelectionnee,
                            marqueur: _marqueurSelectionne,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                            estFractionnee: estFractionneeFinal,
                            sousItems: estFractionneeFinal
                                ? _transactionFractionnee!.sousItems
                                      .map((item) => item.toJson())
                                      .toList()
                                : null,
                          );
                          print(
                            'DEBUG: Transaction de modification créée, tentative de sauvegarde...',
                          );
                          try {
                            await firebaseService.ajouterTransaction(
                              nouvelleTransaction,
                            );
                          } catch (e, stack) {
                            print('ERREUR lors de la sauvegarde: $e');
                            print(stack);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Erreur lors de la sauvegarde de la transaction.',
                                ),
                              ),
                            );
                            return;
                          }
                        } else {
                          print('DEBUG: Mode création détecté...');
                          // Création d'une nouvelle transaction

                          // Gérer les dettes/prêts selon le type de mouvement en utilisant DetteService
                          if (_typeMouvementSelectionne ==
                                  app_model
                                      .TypeMouvementFinancier
                                      .detteContractee ||
                              _typeMouvementSelectionne ==
                                  app_model
                                      .TypeMouvementFinancier
                                      .pretAccorde) {
                            await _creerDetteViaDettesService(
                              tiersTexte,
                              montant,
                              _typeMouvementSelectionne,
                            );
                          }

                          // Gérer les remboursements via DetteService
                          if (_typeMouvementSelectionne ==
                                  app_model
                                      .TypeMouvementFinancier
                                      .remboursementRecu ||
                              _typeMouvementSelectionne ==
                                  app_model
                                      .TypeMouvementFinancier
                                      .remboursementEffectue) {
                            await _traiterRemboursementViaDettesService(
                              tiersTexte,
                              montant,
                              _typeMouvementSelectionne,
                              transactionId,
                            );
                          }

                          final nouvelleTransaction = app_model.Transaction(
                            id: transactionId,
                            userId: user?.uid ?? '',
                            type: _typeSelectionne,
                            typeMouvement: _typeMouvementSelectionne,
                            montant: montant,
                            tiers: tiersTexte,
                            compteId: compte.id,
                            compteDePassifAssocie:
                                null, // Pas besoin de comptes associés avec DetteService
                            date: _dateSelectionnee,
                            enveloppeId: estFractionneeFinal
                                ? null
                                : _enveloppeSelectionnee,
                            marqueur: _marqueurSelectionne,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                            estFractionnee: estFractionneeFinal,
                            sousItems: estFractionneeFinal
                                ? _transactionFractionnee!.sousItems
                                      .map((item) => item.toJson())
                                      .toList()
                                : null,
                          );
                          print(
                            'DEBUG: Nouvelle transaction créée, tentative de sauvegarde...',
                          );
                          try {
                            await firebaseService.ajouterTransaction(
                              nouvelleTransaction,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Transaction sauvegardée avec succès !',
                                  ),
                                ),
                              );
                            }
                          } catch (e, stack) {
                            print('ERREUR lors de la sauvegarde: $e');
                            print(stack);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Erreur lors de la sauvegarde de la transaction.',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: ${e.toString()}')),
                          );
                        }
                      }
                    },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  // Nouvelle méthode pour créer une dette via DetteService au lieu de comptes automatiques
  Future<void> _creerDetteViaDettesService(
    String nomTiers,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final detteService = DetteService();
      final String detteId = DateTime.now().millisecondsSinceEpoch.toString();

      // Déterminer le type de dette selon le mouvement
      String typeDette;
      if (typeMouvement == app_model.TypeMouvementFinancier.detteContractee) {
        typeDette = 'dette'; // Je dois de l'argent
      } else if (typeMouvement ==
          app_model.TypeMouvementFinancier.pretAccorde) {
        typeDette = 'pret'; // On me doit de l'argent
      } else {
        return; // Pour les remboursements, on ne crée pas de nouvelle dette
      }

      // Créer la dette
      final nouvelleDette = Dette(
        id: detteId,
        nomTiers: nomTiers.trim().isNotEmpty
            ? nomTiers.trim()
            : 'Tiers générique',
        montantInitial: montant,
        solde: montant,
        type: typeDette,
        historique: [
          MouvementDette(
            id: '${detteId}_initial', // Ajouter l'ID obligatoire
            type: typeDette,
            montant: typeDette == 'dette'
                ? montant
                : -montant, // Négatif pour les prêts accordés
            date: DateTime.now(),
            note: 'Création initiale',
          ),
        ],
        archive: false,
        dateCreation: DateTime.now(),
        dateArchivage: null,
        userId: user.uid,
      );

      await detteService.creerDette(nouvelleDette);
    } catch (e) {
      print('Erreur lors de la création de la dette: $e');
    }
  }

  // Nouvelle méthode pour traiter les remboursements via DetteService
  Future<void> _traiterRemboursementViaDettesService(
    String nomTiers,
    double montant,
    app_model.TypeMouvementFinancier typeMouvement,
    String transactionId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final detteService = DetteService();

      // Déterminer le type de remboursement
      String typeRemboursement;
      String typeDetteRecherche;

      if (typeMouvement == app_model.TypeMouvementFinancier.remboursementRecu) {
        typeRemboursement = 'remboursement_recu';
        typeDetteRecherche = 'pret'; // Chercher dans les prêts accordés
      } else {
        typeRemboursement = 'remboursement_effectue';
        typeDetteRecherche = 'dette'; // Chercher dans les dettes contractées
      }

      // Trouver les dettes actives pour ce tiers
      final dettesActives = await detteService.dettesActives().first;

      // Debug : afficher toutes les dettes actives
      print('DEBUG - Dettes actives trouvées : ${dettesActives.length}');
      for (final dette in dettesActives) {
        print(
          'DEBUG - Dette : ID=${dette.id}, Tiers="${dette.nomTiers}", Type=${dette.type}, Solde=${dette.solde}',
        );
      }

      print(
        'DEBUG - Recherche pour : nomTiers="$nomTiers", typeDetteRecherche="$typeDetteRecherche"',
      );

      // Recherche plus flexible : d'abord une correspondance exacte, puis une correspondance partielle
      var dettesATiers = dettesActives
          .where(
            (d) =>
                d.nomTiers.toLowerCase() == nomTiers.toLowerCase() &&
                d.type == typeDetteRecherche,
          )
          .toList();

      // Si aucune correspondance exacte, essayer une correspondance partielle
      if (dettesATiers.isEmpty) {
        dettesATiers = dettesActives
            .where(
              (d) =>
                  (d.nomTiers.toLowerCase().contains(nomTiers.toLowerCase()) ||
                      nomTiers.toLowerCase().contains(
                        d.nomTiers.toLowerCase(),
                      )) &&
                  d.type == typeDetteRecherche,
            )
            .toList();

        if (dettesATiers.isNotEmpty) {
          print(
            'DEBUG - Correspondance partielle trouvée avec "${dettesATiers.first.nomTiers}"',
          );
        }
      }

      // Si toujours aucune correspondance, essayer de chercher dans les comptes associés
      if (dettesATiers.isEmpty) {
        // Chercher une dette qui a un compte associé dont le nom contient le tiers recherché
        for (final dette in dettesActives.where(
          (d) => d.type == typeDetteRecherche,
        )) {
          if (dette.compteAssocie != null) {
            // Récupérer le compte associé pour vérifier son nom
            try {
              final compteDoc = await FirebaseFirestore.instance
                  .collection('comptes')
                  .doc(dette.compteAssocie)
                  .get();
              if (compteDoc.exists) {
                final compteData = compteDoc.data() as Map<String, dynamic>;
                final nomCompte = compteData['nom'] as String? ?? '';

                // Vérifier si le nom du tiers correspond au nom du compte
                if (nomCompte.toLowerCase().contains(nomTiers.toLowerCase())) {
                  dettesATiers.add(dette);
                  print(
                    'DEBUG - Correspondance trouvée via compte associé : "${nomCompte}"',
                  );
                  break;
                }
              }
            } catch (e) {
              print(
                'DEBUG - Erreur lors de la vérification du compte associé : $e',
              );
            }
          }
        }
      }

      if (dettesATiers.isEmpty) {
        print(
          'DEBUG - Aucune dette trouvée pour "$nomTiers" de type "$typeDetteRecherche"',
        );
        if (mounted) {
          // Afficher les dettes disponibles pour aider l'utilisateur
          final dettesDisponibles = dettesActives
              .where((d) => d.type == typeDetteRecherche)
              .map((d) => d.nomTiers)
              .toSet()
              .join(', ');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Aucune ${typeDetteRecherche == 'pret' ? 'prêt' : 'dette'} active trouvée pour "$nomTiers".\n'
                'Dettes disponibles : $dettesDisponibles',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Trier par date de création (plus ancien en premier)
      dettesATiers.sort((a, b) => a.dateCreation.compareTo(b.dateCreation));

      double montantRestant = montant;

      // Traitement en cascade pour rembourser les dettes dans l'ordre
      for (final dette in dettesATiers) {
        if (montantRestant <= 0) break;

        final montantAPayer = montantRestant >= dette.solde
            ? dette.solde
            : montantRestant;

        // Créer le mouvement de remboursement
        final mouvement = MouvementDette(
          id: '${transactionId}_${dette.id}',
          date: DateTime.now(),
          montant: -montantAPayer, // Négatif car c'est un remboursement
          type: typeRemboursement,
          note: 'Remboursement via transaction $transactionId',
        );

        // Ajouter le mouvement à la dette (cela déclenchera automatiquement le recalcul du solde)
        await detteService.ajouterMouvement(dette.id, mouvement);

        montantRestant -= montantAPayer;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Remboursement de ${montantAPayer.toStringAsFixed(2)}\$ appliqué à ${dette.nomTiers}',
              ),
            ),
          );
        }
      }

      if (montantRestant > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Remboursement excédentaire de ${montantRestant.toStringAsFixed(2)}\$ - toutes les dettes sont remboursées',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du traitement du remboursement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du traitement du remboursement: $e'),
          ),
        );
      }
    }
  }
}
