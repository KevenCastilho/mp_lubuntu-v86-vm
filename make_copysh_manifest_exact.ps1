$ErrorActionPreference = "Stop"

$RepoDir = "C:\v86-linux\export\maniac-linux-jwm"

$OldBaseName = "maniac-linux-jwm.raw"
$ChunkSize = 47185920
$DiskSize = 8589934592
$PartCount = 183

$SourceRevision = "4e4bf556350916a9a5139a4b3756af0971d56f8c"

Set-Location $RepoDir

New-Item -ItemType Directory -Force -Path "disk" | Out-Null

$parts = @()

for ($i = 0; $i -lt $PartCount; $i++) {
    $start = [int64]$i * [int64]$ChunkSize
    $expectedEnd = [Math]::Min($start + $ChunkSize, $DiskSize)

    $oldName = "$OldBaseName-$start-$ChunkSize"
    $newName = "disk/$start-$expectedEnd.img"

    if (!(Test-Path $oldName) -and !(Test-Path $newName)) {
        throw "Parte não encontrada: $oldName nem $newName"
    }

    if ((Test-Path $oldName) -and !(Test-Path $newName)) {
        Write-Host "Movendo: $oldName -> $newName"
        Move-Item -Force $oldName $newName
    }

    $item = Get-Item $newName
    $actualSize = [int64]$item.Length
    $end = $start + $actualSize

    if ($end -ne $expectedEnd) {
        throw "Tamanho/end inválido em $newName. Esperado end=$expectedEnd / Real end=$end / size=$actualSize"
    }

    $sha = (Get-FileHash $newName -Algorithm SHA256).Hash.ToLowerInvariant()

    $parts += [ordered]@{
        path = $newName.Replace("\", "/")
        size = $actualSize
        sha256 = $sha
        start = $start
        end = $end
    }
}

$manifest = [ordered]@{
    format = "maniac-vm-v86-v1"
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    profile = [ordered]@{
        provider = "copy.sh"
        profile_id = "maniac-linux-jwm"
        source_profile_url = "https://copy.sh/v86/?profile=maniac-linux-jwm"
        source_revision = $SourceRevision
    }

    runtime = [ordered]@{
        local_revision = $SourceRevision
    }

    disk = [ordered]@{
        type = "hda"
        base_path = "disk/.img"
        size = $DiskSize
        chunk_size = $ChunkSize
        use_parts = $true
        part_count = $parts.Count
        parts = $parts
    }
}

$manifest | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 "manifest.json"

git add manifest.json .gitattributes disk

Write-Host ""
Write-Host "OK: manifest no padrão copy.sh gerado."
Write-Host "Parts: $($parts.Count)"
Write-Host ""
Write-Host "Primeira parte:"
$parts[0] | ConvertTo-Json
Write-Host ""
Write-Host "Última parte:"
$parts[-1] | ConvertTo-Json
