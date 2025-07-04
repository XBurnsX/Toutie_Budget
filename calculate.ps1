param (
    [string]$FilePath = 'exemple_csv.csv',
    [string]$DateLimitStr = '22/06/2025',
    [string]$AccountName = 'WealthSimple Cash'
)

try {
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $dateLimit = [datetime]::ParseExact($DateLimitStr, 'dd/MM/yyyy', $null)

    $totalInflow = 0.0
    $totalOutflow = 0.0

    $absolutePath = (Resolve-Path -Path $FilePath).Path

    $csvData = Import-Csv -Path $absolutePath -Encoding UTF8

    foreach ($row in $csvData) {
        if ($row.Account -ne $AccountName) {
            continue
        }

        # On ignore les transactions réconciliées
        if ($row.Cleared -eq 'Reconciled') {
            continue
        }
        
        try {
            $transactionDate = [datetime]::ParseExact($row.Date, 'dd/M/yyyy', $null)

            if ($transactionDate -le $dateLimit) {
                $outflowStr = $row.Outflow -replace '[$\s]', '' -replace ',', '.'
                if (-not [string]::IsNullOrWhiteSpace($outflowStr)) {
                    $totalOutflow += [double]::Parse($outflowStr, $culture)
                }

                $inflowStr = $row.Inflow -replace '[$\s]', '' -replace ',', '.'
                if (-not [string]::IsNullOrWhiteSpace($inflowStr)) {
                    $totalInflow += [double]::Parse($inflowStr, $culture)
                }
            }
        }
        catch {
            # Ignore rows with parsing errors
        }
    }

    $net = $totalInflow - $totalOutflow

    Write-Output "Calcul pour le compte : $AccountName (transactions NON réconciliées uniquement)"
    Write-Output "----------------------------------------------------"
    Write-Output "Total dépenses (Outflow) jusqu'au 22/06/2025 : $($totalOutflow.ToString('F2', $culture)) $"
    Write-Output "Total revenus (Inflow)   jusqu'au 22/06/2025 : $($totalInflow.ToString('F2', $culture)) $"
    Write-Output "----------------------------------------------------"
    Write-Output "Solde Net (revenus - dépenses)                 : $($net.ToString('F2', $culture)) $"

}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
} 