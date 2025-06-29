# Script PowerShell pour exécuter tous les tests de Toutie_Budget
# Usage: .\scripts\run_tests.ps1 [options]

param(
    [switch]$Help,
    [switch]$Coverage,
    [switch]$Verbose,
    [switch]$UnitOnly,
    [switch]$WidgetOnly,
    [switch]$IntegrationOnly
)

# Fonction d'aide
function Show-Help {
    Write-Host "Script de test pour Toutie_Budget" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\scripts\run_tests.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Help              Afficher cette aide"
    Write-Host "  -Coverage          Générer un rapport de couverture"
    Write-Host "  -Verbose           Mode verbeux"
    Write-Host "  -UnitOnly          Exécuter seulement les tests unitaires"
    Write-Host "  -WidgetOnly        Exécuter seulement les tests de widgets"
    Write-Host "  -IntegrationOnly   Exécuter seulement les tests d'intégration"
    Write-Host ""
    Write-Host "Exemples:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run_tests.ps1                      Exécuter tous les tests"
    Write-Host "  .\scripts\run_tests.ps1 -Coverage           Exécuter tous les tests avec couverture"
    Write-Host "  .\scripts\run_tests.ps1 -UnitOnly -Verbose  Exécuter les tests unitaires en mode verbeux"
    Write-Host "  .\scripts\run_tests.ps1 -WidgetOnly -Coverage Exécuter les tests de widgets avec couverture"
}

# Fonction pour afficher les messages
function Write-Log {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Afficher l'aide si demandé
if ($Help) {
    Show-Help
    exit 0
}

# Vérifier que Flutter est installé
try {
    $flutterVersion = flutter --version
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter non trouvé"
    }
} catch {
    Write-Error "Flutter n'est pas installé ou n'est pas dans le PATH"
    exit 1
}

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "Ce script doit être exécuté depuis la racine du projet Flutter"
    exit 1
}

Write-Log "Démarrage des tests pour Toutie_Budget..."

# Nettoyer les anciens tests
Write-Log "Nettoyage des anciens tests..."
flutter clean
flutter pub get

# Préparer les options de test
$testOptions = @()
if ($Verbose) {
    $testOptions += "--verbose"
}

if ($Coverage) {
    $testOptions += "--coverage"
    # Créer le dossier de couverture s'il n'existe pas
    if (-not (Test-Path "coverage")) {
        New-Item -ItemType Directory -Path "coverage" | Out-Null
    }
}

# Fonction pour exécuter les tests
function Run-Tests {
    param(
        [string]$TestPattern,
        [string]$TestName
    )
    
    Write-Log "Exécution des $TestName..."
    
    $command = "flutter test $TestPattern"
    if ($testOptions.Count -gt 0) {
        $command += " " + ($testOptions -join " ")
    }
    
    if ($Coverage) {
        $coveragePath = "coverage/$($TestName.Replace(' ', '_').ToLower())"
        $command += " --coverage-path=$coveragePath"
    }
    
    Write-Host "Exécution: $command" -ForegroundColor Gray
    
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$TestName terminés avec succès"
        return $true
    } else {
        Write-Error "$TestName ont échoué"
        return $false
    }
}

# Exécuter les tests selon les options
$failedTests = 0

if ($UnitOnly) {
    # Tests unitaires seulement
    if (-not (Run-Tests "test/models/" "tests unitaires des modèles")) { $failedTests++ }
    if (-not (Run-Tests "test/services/" "tests unitaires des services")) { $failedTests++ }
} elseif ($WidgetOnly) {
    # Tests de widgets seulement
    if (-not (Run-Tests "test/widgets/" "tests de widgets")) { $failedTests++ }
} elseif ($IntegrationOnly) {
    # Tests d'intégration seulement
    if (-not (Run-Tests "test/integration/" "tests d'intégration")) { $failedTests++ }
} else {
    # Tous les tests
    Write-Log "Exécution de tous les tests..."
    
    # Tests unitaires
    if (-not (Run-Tests "test/models/" "tests unitaires des modèles")) { $failedTests++ }
    if (-not (Run-Tests "test/services/" "tests unitaires des services")) { $failedTests++ }
    
    # Tests de widgets
    if (-not (Run-Tests "test/widgets/" "tests de widgets")) { $failedTests++ }
    
    # Tests d'intégration
    if (-not (Run-Tests "test/integration/" "tests d'intégration")) { $failedTests++ }
    
    # Tests existants
    if (-not (Run-Tests "test/finances_calculs_test.dart" "tests de calculs financiers")) { $failedTests++ }
    if (-not (Run-Tests "test/widget_test.dart" "tests de widgets par défaut")) { $failedTests++ }
}

# Générer le rapport de couverture si demandé
if ($Coverage) {
    Write-Log "Génération du rapport de couverture..."
    
    # Vérifier si genhtml est disponible (nécessite lcov sur Windows)
    try {
        $genhtmlVersion = genhtml --version
        if ($LASTEXITCODE -eq 0) {
            genhtml coverage/lcov.info -o coverage/html
            Write-Success "Rapport de couverture généré dans coverage/html/"
            Write-Log "Ouvrez coverage/html/index.html dans votre navigateur pour voir le rapport"
        }
    } catch {
        Write-Warning "genhtml n'est pas installé. Installez lcov pour générer le rapport HTML"
        Write-Log "Rapport de couverture brut disponible dans coverage/lcov.info"
    }
}

# Résumé final
Write-Host ""
if ($failedTests -eq 0) {
    Write-Success "Tous les tests sont passés avec succès ! 🎉"
    exit 0
} else {
    Write-Error "$failedTests suite(s) de tests ont échoué"
    exit 1
} 