#!/bin/bash

# Script pour exécuter tous les tests de Toutie_Budget
# Usage: ./scripts/run_tests.sh [options]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
COVERAGE=false
VERBOSE=false
UNIT_ONLY=false
WIDGET_ONLY=false
INTEGRATION_ONLY=false

# Fonction d'aide
show_help() {
    echo "Script de test pour Toutie_Budget"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -c, --coverage          Générer un rapport de couverture"
    echo "  -v, --verbose           Mode verbeux"
    echo "  -u, --unit-only         Exécuter seulement les tests unitaires"
    echo "  -w, --widget-only       Exécuter seulement les tests de widgets"
    echo "  -i, --integration-only  Exécuter seulement les tests d'intégration"
    echo ""
    echo "Exemples:"
    echo "  $0                      Exécuter tous les tests"
    echo "  $0 -c                   Exécuter tous les tests avec couverture"
    echo "  $0 -u -v                Exécuter les tests unitaires en mode verbeux"
    echo "  $0 -w -c                Exécuter les tests de widgets avec couverture"
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -u|--unit-only)
            UNIT_ONLY=true
            shift
            ;;
        -w|--widget-only)
            WIDGET_ONLY=true
            shift
            ;;
        -i|--integration-only)
            INTEGRATION_ONLY=true
            shift
            ;;
        *)
            echo "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fonction pour afficher les messages
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que Flutter est installé
if ! command -v flutter &> /dev/null; then
    error "Flutter n'est pas installé ou n'est pas dans le PATH"
    exit 1
fi

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "pubspec.yaml" ]; then
    error "Ce script doit être exécuté depuis la racine du projet Flutter"
    exit 1
fi

log "Démarrage des tests pour Toutie_Budget..."

# Nettoyer les anciens tests
log "Nettoyage des anciens tests..."
flutter clean
flutter pub get

# Préparer les options de test
TEST_OPTIONS=""
if [ "$VERBOSE" = true ]; then
    TEST_OPTIONS="$TEST_OPTIONS --verbose"
fi

if [ "$COVERAGE" = true ]; then
    TEST_OPTIONS="$TEST_OPTIONS --coverage"
    # Créer le dossier de couverture s'il n'existe pas
    mkdir -p coverage
fi

# Fonction pour exécuter les tests
run_tests() {
    local test_pattern="$1"
    local test_name="$2"
    
    log "Exécution des $test_name..."
    
    if [ "$COVERAGE" = true ]; then
        flutter test $test_pattern $TEST_OPTIONS --coverage-path=coverage/$test_name
    else
        flutter test $test_pattern $TEST_OPTIONS
    fi
    
    if [ $? -eq 0 ]; then
        success "$test_name terminés avec succès"
    else
        error "$test_name ont échoué"
        return 1
    fi
}

# Exécuter les tests selon les options
FAILED_TESTS=0

if [ "$UNIT_ONLY" = true ]; then
    # Tests unitaires seulement
    run_tests "test/models/" "tests unitaires des modèles" || FAILED_TESTS=$((FAILED_TESTS + 1))
    run_tests "test/services/" "tests unitaires des services" || FAILED_TESTS=$((FAILED_TESTS + 1))
elif [ "$WIDGET_ONLY" = true ]; then
    # Tests de widgets seulement
    run_tests "test/widgets/" "tests de widgets" || FAILED_TESTS=$((FAILED_TESTS + 1))
elif [ "$INTEGRATION_ONLY" = true ]; then
    # Tests d'intégration seulement
    run_tests "test/integration/" "tests d'intégration" || FAILED_TESTS=$((FAILED_TESTS + 1))
else
    # Tous les tests
    log "Exécution de tous les tests..."
    
    # Tests unitaires
    run_tests "test/models/" "tests unitaires des modèles" || FAILED_TESTS=$((FAILED_TESTS + 1))
    run_tests "test/services/" "tests unitaires des services" || FAILED_TESTS=$((FAILED_TESTS + 1))
    
    # Tests de widgets
    run_tests "test/widgets/" "tests de widgets" || FAILED_TESTS=$((FAILED_TESTS + 1))
    
    # Tests d'intégration
    run_tests "test/integration/" "tests d'intégration" || FAILED_TESTS=$((FAILED_TESTS + 1))
    
    # Tests existants
    run_tests "test/finances_calculs_test.dart" "tests de calculs financiers" || FAILED_TESTS=$((FAILED_TESTS + 1))
    run_tests "test/widget_test.dart" "tests de widgets par défaut" || FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Générer le rapport de couverture si demandé
if [ "$COVERAGE" = true ]; then
    log "Génération du rapport de couverture..."
    
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        success "Rapport de couverture généré dans coverage/html/"
        log "Ouvrez coverage/html/index.html dans votre navigateur pour voir le rapport"
    else
        warning "genhtml n'est pas installé. Installez lcov pour générer le rapport HTML"
        log "Rapport de couverture brut disponible dans coverage/lcov.info"
    fi
fi

# Résumé final
echo ""
if [ $FAILED_TESTS -eq 0 ]; then
    success "Tous les tests sont passés avec succès ! 🎉"
    exit 0
else
    error "$FAILED_TESTS suite(s) de tests ont échoué"
    exit 1
fi 