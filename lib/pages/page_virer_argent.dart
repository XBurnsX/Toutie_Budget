import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../services/argent_service.dart';
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';

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
  String montant = '';
  String? sourceId;
  String? destinationId;
  dynamic source;
  dynamic destination;

  @override
  void initState() {
    super.initState();
    // Apply preselection if provided
    if (widget.destinationPreselectionnee != null) {
      destinationId = widget.destinationPreselectionnee;
    }
    if (widget.montantPreselectionne != null) {
      // Format with comma as decimal separator
      montant = widget.montantPreselectionne!
          .toStringAsFixed(2)
          .replaceAll('.', ',');
    }
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

  String getId(dynamic obj) => obj is Compte ? obj.id : (obj as Enveloppe).id;

  bool _peutVirer() {
    // Le bouton est cliquable dès que source et destination sont sélectionnées
    return sourceId != null && destinationId != null;
  }

  Future<void> _effectuerVirement() async {
    if (!_peutVirer()) return;

    // Vérifier d'abord le montant
    if (montant.isEmpty) {
      _afficherErreur('Veuillez saisir un montant.');
      return;
    }

    double montantDouble = double.tryParse(montant.replaceAll(',', '.')) ?? 0;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Virer de l\'argent')),
      body: StreamBuilder<List<Compte>>(
        stream: FirebaseService().lireComptes(),
        builder: (context, comptesSnapshot) {
          return StreamBuilder<List<Categorie>>(
            stream: FirebaseService().lireCategories(),
            builder: (context, catSnapshot) {
              try {
                if (comptesSnapshot.hasError || catSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur : ${comptesSnapshot.error?.toString() ?? ''}\n${catSnapshot.error?.toString() ?? ''}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!comptesSnapshot.hasData || !catSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comptes = comptesSnapshot.data!;
                final enveloppes = catSnapshot.data!
                    .expand((cat) => cat.enveloppes)
                    .toList();

                // Filtrer les comptes pour exclure les types 'Dette' et 'Investissement'
                final comptesFilters = comptes
                    .where(
                      (compte) =>
                          compte.type != 'Dette' &&
                          compte.type != 'Investissement',
                    )
                    .toList();

                final tout = [...comptesFilters, ...enveloppes];
                if (tout.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun compte ou enveloppe disponible',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                // Mettre à jour les objets source et destination
                _updateObjectsFromSelection(tout);
                String getNom(dynamic obj) {
                  if (obj is Compte) {
                    return "${obj.nom} -> Prêt à placer";
                  } else if (obj is Enveloppe) {
                    return obj.nom;
                  }
                  return '';
                }

                Widget getNomAvecCouleur(dynamic obj) {
                  if (obj is Compte) {
                    return RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "${obj.nom} -> ",
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color ??
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

                String getSolde(dynamic obj) {
                  double solde = 0;
                  if (obj is Compte) {
                    solde = obj.pretAPlacer;
                  } else if (obj is Enveloppe) {
                    solde = obj.solde;
                  }
                  return '${solde.toStringAsFixed(2)} \$';
                }

                // Couleur basée sur le compte de provenance
                Color getSoldeColor(dynamic obj) {
                  // Si c'est un compte, on prend directement sa couleur
                  if (obj is Compte) {
                    return Color(obj.couleur);
                  }

                  // Si c'est une enveloppe, essayer de trouver le compte d'origine
                  if (obj is Enveloppe) {
                    // 1) Nouveau système multi-provenances (non exposé dans le modèle)
                    //    -> on ignore pour l'instant faute d'info

                    // 2) Ancien champ unique provenanceCompteId
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
                      return Color(compteProv.couleur);
                    }
                  }

                  // Couleur par défaut
                  return Colors.grey;
                }

                return Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            montant.isEmpty ? '0,00 \$' : '$montant \$',
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
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: sourceId,
                            decoration: const InputDecoration(
                              labelText: 'Source',
                              border: OutlineInputBorder(),
                            ),
                            items: tout
                                .where(
                                  (obj) => getId(obj) != destinationId,
                                ) // Exclure la destination sélectionnée
                                .map<DropdownMenuItem<String>>(
                                  (obj) => DropdownMenuItem(
                                    value: getId(obj),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        getNomAvecCouleur(obj),
                                        const SizedBox(width: 8),
                                        Text(
                                          getSolde(obj),
                                          style: TextStyle(
                                            color: getSoldeColor(obj),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            selectedItemBuilder: (BuildContext context) {
                              return tout
                                  .where((obj) => getId(obj) != destinationId)
                                  .map<Widget>(
                                    (obj) => Row(
                                      children: [
                                        Expanded(child: getNomAvecCouleur(obj)),
                                        Text(
                                          getSolde(obj),
                                          style: TextStyle(
                                            color: getSoldeColor(obj),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList();
                            },
                            onChanged: (val) => setState(() {
                              sourceId = val;
                              source = getSelectedById(val, tout);
                            }),
                          ),
                          if (sourceId != null) const SizedBox.shrink(),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: destinationId,
                            decoration: const InputDecoration(
                              labelText: 'Destination',
                              border: OutlineInputBorder(),
                            ),
                            items: tout
                                .where(
                                  (obj) => getId(obj) != sourceId,
                                ) // Exclure la source sélectionnée
                                .map<DropdownMenuItem<String>>(
                                  (obj) => DropdownMenuItem(
                                    value: getId(obj),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        getNomAvecCouleur(obj),
                                        const SizedBox(width: 8),
                                        Text(
                                          getSolde(obj),
                                          style: TextStyle(
                                            color: getSoldeColor(obj),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            selectedItemBuilder: (BuildContext context) {
                              return tout
                                  .where((obj) => getId(obj) != sourceId)
                                  .map<Widget>(
                                    (obj) => Row(
                                      children: [
                                        Expanded(child: getNomAvecCouleur(obj)),
                                        Text(
                                          getSolde(obj),
                                          style: TextStyle(
                                            color: getSoldeColor(obj),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList();
                            },
                            onChanged: (val) => setState(() {
                              destinationId = val;
                              destination = getSelectedById(val, tout);
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: NumericKeyboard(
                        controller: TextEditingController(text: montant),
                        onValueChanged: (value) {
                          setState(() {
                            montant = value
                                .replaceAll('\$', '')
                                .replaceAll(' ', '');
                          });
                        },
                        showDecimal: true,
                      ),
                    ),
                    // Bouton Virer ajouté
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: _peutVirer() ? _effectuerVirement : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                );
              } catch (e, stack) {
                return Center(
                  child: Text(
                    'Exception : $e\n$stack',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
