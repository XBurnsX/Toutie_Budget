import 'package:flutter/material.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/enveloppe.dart';
import '../services/argent_service.dart';
import '../services/color_service.dart';
import '../services/cache_service.dart';
import '../services/persistent_cache_service.dart';
import '../services/pocketbase_service.dart';
import '../widgets/numeric_keyboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PageVirerArgent extends StatefulWidget {
  const PageVirerArgent({
    super.key,
    this.destinationPreselectionnee,
    this.montantPreselectionne,
  });

  final String? destinationPreselectionnee;
  final double? montantPreselectionne;

  @override
  State<PageVirerArgent> createState() => _PageVirerArgentState();
}

class _PageVirerArgentState extends State<PageVirerArgent> {
  late TextEditingController _montantController;
  String? sourceId;
  String? destinationId;
  dynamic source;
  dynamic destination;
  String? _montantOriginal;
  int _refreshKey = 0; // Clé pour forcer le rafraîchissement des FutureBuilder

  @override
  void initState() {
    super.initState();
    String initialMontant = '';
    if (widget.montantPreselectionne != null) {
      initialMontant =
          widget.montantPreselectionne!.toStringAsFixed(2).replaceAll('.', ',');
    }
    _montantController = TextEditingController(text: initialMontant);
    _montantController.addListener(() {
      setState(() {});
    });

    // Apply preselection if provided
    if (widget.destinationPreselectionnee != null) {
      destinationId = widget.destinationPreselectionnee;
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  void _openNumericKeyboard(BuildContext context) {
    // Sauvegarder la valeur actuelle et réinitialiser
    _montantOriginal = _montantController.text;
    _montantController.text = '0,00';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NumericKeyboard(
        controller: _montantController,
        onValueChanged: (val) {}, // Le listener sur le controller s'en occupe
        onClear: () => _montantController.clear(),
        showDone: false,
      ),
    ).whenComplete(() {
      // Si l'utilisateur ferme sans entrer de valeur, restaurer la valeur originale
      if (_montantController.text == '0,00' ||
          _montantController.text.isEmpty) {
        _montantController.text = _montantOriginal ?? '';
      }
    });
  }

  void _updateObjectsFromSelection(List<dynamic> tout) {
    // Met à jour les objets source et destination quand les données changent
    if (sourceId != null) {
      source = getSelectedById(sourceId, tout);
    }
    if (destinationId != null) {
      destination = getSelectedById(destinationId, tout);
    }
  }

  void _afficherMessageErreurMelangeFonds(
    BuildContext context, {
    bool isEnveloppeVersEnveloppe = false,
    bool isEnveloppeVersCompte = false,
  }) {
    String titre;
    String message;

    if (isEnveloppeVersCompte) {
      titre = "Impossible de retourner l'argent";
      message =
          "Cette enveloppe contient de l'argent qui ne provient pas de ce compte.\nVous ne pouvez retourner l'argent que vers son compte d'origine.";
    } else if (isEnveloppeVersEnveloppe) {
      titre = "Impossible de transférer l'argent";
      message =
          "Ces enveloppes contiennent de l'argent provenant de comptes différents.\nVous ne pouvez pas mélanger les fonds.";
    } else {
      titre = "Impossible d'ajouter de l'argent";
      message =
          "Cette enveloppe contient déjà de l'argent provenant d'un autre compte.\nVous ne pouvez pas mélanger les fonds.";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.grey[900],
        title: Text(
          titre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 20, color: Colors.white),
            label: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  dynamic getSelectedById(String? id, List<dynamic> tout) {
    for (var obj in tout) {
      String? objId;
      if (obj is Compte) {
        objId = obj.id;
      } else if (obj is Enveloppe) {
        objId = obj.id;
      } else {
        continue;
      }
      if (objId == id) {
        return obj;
      }
    }
    return null;
  }

  String getId(dynamic obj) {
    String result;
    if (obj is Compte) {
      result = obj.id;
    } else if (obj is Enveloppe) {
      result = obj.id;
    } else {
      result = '';
    }
    return result;
  }

  bool _peutVirer() {
    // Le bouton est cliquable dès que source et destination sont sélectionnées
    return sourceId != null && destinationId != null;
  }

  Future<void> _effectuerVirement() async {
    if (!_peutVirer()) return;

    // Vérifier d'abord le montant
    if (_montantController.text.isEmpty) {
      _afficherErreur('Veuillez saisir un montant.');
      return;
    }

    double montantDouble =
        double.tryParse(_montantController.text.replaceAll(',', '.')) ?? 0;
    if (montantDouble <= 0) {
      _afficherErreur('Le montant doit être supérieur à 0.');
      return;
    }

    try {
      // Vérifier les soldes
      if (source is Compte && (source as Compte).pretAPlacer < montantDouble) {
        _afficherErreur('Solde insuffisant dans le compte source.');
        return;
      }
      if (source is Enveloppe && (source as Enveloppe).solde < montantDouble) {
        _afficherErreur('Solde insuffisant dans l\'enveloppe source.');
        return;
      }

      await ArgentService().virerArgent(
        sourceId: sourceId!,
        destinationId: destinationId!,
        montant: montantDouble,
      );

      if (mounted) {
        // Forcer le rafraîchissement des données
        _refreshData();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Succès',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Virement de ${montantDouble.toStringAsFixed(2)} \$ effectué avec succès',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 20, color: Colors.white),
                label: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Ferme le popup
                  Navigator.of(context).pop(); // Ferme la page
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Gestion spécifique des erreurs de mélange de fonds
      String errorMessage = e.toString();

      if (errorMessage.contains('mélanger') ||
          errorMessage.contains('provient') ||
          errorMessage.contains('autre compte')) {
        // Déterminer le type d'erreur pour afficher la bonne modale
        if (source is Enveloppe && destination is Compte) {
          _afficherMessageErreurMelangeFonds(
            context,
            isEnveloppeVersCompte: true,
          );
        } else if (source is Enveloppe && destination is Enveloppe) {
          _afficherMessageErreurMelangeFonds(
            context,
            isEnveloppeVersEnveloppe: true,
          );
        } else {
          _afficherMessageErreurMelangeFonds(context);
        }
      } else {
        // Autres erreurs
        _afficherErreur('Erreur lors du virement: $e');
      }
    }
  }

  void _afficherErreur(String message) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Erreur',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 20, color: Colors.white),
              label: const Text(
                'OK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Virer de l\'argent'),
          backgroundColor: const Color(0xFF18191A),
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: const Color(0xFF18191A),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Rafraîchir les données',
            ),
            IconButton(
              icon: const Icon(Icons.cloud_download),
              onPressed: _forceRefreshFromFirebase,
              tooltip: 'Recharger depuis Firebase',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _buildVirerArgentContent(context),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virer de l\'argent'),
        backgroundColor: const Color(0xFF18191A),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: const Color(0xFF18191A),
      ),
      body: _buildVirerArgentContent(context),
    );
  }

  Widget _buildVirerArgentContent(BuildContext context) {
    return StreamBuilder<List<Compte>>(
      key: ValueKey('comptes_$_refreshKey'),
      stream: PocketBaseService.lireComptes(),
      builder: (context, comptesSnapshot) {
        if (comptesSnapshot.hasError) {
          return Center(
            child: Text(
              'Erreur : ${comptesSnapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!comptesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        
        return StreamBuilder<List<Categorie>>(
          key: ValueKey('categories_$_refreshKey'),
          stream: PocketBaseService.lireCategories(),
          builder: (context, catSnapshot) {
            if (catSnapshot.hasError) {
              return Center(
                child: Text(
                  'Erreur : ${catSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!comptesSnapshot.hasData || !catSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            
            final comptes = comptesSnapshot.data!;
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: PocketBaseService.lireToutesEnveloppes(),
              builder: (context, enveloppesSnapshot) {
                if (enveloppesSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur enveloppes: ${enveloppesSnapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!enveloppesSnapshot.hasData) {
                  return Container();
                }
                
                
                try {
                  final enveloppes = enveloppesSnapshot.data!.map((data) {
                    return Enveloppe.fromMap(data);
                  }).toList();
                  
                  
                  // Vérification des données
                  if (catSnapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucune catégorie trouvée. Vérifiez votre connexion.',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // Filtrer les comptes pour exclure les types 'Dette' et 'Investissement'
                  final comptesFilters = comptes
                      .where(
                        (compte) =>
                            !compte.estArchive &&
                            compte.type != 'Dette' &&
                            compte.type != 'Investissement',
                      )
                      .toList()
                    ..sort(
                        (a, b) => (a.ordre ?? 999999).compareTo(b.ordre ?? 999999));

                  final tout = [...comptesFilters, ...enveloppes];
                  if (tout.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun compte ou enveloppe disponible',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // Initialiser les sélections si nécessaire
                  if (destinationId != null && destination == null) {
                    destination = getSelectedById(destinationId, tout);
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              _montantController.text.isEmpty
                                  ? '0,00 \$'
                                  : '${_montantController.text} \$',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: sourceId,
                                  hint: const Text('Sélectionner une source'),
                                  items: _buildDropdownItems(tout, destinationId,
                                      catSnapshot.data!, comptes),
                                  onChanged: (val) => setState(() {
                                    sourceId = val;
                                    source = getSelectedById(val, tout);
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: destinationId,
                                  hint: const Text('Sélectionner une destination'),
                                  items: _buildDropdownItems(tout, sourceId,
                                      catSnapshot.data!, comptes),
                                  onChanged: (val) => setState(() {
                                    destinationId = val;
                                    destination = getSelectedById(val, tout);
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _peutVirer()
                                          ? Colors.green
                                          : Colors.grey,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    onPressed: _peutVirer() ? _effectuerVirement : null,
                                    child: const Text(
                                      'Virer',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } catch (e, stackTrace) {
                  return Center(
                    child: Text(
                      'Erreur de conversion: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // Méthode pour forcer le rafraîchissement des données
  void _refreshData() {
    // Avec les streams, il suffit de changer la clé pour forcer la reconstruction
    setState(() {
      _refreshKey++;
    });
  }

  // Fonction pour construire les items du dropdown avec séparateurs par catégorie
  List<DropdownMenuItem<String>> _buildDropdownItems(List<dynamic> tout,
      String? excludeId, List<Categorie> categories, List<Compte> comptes) {
    final items = <DropdownMenuItem<String>>[];

    // Ajouter d'abord tous les comptes
    final comptesFiltres =
        tout.where((obj) {
          if (obj is Compte) {
            final objId = getId(obj);
            return objId != excludeId;
          }
          return false;
        }).toList();
    
    
    for (var compte in comptesFiltres) {
      final compteId = getId(compte);
      items.add(DropdownMenuItem(
        value: compteId,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _getNomAvecCouleur(compte, categories, comptes),
            const SizedBox(width: 8),
            Text(
              _getSolde(compte),
              style: TextStyle(
                color: _getSoldeColor(compte, comptes),
              ),
            ),
          ],
        ),
      ));
    }

    // Ajouter les enveloppes groupées par catégorie
    final enveloppes = tout
        .where((obj) {
          if (obj is Enveloppe) {
            final objId = getId(obj);
            return objId != excludeId;
          }
          return false;
        })
        .toList();
    
    
    final categoriesMap = <String, List<Enveloppe>>{};

    // Grouper les enveloppes par catégorie
    for (var enveloppe in enveloppes) {
      final nomCategorie =
          _getNomCategorieEnveloppe(enveloppe as Enveloppe, categories);
      categoriesMap.putIfAbsent(nomCategorie, () => []).add(enveloppe);
    }

    // Ajouter les enveloppes avec séparateurs
    categoriesMap.forEach((nomCategorie, enveloppesCategorie) {
      // Ajouter le séparateur de catégorie
      items.add(DropdownMenuItem<String>(
        value: null, // Valeur null pour le séparateur
        enabled: false, // Désactiver le séparateur
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            nomCategorie,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ));

      // Ajouter les enveloppes de cette catégorie
      for (var enveloppe in enveloppesCategorie) {
        final enveloppeId = getId(enveloppe);
        items.add(DropdownMenuItem(
          value: enveloppeId,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _getNomAvecCouleur(enveloppe, categories, comptes),
                const SizedBox(width: 8),
                Text(
                  _getSolde(enveloppe),
                  style: TextStyle(
                    color: _getSoldeColor(enveloppe, comptes),
                  ),
                ),
              ],
            ),
          ),
        ));
      }
    });

    return items;
  }

  // Fonction pour obtenir le nom de la catégorie d'une enveloppe
  String _getNomCategorieEnveloppe(
      Enveloppe enveloppe, List<Categorie> categories) {
    // Utiliser le categorieId de l'enveloppe pour trouver la catégorie
    final categorie = categories.firstWhere(
      (cat) => cat.id == enveloppe.categorieId,
      orElse: () => Categorie(id: '', utilisateurId: '', nom: 'Catégorie inconnue', ordre: 0),
    );
    return categorie.nom;
  }

  // Fonctions utilitaires pour l'affichage
  Widget _getNomAvecCouleur(
      dynamic obj, List<Categorie> categories, List<Compte> comptes) {
    if (obj is Compte) {
      return RichText(
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: "${obj.nom} -> ",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
                fontSize: 16,
              ),
            ),
            TextSpan(
              text: "Prêt à placer",
              style: TextStyle(
                color: Color(obj.couleur),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } else if (obj is Enveloppe) {
      return Text(
        obj.nom,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16),
      );
    }
    return const Text(
      '',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 16),
    );
  }

  String _getSolde(dynamic obj) {
    double solde = 0;
    if (obj is Compte) {
      solde = obj.pretAPlacer;
    } else if (obj is Enveloppe) {
      solde = obj.solde;
    }
    return '${solde.toStringAsFixed(2)} \$';
  }

  Color _getSoldeColor(dynamic obj, List<Compte> comptes) {
    // Obtenir le solde de l'objet
    double solde = 0.0;
    if (obj is Compte) {
      solde = obj.solde;
    } else if (obj is Enveloppe) {
      solde = obj.solde;
    }

    // Déterminer la couleur par défaut du compte de provenance
    Color couleurDefaut = Colors.grey;
    if (obj is Compte) {
      couleurDefaut = Color(obj.couleur);
    } else if (obj is Enveloppe) {
      // Si c'est une enveloppe, essayer de trouver le compte d'origine
      final compId = obj.provenanceCompteId;
      if (compId.isNotEmpty) {
        final compteProv = comptes.firstWhere(
          (c) => c.id == compId,
          orElse: () => Compte(
            id: '',
            nom: '',
            type: 'Chèque',
            solde: 0,
            couleur: Colors.grey.value,
            pretAPlacer: 0,
            dateCreation: DateTime.now(),
            estArchive: false,
          ),
        );
        couleurDefaut = Color(compteProv.couleur);
      }
    }

    // Utiliser le service de couleur pour appliquer les règles
    return ColorService.getCouleurMontant(solde, couleurDefaut);
  }

  // Méthode alternative pour charger directement depuis Firebase
  Future<void> _forceRefreshFromFirebase() async {
    try {

      // Invalider complètement le cache
      CacheService.invalidateAll();

      // Nettoyer le cache persistant si possible
      try {
        await PersistentCacheService.clearAllCache();
      } catch (e) {
      }

      // Attendre un peu pour s'assurer que l'invalidation est terminée
      await Future.delayed(const Duration(milliseconds: 100));

      // Forcer le rafraîchissement
      setState(() {
        _refreshKey++;
      });

    } catch (e) {
    }
  }
}

class _AmountDisplay extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _AmountDisplay({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
