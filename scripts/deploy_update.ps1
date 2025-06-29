# Script PowerShell pour automatiser le déploiement de mise à jour
# Usage: .\deploy_update.ps1 -version "1.0.2" -releaseNotes "Correction de bugs"

param(
    [Parameter(Mandatory=$true)]
    [string]$version,
    
    [Parameter(Mandatory=$false)]
    [string]$releaseNotes = "Nouvelle version disponible",
    
    [Parameter(Mandatory=$false)]
    [string]$groups = "testeurs"
)

Write-Host "🚀 Déploiement de la version $version" -ForegroundColor Green

# 1. Mettre à jour la version dans pubspec.yaml
Write-Host "📝 Mise à jour de la version dans pubspec.yaml..." -ForegroundColor Yellow
$pubspecContent = Get-Content "pubspec.yaml" -Raw
$pubspecContent = $pubspecContent -replace 'version: \d+\.\d+\.\d+\+\d+', "version: $version+1"
Set-Content "pubspec.yaml" $pubspecContent

# 2. Build de l'APK
Write-Host "🔨 Build de l'APK..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors du build" -ForegroundColor Red
    exit 1
}

# 3. Upload vers Firebase App Distribution
Write-Host "📤 Upload vers Firebase App Distribution..." -ForegroundColor Yellow
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"

# Vérifier que l'APK existe
if (-not (Test-Path $apkPath)) {
    Write-Host "❌ APK non trouvé à $apkPath" -ForegroundColor Red
    exit 1
}

# Upload vers Firebase App Distribution
./gradlew appDistributionUploadRelease

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors de l'upload vers App Distribution" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Upload réussi vers Firebase App Distribution" -ForegroundColor Green

# 4. Récupérer le lien de téléchargement (à faire manuellement pour l'instant)
Write-Host "🔗 Veuillez récupérer le lien de téléchargement depuis la console Firebase App Distribution" -ForegroundColor Cyan
Write-Host "   Console: https://console.firebase.google.com/project/_/appdistribution" -ForegroundColor Cyan

$apkUrl = Read-Host "Entrez le lien de téléchargement de l'APK"

if ([string]::IsNullOrEmpty($apkUrl)) {
    Write-Host "❌ Lien de téléchargement requis" -ForegroundColor Red
    exit 1
}

# 5. Mettre à jour Firebase Remote Config
Write-Host "⚙️ Mise à jour de Firebase Remote Config..." -ForegroundColor Yellow

# Créer le fichier de configuration Remote Config
$remoteConfigJson = @{
    latest_version = $version
    apk_url = $apkUrl
    release_notes = $releaseNotes
} | ConvertTo-Json

# Sauvegarder la configuration
Set-Content "remote_config_update.json" $remoteConfigJson

Write-Host "📋 Configuration Remote Config créée dans remote_config_update.json" -ForegroundColor Green
Write-Host "   Veuillez mettre à jour Firebase Remote Config manuellement avec ces valeurs:" -ForegroundColor Cyan
Write-Host "   - latest_version: $version" -ForegroundColor White
Write-Host "   - apk_url: $apkUrl" -ForegroundColor White
Write-Host "   - release_notes: $releaseNotes" -ForegroundColor White

Write-Host "🎉 Déploiement terminé avec succès!" -ForegroundColor Green
Write-Host "   Les utilisateurs recevront une notification de mise à jour au prochain lancement de l'app" -ForegroundColor Cyan 