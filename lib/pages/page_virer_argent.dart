import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../services/argent_service.dart';
import '../services/firebase_service.dart';
import '../widgets/numeric_keyboard.dart';

class PageVirerArgent extends StatefulWidget {
  const PageVirerArgent({
    Key? key,
    this.destinationPreselectionnee,
    this.montantPreselectionne,
  }) : super(key: key);

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
  bool _isProcessing = false;

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

  void ajouterChiffre(String chiffre) {
    setState(() {
      if (chiffre == '.') {
        if (montant.isEmpty) {
          montant = '0.';
          return;
        }
        if (montant.contains('.')) return;
        montant += '.';
        return;
      }
      if (chiffre == '0' && montant == '0') return;
      if (montant.contains('.')) {
        final decimales = montant.split('.')[1];
        if (decimales.length >= 2) return;
      }
      if (montant == '0') {
        montant = chiffre;
      } else {
        montant += chiffre;
      }
    });
  }

  void effacer() {
    setState(() {
      if (montant.isNotEmpty) {
        montant = montant.substring(0, montant.length - 1);
      }
    });
  }

  void effacerTout() {
    setState(() {
      montant = '';
    });
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
          textAlign: TextAlign.left,
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

  bool virementPossible() {
    if (montant.isEmpty || source == null || destination == null) return false;
    if (source == destination) return false;
    final double montantDouble =
        double.tryParse(montant.replaceAll(',', '.')) ?? 0;
    if (montantDouble <= 0) return false;
    if (source is Compte) {
      return source.pretAPlacer >= montantDouble;
    } else if (source is Enveloppe) {
      return source.solde >= montantDouble;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Virer de l\'argent')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                      'Erreur : ' +
                          (comptesSnapshot.error?.toString() ?? '') +
                          '\n' +
                          (catSnapshot.error?.toString() ?? ''),
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
                  return solde.toStringAsFixed(2) + ' \$';
                }

                Color getSoldeColor(dynamic obj) {
                  double solde = 0;
                  if (obj is Compte) {
                    solde = obj.pretAPlacer;
                  } else if (obj is Enveloppe) {
                    solde = obj.solde;
                  }

                  if (solde < 0) return Colors.red;
                  if (solde == 0) return Colors.grey;
                  return Colors.green;
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
                        onClear: effacerTout,
                        showDecimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: montant.isNotEmpty ? effacerTout : null,
                            child: const Text('Effacer tout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[100],
                              foregroundColor: Colors.red[900],
                              minimumSize: const Size.fromHeight(40),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: virementPossible() && !_isProcessing
                          ? () async {
                              if (_isProcessing) return;

                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              setState(() {
                                _isProcessing = true;
                              });

                              final argentService = ArgentService();
                              final double montantDouble =
                                  double.tryParse(
                                    montant.replaceAll(',', '.'),
                                  ) ??
                                  0;

                              if (montantDouble <= 0) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Montant invalide'),
                                  ),
                                );
                                setState(() {
                                  _isProcessing = false;
                                });
                                return;
                              }

                              try {
                                if (source == null ||
                                    destination == null ||
                                    montant.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Veuillez remplir tous les champs.',
                                      ),
                                    ),
                                  );
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                  return;
                                }
                                // Vérification préalable de la provenance pour éviter de débiter le compte si refusé
                                if (source is Compte &&
                                    destination is Enveloppe) {
                                  debugPrint(
                                    '[DEBUG] destination brut: ' +
                                        destination.toString(),
                                  );

                                  // Vérifier si l'enveloppe contient déjà de l'argent d'un autre compte
                                  bool peutTransferer = true;
                                  String raisonBlocage = '';

                                  try {
                                    // Si l'enveloppe a des fonds et une provenance définie
                                    if (destination.solde > 0.01 &&
                                        destination
                                            .provenanceCompteId
                                            .isNotEmpty) {
                                      // Vérifier si la provenance correspond au compte source
                                      if (destination.provenanceCompteId !=
                                          source.id) {
                                        peutTransferer = false;
                                        raisonBlocage =
                                            'Provenance différente du compte source';
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      '[DEBUG] Erreur lors de la vérification compte vers enveloppe: $e',
                                    );
                                  }

                                  if (!peutTransferer) {
                                    debugPrint(
                                      '[DEBUG] Blocage compte vers enveloppe: $raisonBlocage',
                                    );
                                    if (!mounted) return;
                                    _afficherMessageErreurMelangeFonds(context);
                                    setState(() {
                                      _isProcessing = false;
                                    });
                                    return;
                                  }

                                  debugPrint(
                                    '[DEBUG] Procéder au virement compte vers enveloppe',
                                  );
                                  await argentService.allouerPretAPlacer(
                                    compte: source,
                                    montant: montantDouble,
                                  );
                                  await argentService.crediterEnveloppe(
                                    enveloppe: destination,
                                    montant: montantDouble,
                                    compteId: source.id,
                                  );
                                } else if (source is Compte &&
                                    destination is Compte) {
                                  await argentService.virementEntreComptes(
                                    source: source,
                                    destination: destination,
                                    montant: montantDouble,
                                  );
                                } else if (source is Enveloppe &&
                                    destination is Compte) {
                                  // Vérification préalable de la provenance pour enveloppe vers compte
                                  debugPrint(
                                    '[DEBUG] Vérification enveloppe vers compte',
                                  );

                                  // Vérifier si l'enveloppe source provient du même compte de destination
                                  bool peutTransferer = true;
                                  String raisonBlocage = '';

                                  try {
                                    // Si l'enveloppe a des fonds et une provenance définie
                                    if (source.solde > 0 &&
                                        source.provenanceCompteId.isNotEmpty) {
                                      // Vérifier si la provenance correspond au compte de destination
                                      if (source.provenanceCompteId !=
                                          destination.id) {
                                        peutTransferer = false;
                                        raisonBlocage =
                                            'Provenance différente du compte de destination';
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      '[DEBUG] Erreur lors de la vérification enveloppe vers compte: $e',
                                    );
                                  }

                                  if (!peutTransferer) {
                                    debugPrint(
                                      '[DEBUG] Blocage enveloppe vers compte: $raisonBlocage',
                                    );
                                    if (!mounted) return;
                                    _afficherMessageErreurMelangeFonds(
                                      context,
                                      isEnveloppeVersCompte: true,
                                    );
                                    setState(() {
                                      _isProcessing = false;
                                    });
                                    return;
                                  }

                                  await argentService.enveloppeVersCompte(
                                    source: source,
                                    destination: destination,
                                    montant: montantDouble,
                                  );
                                } else if (source is Enveloppe &&
                                    destination is Enveloppe) {
                                  // Vérification préalable de la provenance pour enveloppe vers enveloppe
                                  debugPrint(
                                    '[DEBUG] Vérification enveloppe vers enveloppe',
                                  );

                                  // Vérifier s'il y a des provenances incompatibles
                                  bool peutTransferer = true;
                                  String raisonBlocage = '';

                                  try {
                                    // Simuler la vérification comme dans ArgentService
                                    if (source.solde > 0 &&
                                        destination.solde > 0) {
                                      // Si les deux enveloppes ont des fonds, vérifier les provenances
                                      if (source
                                              .provenanceCompteId
                                              .isNotEmpty &&
                                          destination
                                              .provenanceCompteId
                                              .isNotEmpty &&
                                          source.provenanceCompteId !=
                                              destination.provenanceCompteId) {
                                        peutTransferer = false;
                                        raisonBlocage =
                                            'Provenances différentes détectées';
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      '[DEBUG] Erreur lors de la vérification: $e',
                                    );
                                  }

                                  if (!peutTransferer) {
                                    debugPrint(
                                      '[DEBUG] Blocage enveloppe vers enveloppe: $raisonBlocage',
                                    );
                                    if (!mounted) return;
                                    _afficherMessageErreurMelangeFonds(
                                      context,
                                      isEnveloppeVersEnveloppe: true,
                                    );
                                    setState(() {
                                      _isProcessing = false;
                                    });
                                    return;
                                  }

                                  await argentService
                                      .virementEnveloppeVersEnveloppe(
                                        source: source,
                                        destination: destination,
                                        montant: montantDouble,
                                      );
                                }

                                debugPrint(
                                  '[DEBUG] Virement terminé avec succès',
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Virement effectué !'),
                                  ),
                                );

                                // Utiliser le NavigatorState capturé pour éviter le null check sur context
                                navigator.pop();
                              } catch (e) {
                                String messageErreur = e.toString();
                                debugPrint(
                                  '[DEBUG] Exception capturée: $messageErreur',
                                );
                                debugPrint(
                                  '[DEBUG] Type exception: ${e.runtimeType}',
                                );

                                // S'assurer que le setState est appelé AVANT le showDialog pour éviter les problèmes d'affichage
                                setState(() {
                                  _isProcessing = false;
                                });
                                if (!mounted) return;

                                // Gestion spéciale pour les FirebaseException avec message null
                                if (e is FirebaseException &&
                                    (messageErreur.contains('null') ||
                                        messageErreur.isEmpty)) {
                                  debugPrint(
                                    '[DEBUG] FirebaseException avec message null détectée',
                                  );
                                  messageErreur =
                                      "Erreur de synchronisation avec la base de données. Veuillez réessayer.";
                                }

                                // Vérifier si c'est une erreur de mélange de fonds
                                if (messageErreur.contains(
                                      "L'argent de cette enveloppe provient déjà d'un autre compte",
                                    ) ||
                                    messageErreur.contains(
                                      "Impossible de mélanger des fonds provenant de comptes différents",
                                    ) ||
                                    messageErreur.contains(
                                      "Cette enveloppe contient déjà de l'argent d'un autre compte",
                                    )) {
                                  debugPrint(
                                    '[DEBUG] Message de mélange détecté, affichage du popup',
                                  );

                                  // Afficher immédiatement le popup sans délai
                                  if (mounted) {
                                    _afficherMessageErreurMelangeFonds(context);
                                  }
                                } else {
                                  debugPrint(
                                    '[DEBUG] Autre erreur, affichage popup générique',
                                  );

                                  // Afficher immédiatement le popup générique
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        backgroundColor: Colors.grey[900],
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange[400],
                                              size: 30,
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Erreur',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          messageErreur,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                        actions: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                              right: 8,
                                            ),
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.check,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'OK',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orange[700],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 28,
                                                      vertical: 12,
                                                    ),
                                                elevation: 0,
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              } finally {
                                debugPrint(
                                  '[DEBUG] Finally block: _isProcessing = $_isProcessing',
                                );
                                if (_isProcessing)
                                  setState(() {
                                    _isProcessing = false;
                                  });
                              }
                            }
                          : null,
                      child: Text(
                        source == null ||
                                destination == null ||
                                montant.isEmpty ||
                                _isProcessing
                            ? 'Remplir tous les champs'
                            : 'Valider le virement',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (!virementPossible()) const SizedBox.shrink(),
                  ],
                );
              } catch (e, stack) {
                return Center(
                  child: Text(
                    'Exception : ' + e.toString() + '\n' + stack.toString(),
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
