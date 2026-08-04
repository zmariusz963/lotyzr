<#
.SYNOPSIS
    Wyszukuje najtansze loty Ryanair z Bydgoszczy (BZG) i Warszawy-Modlina (WMI).

.PARAMETER From
    Kody IATA lotnisk wylotu (domyslnie BZG i WMI).

.PARAMETER DateFrom
    Poczatek okresu wyszukiwania (yyyy-MM-dd). Domyslnie dzisiaj.

.PARAMETER DateTo
    Koniec okresu wyszukiwania (yyyy-MM-dd). Domyslnie +90 dni.

.PARAMETER MaxPrice
    Maksymalna cena w PLN (opcjonalnie).

.PARAMETER Top
    Ile najtanszych wynikow pokazac. Domyslnie 20.

.EXAMPLE
    .\tanie-loty.ps1
    .\tanie-loty.ps1 -DateFrom 2026-08-01 -DateTo 2026-08-31 -MaxPrice 150 -Top 10
#>

param(
    [string[]]$From = @('BZG', 'WMI'),
    [string]$DateFrom = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$DateTo = (Get-Date).AddDays(90).ToString('yyyy-MM-dd'),
    [double]$MaxPrice,
    [int]$Top = 20
)

$results = @()

foreach ($airport in $From) {
    $uri = "https://services-api.ryanair.com/farfnd/3/oneWayFares" +
           "?departureAirportIataCode=$airport" +
           "&language=pl&market=pl-pl" +
           "&outboundDepartureDateFrom=$DateFrom" +
           "&outboundDepartureDateTo=$DateTo" +
           "&limit=200"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -ErrorAction Stop
    } catch {
        Write-Warning "Blad pobierania danych dla $airport : $_"
        continue
    }

    foreach ($fare in $resp.fares) {
        $out = $fare.outbound
        if (-not $out) { continue }
        $results += [pscustomobject]@{
            Skad     = $out.departureAirport.name
            Dokad    = $out.arrivalAirport.name
            Kraj     = $out.arrivalAirport.countryName
            Wylot    = [datetime]$out.departureDate
            Cena     = $out.price.value
            Waluta   = $out.price.currencyCode
            Lot      = $out.flightNumber
        }
    }
}

if ($MaxPrice) {
    $results = $results | Where-Object { $_.Cena -le $MaxPrice }
}

$results |
    Sort-Object Cena |
    Select-Object -First $Top |
    Format-Table Skad, Dokad, Kraj, @{N='Wylot';E={$_.Wylot.ToString('yyyy-MM-dd HH:mm')}}, @{N='Cena';E={"$($_.Cena) $($_.Waluta)"}}, Lot -AutoSize
