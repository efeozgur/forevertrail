# ForeverTrail_Nav* eklentilerini oyunun AddOns klasörüne bağlar (junction).
# Oyun iç içe klasörlerdeki eklentileri yüklemez; bu üç klasör AddOns'ta üst düzey görünmelidir.
# Kullanım (depo kökünden):  powershell -ExecutionPolicy Bypass -File tools\link_nav_addons.ps1 [-AddOns "C:\...\Interface\AddOns"]
param([string]$AddOns = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns')

$repo = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $AddOns)) { Write-Error "AddOns klasörü yok: $AddOns"; exit 1 }
foreach ($name in 'ForeverTrail_Nav', 'ForeverTrail_Nav_EK', 'ForeverTrail_Nav_Kalimdor') {
    $source = Join-Path $repo $name
    $link = Join-Path $AddOns $name
    if (-not (Test-Path $source)) { Write-Error "Depoda yok: $source"; exit 1 }
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -eq 'Junction') { Write-Output "Zaten bağlı: $name"; continue }
        Write-Error "$link var ve bir bağlantı değil; üzerine yazılmadı."; exit 1
    }
    New-Item -ItemType Junction -Path $link -Target $source | Out-Null
    Write-Output "Bağlandı: $name -> $source"
}
