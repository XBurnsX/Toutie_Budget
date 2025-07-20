# Script pour démarrer PocketBase
# Assurez-vous d'avoir téléchargé PocketBase depuis https://pocketbase.io/

Write-Host "🚀 Démarrage de PocketBase..." -ForegroundColor Green

# Vérifier si PocketBase existe
$pocketbasePath = ".\pocketbase\pocketbase.exe"
if (-not (Test-Path $pocketbasePath)) {
    Write-Host "❌ PocketBase non trouvé dans .\pocketbase\pocketbase.exe" -ForegroundColor Red
    Write-Host "📁 Vérifiez que PocketBase est dans le dossier pocketbase/" -ForegroundColor Yellow
    exit 1
}

# Démarrer PocketBase
Write-Host "✅ Démarrage de PocketBase sur http://127.0.0.1:8090" -ForegroundColor Green
Write-Host "📊 Interface admin: http://127.0.0.1:8090/_/" -ForegroundColor Cyan
Write-Host "🔄 Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow

try {
    & $pocketbasePath serve
} catch {
    Write-Host "❌ Erreur lors du démarrage de PocketBase: $($_.Exception.Message)" -ForegroundColor Red
} 