#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$DemoRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $DemoRoot "..\..")
$ProbeRelativePath = "src/main/java/com/example/orders/service/MergeProbeService.java"
$ProbePath = Join-Path $DemoRoot $ProbeRelativePath
$DbPath = Join-Path $DemoRoot "metadata\symbols.db"
$ProbeDisplayName = "MergeProbeService"
$ProbeAdded = $false
$CleanupComplete = $false

function Assert-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $Name"
    }
}

function Get-GraphState([string]$Path, [string]$DisplayName) {
    $json = python -c @"
import json
import sqlite3

from stubborn.store.reader import list_symbols
from stubborn.store.writer import read_info

db_path = r'''$Path'''
display_name = '$DisplayName'
info = read_info(db_path)
probe_records = list_symbols(db_path, query=display_name, limit=10)
order_records = list_symbols(db_path, query='OrderService', limit=10)

conn = sqlite3.connect(db_path)
row = conn.execute(
    '''
    SELECT relative_path
    FROM scip_symbol
    WHERE display_name = ?
    ORDER BY stable_id
    LIMIT 1
    ''',
    (display_name,),
).fetchone()
conn.close()

print(json.dumps({
    'run_id': info.index_run_id,
    'mode': info.mode,
    'merge_count': info.merge_count,
    'probe_present': any(record.display_name == display_name for record in probe_records),
    'order_service_present': any(record.display_name == 'OrderService' for record in order_records),
    'relative_path': row[0] if row else None,
}))
"@
    return $json | ConvertFrom-Json
}

Write-Host "== orders-demo merge E2E ==" -ForegroundColor Cyan
Assert-Command mvn
Assert-Command scip-java
Assert-Command stubborn
Assert-Command python

if (Test-Path $ProbePath) {
    throw "Refusing to overwrite existing probe source: $ProbePath"
}

Push-Location $DemoRoot
try {
    Write-Host "`n[1/8] Maven compile baseline..." -ForegroundColor Yellow
    mvn -q -DskipTests package

    Write-Host "`n[2/8] scip-java index baseline..." -ForegroundColor Yellow
    if (Test-Path index.scip) { Remove-Item index.scip }
    scip-java index
    if (-not (Test-Path index.scip)) {
        throw "index.scip was not created"
    }

    Write-Host "`n[3/8] stubborn snapshot index..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path metadata | Out-Null
    if (Test-Path $DbPath) { Remove-Item $DbPath }
    stubborn index --scip index.scip --out $DbPath
    stubborn info $DbPath

    $before = Get-GraphState -Path $DbPath -DisplayName $ProbeDisplayName
    if ($before.probe_present) {
        throw "$ProbeDisplayName unexpectedly exists before merge test starts"
    }
    $baselineRunId = [int]$before.run_id

    Write-Host "`n[4/8] Save a new Java source file..." -ForegroundColor Yellow
    $probeSource = @"
package com.example.orders.service;

import org.springframework.stereotype.Service;

@Service
public class MergeProbeService {

    public String probe() {
        return "merge-ok";
    }
}
"@
    $probeSource | Set-Content -Path $ProbePath -Encoding Ascii
    $ProbeAdded = $true

    Write-Host "`n[5/8] Re-index after save..." -ForegroundColor Yellow
    if (Test-Path index.scip) { Remove-Item index.scip }
    scip-java index
    if (-not (Test-Path index.scip)) {
        throw "index.scip was not recreated after adding the probe source"
    }

    Write-Host "`n[6/8] Merge just the changed path..." -ForegroundColor Yellow
    stubborn index --scip index.scip --out $DbPath --merge --paths $ProbeRelativePath
    stubborn info $DbPath

    $after = Get-GraphState -Path $DbPath -DisplayName $ProbeDisplayName
    if (-not $after.probe_present) {
        throw "$ProbeDisplayName was not visible via list_symbols after merge"
    }
    if (-not $after.order_service_present) {
        throw "OrderService disappeared after path-scoped merge"
    }
    if ([int]$after.run_id -ne $baselineRunId) {
        throw "Expected merge to update index_run_id=$baselineRunId, got $($after.run_id)"
    }
    if ($after.mode -ne "merged") {
        throw "Expected merged mode after path-scoped update, got $($after.mode)"
    }
    if ([int]$after.merge_count -lt 1) {
        throw "Expected merge_count >= 1 after merge, got $($after.merge_count)"
    }
    if ($after.relative_path -ne $ProbeRelativePath) {
        throw "Expected $ProbeDisplayName relative_path to be $ProbeRelativePath, got $($after.relative_path)"
    }

    Write-Host "`n[7/8] Delete the temporary source file..." -ForegroundColor Yellow
    Remove-Item $ProbePath

    Write-Host "`n[8/8] Re-index and merge the deletion..." -ForegroundColor Yellow
    if (Test-Path index.scip) { Remove-Item index.scip }
    scip-java index
    stubborn index --scip index.scip --out $DbPath --merge --paths $ProbeRelativePath

    $final = Get-GraphState -Path $DbPath -DisplayName $ProbeDisplayName
    if ($final.probe_present) {
        throw "$ProbeDisplayName still exists after merging the deletion"
    }
    if (-not $final.order_service_present) {
        throw "OrderService disappeared after merge cleanup"
    }
    if ([int]$final.run_id -ne $baselineRunId) {
        throw "Cleanup merge changed index_run_id from $baselineRunId to $($final.run_id)"
    }
    if ([int]$final.merge_count -lt 2) {
        throw "Expected merge_count >= 2 after add/remove cycle, got $($final.merge_count)"
    }
    $CleanupComplete = $true
}
finally {
    if (Test-Path $ProbePath) {
        Remove-Item $ProbePath
    }

    if ($ProbeAdded -and -not $CleanupComplete) {
        Write-Warning "Merge E2E did not finish cleanly; attempting to restore metadata/symbols.db."
        try {
            if (Test-Path index.scip) { Remove-Item index.scip }
            scip-java index
            if (Test-Path $DbPath) {
                stubborn index --scip index.scip --out $DbPath --merge --paths $ProbeRelativePath | Out-Null
            }
        }
        catch {
            Write-Warning "Automatic cleanup failed. Re-run this script or scripts/run-e2e.ps1 to restore metadata/symbols.db."
        }
    }

    Pop-Location
}

Write-Host "`nDone." -ForegroundColor Green
Write-Host "  SQLite graph : $DbPath"
Write-Host "  Source tree  : restored (probe file removed)"
Write-Host "  Verified     : save -> scip-java -> stubborn index --merge -> list_symbols"
