import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toutie_budget/services/dette_service.dart';
import 'package:toutie_budget/models/dette.dart';
import '../test_config.dart';

// Générer les mocks
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
  FirebaseAuth,
  User,
])
import 'dette_service_test.mocks.dart';

void main() {
  group('DetteService Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockDettesRef;
    late MockDocumentReference mockDocRef;
    late MockDocumentSnapshot mockDocSnapshot;
    late MockQuerySnapshot mockQuerySnapshot;
    late MockQuery mockQuery;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late DetteService detteService;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockDettesRef = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockDocSnapshot = MockDocumentSnapshot();
      mockQuerySnapshot = MockQuerySnapshot();
      mockQuery = MockQuery();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();

      // Configuration des mocks
      when(mockFirestore.collection('dettes')).thenReturn(mockDettesRef);
      when(mockDettesRef.doc(any)).thenReturn(mockDocRef);
      when(
        mockDettesRef.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(
        mockQuery.where(any, isEqualTo: anyNamed('isEqualTo')),
      ).thenReturn(mockQuery);
      when(
        mockQuery.where(any, isGreaterThan: anyNamed('isGreaterThan')),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(
        mockQuery.snapshots(),
      ).thenAnswer((_) => Stream.value(mockQuerySnapshot));
      when(mockQuerySnapshot.docs).thenReturn([]);

      // Configuration Firebase Auth
      when(mockUser.uid).thenReturn(TestConfig.testUserId);
      when(mockAuth.currentUser).thenReturn(mockUser);

      detteService = DetteService();
    });

    group('Dette Creation', () {
      test('creerDette success', () async {
        // Arrange
        final dette = Dette(
          id: 'test_dette',
          nomTiers: 'Test Tiers',
          montantInitial: 1000.0,
          solde: 1000.0,
          type: 'pret',
          historique: [],
          archive: false,
          dateCreation: DateTime(2025, 1, 1),
          userId: TestConfig.testUserId,
        );

        when(mockDocRef.set(any)).thenAnswer((_) async => null);

        // Act
        await detteService.creerDette(dette);

        // Assert
        verify(mockDocRef.set(any)).called(1);
      });

      test('creerDette without user throws exception', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);
        final dette = Dette(
          id: 'test_dette',
          nomTiers: 'Test Tiers',
          montantInitial: 1000.0,
          solde: 1000.0,
          type: 'pret',
          historique: [],
          archive: false,
          dateCreation: DateTime(2025, 1, 1),
          userId: TestConfig.testUserId,
        );

        // Act & Assert
        expect(() => detteService.creerDette(dette), throwsA(isA<Exception>()));
      });
    });

    group('Dette Retrieval', () {
      test('dettesActives returns empty list when no user', () async {
        // Arrange
        when(mockAuth.currentUser).thenReturn(null);

        // Act
        final stream = detteService.dettesActives();
        final dettes = await stream.first;

        // Assert
        expect(dettes, isEmpty);
      });

      test('dettesActives returns dettes when user exists', () async {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        final detteData = {
          'id': 'test_dette',
          'nomTiers': 'Test Tiers',
          'montantInitial': 1000.0,
          'solde': 800.0,
          'type': 'pret',
          'historique': [],
          'archive': false,
          'dateCreation': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'userId': TestConfig.testUserId,
        };

        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockDoc.data()).thenReturn(detteData);

        // Act
        final stream = detteService.dettesActives();
        final dettes = await stream.first;

        // Assert
        expect(dettes, hasLength(1));
        expect(dettes.first.nomTiers, equals('Test Tiers'));
        expect(dettes.first.type, equals('pret'));
      });

      test('dettesArchivees returns archived dettes', () async {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        final detteData = {
          'id': 'test_dette_archive',
          'nomTiers': 'Test Tiers Archive',
          'montantInitial': 500.0,
          'solde': 0.0,
          'type': 'dette',
          'historique': [],
          'archive': true,
          'dateCreation': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'dateArchivage': Timestamp.fromDate(DateTime(2025, 6, 1)),
          'userId': TestConfig.testUserId,
        };

        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockDoc.data()).thenReturn(detteData);

        // Act
        final stream = detteService.dettesArchivees();
        final dettes = await stream.first;

        // Assert
        expect(dettes, hasLength(1));
        expect(dettes.first.archive, isTrue);
        expect(dettes.first.dateArchivage, isNotNull);
      });
    });

    group('Dette Operations', () {
      test('ajouterMouvement success', () async {
        // Arrange
        final mouvement = MouvementDette(
          id: 'test_mouvement',
          date: DateTime(2025, 1, 15),
          montant: -100.0,
          type: 'remboursement_recu',
          note: 'Test remboursement',
        );

        when(mockDocRef.update(any)).thenAnswer((_) async => null);

        // Act
        await detteService.ajouterMouvement('test_dette', mouvement);

        // Assert
        verify(mockDocRef.update(any)).called(1);
      });

      test('archiverDette success', () async {
        // Arrange
        when(mockDocRef.update(any)).thenAnswer((_) async => null);

        // Act
        await detteService.archiverDette('test_dette');

        // Assert
        verify(mockDocRef.update(any)).called(1);
      });

      test('getDette returns dette when exists', () async {
        // Arrange
        final detteData = {
          'id': 'test_dette',
          'nomTiers': 'Test Tiers',
          'montantInitial': 1000.0,
          'solde': 800.0,
          'type': 'pret',
          'historique': [],
          'archive': false,
          'dateCreation': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'userId': TestConfig.testUserId,
        };

        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(detteData);

        // Act
        final dette = await detteService.getDette('test_dette');

        // Assert
        expect(dette, isNotNull);
        expect(dette!.nomTiers, equals('Test Tiers'));
        expect(dette.solde, equals(800.0));
      });

      test('getDette returns null when not exists', () async {
        // Arrange
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(false);

        // Act
        final dette = await detteService.getDette('test_dette_inexistant');

        // Assert
        expect(dette, isNull);
      });
    });

    group('Remboursement Cascade', () {
      test('effectuerRemboursementCascade success', () async {
        // Arrange
        final mockDoc = MockDocumentSnapshot();
        final detteData = {
          'id': 'test_dette',
          'nomTiers': 'Test Tiers',
          'montantInitial': 1000.0,
          'solde': 800.0,
          'type': 'pret',
          'historique': [],
          'archive': false,
          'dateCreation': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'userId': TestConfig.testUserId,
        };

        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockDoc.data()).thenReturn(detteData);
        when(mockDocRef.update(any)).thenAnswer((_) async => null);

        // Act
        await detteService.effectuerRemboursementCascade(
          'Test Tiers',
          200.0,
          'remboursement_recu',
        );

        // Assert
        verify(mockDocRef.update(any)).called(greaterThan(0));
      });

      test(
        'effectuerRemboursementCascade throws when no dettes found',
        () async {
          // Arrange
          when(mockQuerySnapshot.docs).thenReturn([]);

          // Act & Assert
          expect(
            () => detteService.effectuerRemboursementCascade(
              'Tiers Inexistant',
              200.0,
              'remboursement_recu',
            ),
            throwsA(isA<Exception>()),
          );
        },
      );
    });

    group('Error Handling', () {
      test('handles Firestore errors gracefully', () async {
        // Arrange
        when(mockDocRef.set(any)).thenThrow(
          FirebaseException(plugin: 'firestore', message: 'Test error'),
        );

        final dette = Dette(
          id: 'test_dette',
          nomTiers: 'Test Tiers',
          montantInitial: 1000.0,
          solde: 1000.0,
          type: 'pret',
          historique: [],
          archive: false,
          dateCreation: DateTime(2025, 1, 1),
          userId: TestConfig.testUserId,
        );

        // Act & Assert
        expect(
          () => detteService.creerDette(dette),
          throwsA(isA<FirebaseException>()),
        );
      });
    });
  });
}
