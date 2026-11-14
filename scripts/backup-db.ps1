[CmdletBinding()]
param(
    [string]$BackupDirectory = (Join-Path $PSScriptRoot "..\backups"),
    [int]$RetentionDays = 14
)

$ErrorActionPreference = "Stop"
if ($RetentionDays -lt 1) { throw "RetentionDays must be at least 1." }

foreach ($name in @("DB_NAME", "DB_USER", "MYSQL_PWD")) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "Environment variable $name is required. Never put the database password in script arguments."
    }
}
$dbName = $env:DB_NAME
$dbHost = if ($env:DB_HOST) { $env:DB_HOST } else { "127.0.0.1" }
$dbPort = if ($env:DB_PORT) { $env:DB_PORT } else { "3306" }
$dump = if ($env:MYSQLDUMP_BIN) { $env:MYSQLDUMP_BIN } else { "mysqldump.exe" }

if (-not (Get-Command $dump -ErrorAction SilentlyContinue)) {
    throw "mysqldump was not found: $dump"
}
New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$base = Join-Path $BackupDirectory ("${dbName}_$stamp.sql.gz")
$sqlTemp = Join-Path $BackupDirectory ([guid]::NewGuid().ToString() + ".sql.tmp")
$gzipTemp = "$base.tmp"

try {
    $dumpArgs = @(
        "--host=$dbHost", "--port=$dbPort", "--user=$($env:DB_USER)",
        "--single-transaction", "--quick", "--routines", "--triggers", "--events",
        "--hex-blob", "--default-character-set=utf8mb4", "--no-tablespaces", $dbName
    )
    $process = Start-Process -FilePath $dump -ArgumentList $dumpArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $sqlTemp
    if ($process.ExitCode -ne 0 -or -not (Test-Path $sqlTemp) -or (Get-Item $sqlTemp).Length -eq 0) {
        throw "mysqldump failed with exit code $($process.ExitCode)."
    }

    $inputStream = [IO.File]::OpenRead($sqlTemp)
    try {
        $outputStream = [IO.File]::Create($gzipTemp)
        try {
            $gzip = [IO.Compression.GZipStream]::new($outputStream, [IO.Compression.CompressionLevel]::Optimal)
            try { $inputStream.CopyTo($gzip) } finally { $gzip.Dispose() }
        } finally { $outputStream.Dispose() }
    } finally { $inputStream.Dispose() }

    $verifyInput = [IO.File]::OpenRead($gzipTemp)
    try {
        $verifyGzip = [IO.Compression.GZipStream]::new($verifyInput, [IO.Compression.CompressionMode]::Decompress)
        try {
            $buffer = New-Object byte[] 81920
            while ($verifyGzip.Read($buffer, 0, $buffer.Length) -gt 0) { }
        } finally { $verifyGzip.Dispose() }
    } finally { $verifyInput.Dispose() }

    Move-Item -Force $gzipTemp $base
    $hash = (Get-FileHash -Algorithm SHA256 -Path $base).Hash
    Set-Content -Path "$base.sha256" -Value "$hash  $(Split-Path $base -Leaf)" -Encoding ASCII
    Get-ChildItem -Path $BackupDirectory -Filter "${dbName}_*.sql.gz" -File |
        Where-Object { $_.LastWriteTimeUtc -lt (Get-Date).ToUniversalTime().AddDays(-$RetentionDays) } |
        ForEach-Object { Remove-Item -Force $_.FullName; Remove-Item -Force "$($_.FullName).sha256" -ErrorAction SilentlyContinue }
    Write-Output "Backup verified: $base"
}
finally {
    Remove-Item -Force $sqlTemp, $gzipTemp -ErrorAction SilentlyContinue
}
