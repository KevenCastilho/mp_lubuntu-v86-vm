$ErrorActionPreference = "Stop"

$RepoDir = "C:\v86-linux\export\maniac-linux-jwm"

$OldBaseName = "maniac-linux-jwm.raw"
$DiskDir = "disk\maniac-linux-jwm"
$Ext = "img"

$ChunkSize = 47185920
$DiskSize = 8589934592
$PartCount = 183

$LocalRevision = "4e4bf556350916a9a5139a4b3756af0971d56f8c"

Set-Location $RepoDir

New-Item -ItemType Directory -Force -Path $DiskDir | Out-Null

$parts = @()

for ($i = 0; $i -lt $PartCount; $i++) {
    $start = [int64]$i * [int64]$ChunkSize
    $endExpected = [Math]::Min($start + $ChunkSize, $DiskSize)

    $oldRootName = "$OldBaseName-$start-$ChunkSize"
    $oldDiskName = "disk\$start-$endExpected.img"
    $newName = "$DiskDir\$start-$endExpected.$Ext"

    if (Test-Path $oldRootName) {
        Move-Item -Force $oldRootName $newName
    }
    elseif (Test-Path $oldDiskName) {
        Move-Item -Force $oldDiskName $newName
    }
    elseif (!(Test-Path $newName)) {
        throw "Parte não encontrada: $oldRootName / $oldDiskName / $newName"
    }

    $item = Get-Item $newName
    $actualSize = [int64]$item.Length
    $end = $start + $actualSize

    if ($end -ne $endExpected) {
        throw "Parte inválida: $newName | end esperado=$endExpected | end real=$end | size=$actualSize"
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

# Remove pasta disk antiga se ficar vazia, mas sem apagar disk/maniac-linux-jwm.
Get-ChildItem "disk" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$manifest = [ordered]@{
    format = "maniac-vm-v86-v1"
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    profile = [ordered]@{
        provider = "copy.sh"
        profile_id = "maniac-linux-jwm"
        source_profile_url = "https://copy.sh/v86/?profile=maniac-linux-jwm"
        source_revision = ""
    }

    runtime = [ordered]@{
        local_revision = $LocalRevision
    }

    disk = [ordered]@{
        type = "hda"
        base_path = "disk/maniac-linux-jwm/maniac-linux-jwm.img"
        size = $DiskSize
        chunk_size = $ChunkSize
        use_parts = $true
        part_count = $parts.Count
        parts = $parts
    }

    snapshot = $null
}

$manifest | ConvertTo-Json -Depth 50 | Set-Content -Encoding UTF8 "manifest.json"

git add -A

Write-Host ""
Write-Host "OK: manifest gerado no padrão Android/copy.sh."
Write-Host "Parts: $($parts.Count)"
Write-Host ""
Write-Host "Primeira parte:"
$parts[0] | ConvertTo-Json
Write-Host ""
Write-Host "Última parte:"
$parts[-1] | ConvertTo-Json
