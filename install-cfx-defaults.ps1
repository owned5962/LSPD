param(
    [string]$ResourceRoot = (Join-Path $PSScriptRoot "resources")
)

$ErrorActionPreference = "Stop"
$targetDir = Join-Path $ResourceRoot "[cfx-default]"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cfx-server-data-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempDir "cfx-server-data.zip"

try {
    New-Item -ItemType Directory -Force -Path $tempDir, $ResourceRoot | Out-Null
    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $ResourceRoot -Name "[cfx-default]" | Out-Null
    }
    Write-Host "Téléchargement des ressources officielles citizenfx/cfx-server-data..."
    Invoke-WebRequest -Uri "https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip" -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force

    $sourceDir = Join-Path $tempDir "cfx-server-data-master/resources/[cfx-default]"
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "Le dossier [cfx-default] est absent de l'archive officielle."
    }

    foreach ($resource in @("spawnmanager", "sessionmanager", "hardcap", "baseevents")) {
        $source = Join-Path $sourceDir $resource
        $target = Join-Path $targetDir $resource
        if (Test-Path -LiteralPath (Join-Path $target "fxmanifest.lua")) {
            Write-Host "Déjà installé, conservé : $resource"
            continue
        }
        if (-not (Test-Path -LiteralPath (Join-Path $source "fxmanifest.lua"))) {
            throw "Ressource absente de l'archive officielle : $resource"
        }
        Copy-Item -LiteralPath $source -Destination $targetDir -Recurse
        Write-Host "Installé : $resource"
    }

    Write-Host "Ressources CFX standard prêtes dans : $targetDir" -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}
