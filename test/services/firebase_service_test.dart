import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:toutie_budget/services/firebase_service.dart';
import 'package:toutie_budget/models/compte.dart';
import 'package:toutie_budget/models/categorie.dart';
import 'package:toutie_budget/models/transaction_model.dart' as app_model;
import 'package:toutie_budget/models/dette.dart';
import '../test_config.dart';

// Générer les mocks
@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
  WriteBatch,
  Transaction,
])
import 'firebase_service_test.mocks.dart';

void main() {
  group('FirebaseService Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockGoogleSignIn mockGoogleSignIn;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockComptesRef;
    late MockCollectionReference mockCategoriesRef;
    late MockCollectionReference mockTiersRef;
    late MockDocumentReference mockDocRef;
    late MockDocumentSnapshot mockDocSnapshot;
    late MockQuerySnapshot mockQuerySnapshot;
    late MockQuery mockQuery;
    late FirebaseService firebaseService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockGoogleSignIn = MockGoogleSignIn();
      mockFirestore = MockFirebaseFirestore();
      mockComptesRef = MockCollectionReference();
      mockCategoriesRef = MockCollectionReference();
      mockTiersRef = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockDocSnapshot = MockDocumentSnapshot();
      mockQuerySnapshot = MockQuerySnapshot();
      mockQuery = MockQuery();

      // Configuration des mocks de base
      when(mockUser.uid).thenReturn(TestConfig.testUserId);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockAuth.authStateChanges).thenAnswer((_) => Stream.value(mockUser));

      // Configuration Firestore
      when(mockFirestore.collection('comptes')).thenReturn(mockComptesRef);
      when(
        mockFirestore.collection('categories'),
      ).thenReturn(mockCategoriesRef);
      when(mockFirestore.collection('tiers')).thenReturn(mockTiersRef);
      when(
        mockFirestore.collection('transactions'),
      ).thenReturn(mockComptesRef); // Réutilisation

      // Configuration des références
      when(mockComptesRef.doc(any)).thenReturn(mockDocRef);
      when(mockCategoriesRef.doc(any)).thenReturn(mockDocRef);
      when(mockTiersRef.doc(any)).thenReturn(mockDocRef);

      // Configuration des requêtes
      when(
        mockComptesRef.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(
        mockCategoriesRef.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(
        mockQuery.snapshots(),
      ).thenAnswer((_) => Stream.value(mockQuerySnapshot));
      when(mockQuerySnapshot.docs).thenReturn([]);
    });

    group('Authentication', () {
      test('signInWithGoogle success', () async {
        // Arrange
        final mockGoogleUser = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();
        final mockCredential = MockUserCredential();

        when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
        when(
          mockGoogleUser.authentication,
        ).thenAnswer((_) async => mockGoogleAuth);
        when(mockGoogleAuth.accessToken).thenReturn('test_access_token');
        when(mockGoogleAuth.idToken).thenReturn('test_id_token');
        when(
          mockAuth.signInWithCredential(any),
        ).thenAnswer((_) async => mockCredential);

        // Act
        final result = await firebaseService.signInWithGoogle();

        // Assert
        expect(result, equals(mockCredential));
        verify(mockGoogleSignIn.signIn()).called(1);
        verify(mockAuth.signInWithCredential(any)).called(1);
      });

      test('signOut success', () async {
        // Act
        await firebaseService.signOut();

        // Assert
        verify(mockGoogleSignIn.signOut()).called(1);
        verify(mockAuth.signOut()).called(1);
      });
    });

    group('Comptes Management', () {
      test('ajouterCompte success', () async {
        // Arrange
        final compte = Compte(
          id: 'test_compte',
          nom: 'Test Compte',
          type: 'Chèque',
          solde: 1000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 500.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        // Act
        await firebaseService.ajouterCompte(compte);

        // Assert
        verify(mockDocRef.set(any)).called(1);
      });

      test('ajouterCompte without user throws exception', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);
        final compte = Compte(
          id: 'test_compte',
          nom: 'Test Compte',
          type: 'Chèque',
          solde: 1000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 500.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        // Act & Assert
        expect(
          () => firebaseService.ajouterCompte(compte),
          throwsA(isA<Exception>()),
        );
      });

      test('lireComptes returns empty list when no user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final stream = firebaseService.lireComptes();
        final comptes = await stream.first;

        // Assert
        expect(comptes, isEmpty);
      });

      test('lireComptes returns comptes when user exists', () async {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        final compteData = TestConfig.createTestCompte();

        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockDoc.data()).thenReturn(compteData);
        when(mockDoc.id).thenReturn('test_compte');

        // Act
        final stream = firebaseService.lireComptes();
        final comptes = await stream.first;

        // Assert
        expect(comptes, hasLength(1));
        expect(comptes.first.nom, equals('Compte Test'));
      });
    });

    group('Categories Management', () {
      test('ajouterCategorie success', () async {
        // Arrange
        final categorie = Categorie(
          id: 'test_cat',
          nom: 'Test Catégorie',
          enveloppes: [],
        );

        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        // Act
        await firebaseService.ajouterCategorie(categorie);

        // Assert
        verify(mockDocRef.set(any)).called(1);
      });

      test('lireCategories returns empty list when no user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final stream = firebaseService.lireCategories();
        final categories = await stream.first;

        // Assert
        expect(categories, isEmpty);
      });
    });

    group('Transactions Management', () {
      test('ajouterTransaction success', () async {
        // Arrange
        final transaction = app_model.Transaction(
          id: 'test_trans',
          type: app_model.TypeTransaction.depense,
          typeMouvement: app_model.TypeMouvementFinancier.depenseNormale,
          montant: 100.0,
          compteId: 'test_compte',
          date: DateTime(2025, 1, 1),
          tiers: 'Test Tiers',
          estFractionnee: false,
        );

        when(mockDocRef.set(any)).thenAnswer((_) async => null);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(
          mockDocSnapshot.data(),
        ).thenReturn({'solde': 1000.0, 'pretAPlacer': 500.0});

        // Act
        await firebaseService.ajouterTransaction(transaction);

        // Assert
        verify(mockDocRef.set(any)).called(1);
      });

      test('lireTransactions returns empty list when no user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final stream = firebaseService.lireTransactions('test_compte');
        final transactions = await stream.first;

        // Assert
        expect(transactions, isEmpty);
      });
    });

    group('Tiers Management', () {
      test('ajouterTiers success', () async {
        // Arrange
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(false);
        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        // Act
        await firebaseService.ajouterTiers('Test Tiers');

        // Assert
        verify(mockDocRef.set(any)).called(1);
      });

      test('lireTiers returns empty list when no user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final tiers = await firebaseService.lireTiers();

        // Assert
        expect(tiers, isEmpty);
      });
    });

    group('Error Handling', () {
      test('handles Firestore errors gracefully', () async {
        // Arrange
        when(mockDocRef.set(any)).thenThrow(
          FirebaseException(plugin: 'firestore', message: 'Test error'),
        );

        final compte = Compte(
          id: 'test_compte',
          nom: 'Test Compte',
          type: 'Chèque',
          solde: 1000.0,
          couleur: 0xFF2196F3,
          pretAPlacer: 500.0,
          dateCreation: DateTime(2025, 1, 1),
          estArchive: false,
        );

        // Act & Assert
        expect(
          () => firebaseService.ajouterCompte(compte),
          throwsA(isA<FirebaseException>()),
        );
      });
    });
  });
}
