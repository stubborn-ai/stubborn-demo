#Requires -Version 5.1
# Host E2E for spring-petclinic-microservices workspace graph.
$ErrorActionPreference = "Stop"

$ExampleRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ExampleRoot "..\..")
$UpstreamRoot = Join-Path $ExampleRoot "upstream"
$PinFile = Join-Path $ExampleRoot "upstream.pin"
$MetadataDir = Join-Path $ExampleRoot "metadata"
$IndexesDir = Join-Path $MetadataDir "indexes"
$BridgeDir = Join-Path $MetadataDir "bridge"
$StubOutputDir = Join-Path $ExampleRoot "stub-output"
$DbPath = Join-Path $MetadataDir "petclinic-workspace.db"
$Workspace = "petclinic-ms"

$Services = @(
    @{ Repo = "api-gateway"; Path = "spring-petclinic-api-gateway"; Index = "api-gateway.scip" },
    @{ Repo = "customers-service"; Path = "spring-petclinic-customers-service"; Index = "customers-service.scip" },
    @{ Repo = "vets-service"; Path = "spring-petclinic-vets-service"; Index = "vets-service.scip" },
    @{ Repo = "visits-service"; Path = "spring-petclinic-visits-service"; Index = "visits-service.scip" }
)

function Read-PinValue([string]$Key) {
    $line = Get-Content $PinFile | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
    if (-not $line) { throw "Missing $Key in upstream.pin" }
    return ($line -split "=", 2)[1].Trim()
}

function Assert-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $Name"
    }
}

$repo = Read-PinValue "repo"
$commit = Read-PinValue "commit"

Write-Host "== spring-petclinic-microservices workspace E2E ==" -ForegroundColor Cyan
Assert-Command git
Assert-Command mvn
Assert-Command scip-java
Assert-Command stubborn
Assert-Command python

if (-not (Test-Path (Join-Path $UpstreamRoot ".git"))) {
    Write-Host "`n[0/8] Clone upstream..." -ForegroundColor Yellow
    git clone --filter=blob:none --no-checkout $repo $UpstreamRoot
    git -C $UpstreamRoot checkout $commit
} else {
    Write-Host "`n[0/8] Use existing upstream at $UpstreamRoot" -ForegroundColor Yellow
    git -C $UpstreamRoot checkout $commit
}

Write-Host "`n[1/8] Maven compile..." -ForegroundColor Yellow
Push-Location $UpstreamRoot
mvn -q -DskipTests package
Pop-Location

New-Item -ItemType Directory -Force -Path $MetadataDir, $IndexesDir, $BridgeDir, $StubOutputDir | Out-Null
if (Test-Path $DbPath) { Remove-Item $DbPath }

Write-Host "`n[2/8] Per-service scip-java indexes..." -ForegroundColor Yellow
foreach ($service in $Services) {
    $serviceRoot = Join-Path $UpstreamRoot $service.Path
    $serviceIndex = Join-Path $serviceRoot "index.scip"
    $targetIndex = Join-Path $IndexesDir $service.Index
    if (Test-Path $serviceIndex) { Remove-Item $serviceIndex }
    Push-Location $serviceRoot
    scip-java index --build-tool maven
    Pop-Location
    Move-Item -Force $serviceIndex $targetIndex
}

Write-Host "`n[3/8] Stubborn workspace indexes..." -ForegroundColor Yellow
foreach ($service in $Services) {
    $indexPath = Join-Path $IndexesDir $service.Index
    $serviceRoot = Join-Path $UpstreamRoot $service.Path
    stubborn index --scip $indexPath --out $DbPath --workspace $Workspace --repo $service.Repo --project-root $serviceRoot
}

Write-Host "`n[4/8] Baseline workspace verification..." -ForegroundColor Yellow
stubborn info $DbPath --workspace $Workspace
python (Join-Path $RepoRoot "scripts\verify_petclinic_ms_workspace.py") --db $DbPath --mode baseline

Write-Host "`n[5/8] Generate HTTP contract bridge..." -ForegroundColor Yellow
$bridgePath = Join-Path $BridgeDir "petclinic-contracts.json"
python (Join-Path $RepoRoot "scripts\generate_petclinic_ms_bridge.py") `
    --db $DbPath `
    --manifest (Join-Path $ExampleRoot "contracts\http.yml") `
    --out $bridgePath

Write-Host "`n[6/8] Index HTTP contract bridge..." -ForegroundColor Yellow
stubborn index --scip $bridgePath --out $DbPath --workspace $Workspace --repo "petclinic-contracts" --project-root $ExampleRoot

Write-Host "`n[7/8] Cross-service context verification..." -ForegroundColor Yellow
python (Join-Path $RepoRoot "scripts\verify_petclinic_ms_workspace.py") --db $DbPath --mode bridged

Write-Host "`n[8/8] Emit sample sidecar stubs..." -ForegroundColor Yellow
python (Join-Path $RepoRoot "scripts\verify_petclinic_ms_workspace.py") --db $DbPath --mode emit-stubs --stub-output $StubOutputDir

Write-Host "`nDone." -ForegroundColor Green
Write-Host "  Upstream : $UpstreamRoot @ $commit"
Write-Host "  SQLite   : $DbPath"
Write-Host "  Bridge   : $bridgePath"
Write-Host "  Stubs    : $StubOutputDir"
