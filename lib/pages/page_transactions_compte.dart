import 'package:flutter/material.dart';
import 'package:toutie_budget/pages/page_ajout_transaction.dart';
import '../models/compte.dart';
import '../models/transaction_model.dart' as app_model;
import '../models/categorie.dart';
import '../services/firebase_service.dart';

/// Page affichant la liste des transactions d'un compte chèque
class PageTransactionsCompte extends StatelessWidget {
  final Compte compte;
  const PageTransactionsCompte({super.key, required this.compte});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Transactions - ${compte.nom}')),
      body: FutureBuilder<List<Categorie>>(
        future: FirebaseService().lireCategories().first,
        builder: (context, catSnapshot) {
          final enveloppeIdToNom = <String, String>{};
          if (catSnapshot.hasData) {
            for (final cat in catSnapshot.data!) {
              for (final env in cat.enveloppes) {
                enveloppeIdToNom[env.id] = env.nom;
              }
            }
          }
          return StreamBuilder<List<app_model.Transaction>>(
            stream: FirebaseService().lireTransactions(compte.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune transaction pour ce compte',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final transactions = snapshot.data!;

              // DEBUG : Afficher l'id du compte, les compteId/userId des transactions et le userId courant
              print('DEBUG: compte.id = \\${compte.id}');
              for (final t in transactions) {
                print(
                  'DEBUG: transaction compteId = \\${t.compteId}, userId = \\${t.userId}',
                );
              }
              // Afficher le userId courant
              print(
                'DEBUG: userId courant = \\${FirebaseService().auth.currentUser?.uid}',
              );

              // Regrouper les transactions par date (formatée)
              final Map<String, List<app_model.Transaction>>
              transactionsParDate = {};
              for (final t in transactions) {
                final dateStr =
                    '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}';
                transactionsParDate.putIfAbsent(dateStr, () => []).add(t);
              }
              final datesTriees = transactionsParDate.keys.toList()
                ..sort((a, b) => b.compareTo(a)); // dates descendantes

              return ListView(
                children: [
                  // En-tête supprimé
                  for (final date in datesTriees) ...[
                    // Bandeau séparateur compact VISIBLE
                    Container(
                      color: const Color(
                        0xFFB71C1C,
                      ).withAlpha(20), // Remplacement de withOpacity déprécié
                      height: 20, // Hauteur réduite
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.1,
                        ),
                      ),
                    ),
                    ...transactionsParDate[date]!.map((t) {
                      final isDepense = t.type.estDepense;
                      final montantColor = isDepense
                          ? Colors.red
                          : Colors.green;
                      String sousTitre = '';
                      // --- Ajout pour transaction fractionnée ---
                      if (t.estFractionnee == true &&
                          t.sousItems != null &&
                          t.sousItems!.isNotEmpty) {
                        // DEBUG: Afficher les données pour comprendre le problème
                        print('DEBUG Transaction fractionnée:');
                        print('  - tiers: ${t.tiers}');
                        print('  - sousItems: ${t.sousItems}');
                        print('  - enveloppeIdToNom: $enveloppeIdToNom');

                        // Afficher la liste des enveloppes et montants avec format demandé
                        final enveloppesFormatees = t.sousItems!.map((item) {
                          final nomEnv =
                              enveloppeIdToNom[item['enveloppeId']] ??
                              'Enveloppe inconnue';
                          final montant =
                              (item['montant'] as num?)?.toDouble() ?? 0.0;
                          print(
                            '  - Enveloppe: ${item['enveloppeId']} -> $nomEnv, Montant: $montant',
                          );
                          return '$nomEnv - ${montant.toStringAsFixed(0)}\$';
                        }).toList();
                        sousTitre = enveloppesFormatees.join(', ');
                      } else if (t.typeMouvement ==
                          app_model.TypeMouvementFinancier.pretAccorde) {
                        sousTitre = 'Prêt accordé';
                      } else if (t.typeMouvement ==
                          app_model.TypeMouvementFinancier.detteContractee) {
                        sousTitre = 'Dette contractée';
                      } else if (t.typeMouvement ==
                          app_model.TypeMouvementFinancier.remboursementRecu) {
                        sousTitre = 'Remboursement reçu';
                      } else if (t.typeMouvement ==
                          app_model
                              .TypeMouvementFinancier
                              .remboursementEffectue) {
                        sousTitre = 'Remboursement effectué';
                      } else if (t.enveloppeId != null &&
                          t.enveloppeId!.startsWith('pret_')) {
                        sousTitre = '${compte.nom} - prêt à placer';
                      } else if (t.enveloppeId != null &&
                          t.enveloppeId!.isNotEmpty) {
                        sousTitre = enveloppeIdToNom[t.enveloppeId!] ?? '-';
                      } else {
                        sousTitre = '-';
                      }
                      return InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EcranAjoutTransactionRefactored(
                                    comptesExistants: const [],
                                    transactionExistante: t,
                                    modeModification: true,
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withAlpha(
                              (0.08 * 255).toInt(),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade300,
                                width: 0.7,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.tiers != null && t.tiers!.isNotEmpty
                                          ? t.tiers!
                                          : '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        height: 1.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      sousTitre,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        height: 1.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isDepense ? '-' : '+'}${t.montant.toStringAsFixed(2)} \$',
                                style: TextStyle(
                                  color: montantColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
