# =============================================================================
#  PROJECT ZOMBOID - MOD TIKANIKLIGI ACICI
#  Coop/Host sunucusu "NormalTermination" ile kapaniyorsa bunu calistirin.
#
#  NE YAPAR:
#   PZ'nin coop sunucusu, Steam istemcisinden AYRI bir atolye kaydi tutar:
#     ...\common\ProjectZomboid\steamapps\workshop\appworkshop_108600.acf
#   Bir mod Steam istemcinizde kurulu oldugu halde bu ayri kayitta "kurulu"
#   olarak isaretli degilse, sunucu onu indirmeye calisir. Ayni modu Steam
#   istemcisi de yonettigi icin kilit catismasi olusur:
#     onItemNotDownloaded result=33  (k_EResultLockingFailed)
#     onItemNotDownloaded result=2   (k_EResultFail)
#   ...ve PZ temizleme kodunda NullPointerException ile coker.
#
#   Bu arac, Steam istemcinizin KENDI kayitlarini kaynak alarak sunucunun
#   kaydini gercege uygun hale getirir ve eksik mod icerigini kopyalar.
#   Hicbir sey indirmez, hicbir seyi uydurmaz.
#
#  GUVENLIK: Degistirmeden once her zaman yedek alir. Oyun aciksa calismaz.
# =============================================================================

$ErrorActionPreference = "Stop"
$APPID = "108600"   # Project Zomboid

function Yaz([string]$m, [string]$renk = "Gray") { Write-Host $m -ForegroundColor $renk }
function Baslik([string]$m) { Write-Host ""; Write-Host $m -ForegroundColor Cyan; Write-Host ("-" * $m.Length) -ForegroundColor DarkCyan }

Clear-Host
Yaz "===============================================================" Yellow
Yaz "  PROJECT ZOMBOID - MOD TIKANIKLIGI ACICI" Yellow
Yaz "===============================================================" Yellow

# ---------------------------------------------------------------- 1) Oyun acik mi
Baslik "1) Oyun kontrolu"
$acik = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "^ProjectZomboid.*\.exe$" -or
    (($_.Name -match "^javaw?\.exe$") -and ($_.CommandLine -match "zombie\.(gameStates\.MainScreenState|network\.GameServer)"))
}
if ($acik) {
    Yaz "  [DUR] Project Zomboid su an ACIK." Red
    Yaz "        Once oyunu tamamen kapatin, sonra tekrar calistirin." Red
    Read-Host "`nCikmak icin Enter"
    exit 1
}
Yaz "  [OK] Oyun kapali." Green

# ---------------------------------------------------------------- 2) Steam bul
Baslik "2) Steam kurulumu araniyor"
$steam = $null
foreach ($k in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam")) {
    try {
        $p = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        $v = if ($p.SteamPath) { $p.SteamPath } elseif ($p.InstallPath) { $p.InstallPath } else { $null }
        if ($v -and (Test-Path $v)) { $steam = $v.Replace("/", "\"); break }
    } catch {}
}
if (-not $steam) {
    foreach ($g in @("C:\Program Files (x86)\Steam", "C:\Program Files\Steam", "D:\Steam", "E:\Steam")) {
        if (Test-Path $g) { $steam = $g; break }
    }
}
if (-not $steam) {
    Yaz "  [HATA] Steam kurulumu bulunamadi." Red
    Read-Host "`nCikmak icin Enter"; exit 1
}
Yaz ("  [OK] Steam: " + $steam) Green

# ---------------------------------------------------------------- 3) Kutuphaneler
Baslik "3) Steam kutuphaneleri taraniyor"
$libs = New-Object System.Collections.Generic.List[string]
$libs.Add($steam)
$lf = Join-Path $steam "steamapps\libraryfolders.vdf"
if (Test-Path $lf) {
    foreach ($line in (Get-Content $lf -Encoding UTF8)) {
        if ($line -match '"path"\s+"(.+?)"') {
            $pth = $matches[1].Replace("\\", "\")
            if ((Test-Path $pth) -and -not $libs.Contains($pth)) { $libs.Add($pth) }
        }
    }
}
foreach ($l in $libs) { Yaz ("  - " + $l) }

# ---------------------------------------------------------------- 4) PZ kurulumu
Baslik "4) Project Zomboid kurulumu araniyor"
$pz = $null
foreach ($l in $libs) {
    $c = Join-Path $l "steamapps\common\ProjectZomboid"
    if (Test-Path $c) { $pz = $c; break }
}
if (-not $pz) {
    Yaz "  [HATA] ProjectZomboid klasoru bulunamadi." Red
    Read-Host "`nCikmak icin Enter"; exit 1
}
Yaz ("  [OK] Oyun: " + $pz) Green

# ---------------------------------------------------------------- 5) Kayit dosyalari
Baslik "5) Atolye kayitlari araniyor"
# Steam istemcisinin kaydi + icerigi (hangi kutuphanede oldugu degisebilir)
$clientAcf = $null; $clientContent = $null
foreach ($l in $libs) {
    $a = Join-Path $l ("steamapps\workshop\appworkshop_" + $APPID + ".acf")
    $c = Join-Path $l ("steamapps\workshop\content\" + $APPID)
    if ((Test-Path $a) -and (Test-Path $c)) { $clientAcf = $a; $clientContent = $c; break }
}
if (-not $clientAcf) {
    Yaz "  [HATA] Steam istemcisinin atolye kaydi bulunamadi." Red
    Yaz "         Once oyuna Steam uzerinden en az bir moda abone olun." Red
    Read-Host "`nCikmak icin Enter"; exit 1
}
Yaz ("  [OK] Istemci kaydi : " + $clientAcf) Green

$serverWs      = Join-Path $pz "steamapps\workshop"
$serverAcf     = Join-Path $serverWs ("appworkshop_" + $APPID + ".acf")
$serverContent = Join-Path $serverWs ("content\" + $APPID)
if (-not (Test-Path $serverAcf)) {
    Yaz "  [BILGI] Sunucunun kendi kaydi henuz olusmamis." Yellow
    Yaz "          Bu normaldir - coop sunucusunu bir kez baslatip kapatin," Yellow
    Yaz "          sonra bu araci tekrar calistirin." Yellow
    Read-Host "`nCikmak icin Enter"; exit 0
}
Yaz ("  [OK] Sunucu kaydi  : " + $serverAcf) Green

# ---------------------------------------------------------------- Yardimci: VDF bolum okuma
function Get-InstalledRecords([string]$acfPath) {
    $ln = [System.IO.File]::ReadAllLines($acfPath, [System.Text.Encoding]::UTF8)
    $s = -1
    for ($i = 0; $i -lt $ln.Length; $i++) { if ($ln[$i] -match '"WorkshopItemsInstalled"') { $s = $i; break } }
    $res = @{}
    if ($s -lt 0) { return $res }
    $d = 0; $e = -1
    for ($i = $s + 1; $i -lt $ln.Length; $i++) {
        if ($ln[$i] -match '\{') { $d++ }
        if ($ln[$i] -match '\}') { $d--; if ($d -eq 0) { $e = $i; break } }
    }
    for ($i = $s; $i -le $e; $i++) {
        if ($ln[$i] -match '^\s*"(\d+)"\s*$') {
            $id = $matches[1]; $blk = @{}
            for ($j = $i + 1; $j -lt [Math]::Min($i + 9, $e); $j++) {
                if ($ln[$j] -match '"(size|timeupdated|manifest)"\s+"(\d+)"') { $blk[$matches[1]] = $matches[2] }
                if ($ln[$j] -match '^\s*\}') { break }
            }
            if ($blk.Count -eq 3) { $res[$id] = $blk }
        }
    }
    return $res
}

# ---------------------------------------------------------------- 6) Sunucunun ihtiyac duydugu modlar
Baslik "6) Sunucunun ihtiyac duydugu modlar belirleniyor"
# ONEMLI: Kapsam SADECE sunucu .ini dosyalarindaki WorkshopItems= listesidir.
# Sunucunun atolye kaydinda, artik kullanilmayan eski yapilandirmalardan
# kalma yuzlerce MB'lik oge bulunabilir; onlari da "eksik" sayip kopyalamak
# gereksiz yere disk doldurur. Sadece sunucunun GERCEKTEN istedigi modlar
# duzeltilir.
$gerekli = New-Object System.Collections.Generic.HashSet[string]
$iniSayisi = 0
$srvDir = Join-Path $env:USERPROFILE "Zomboid\Server"
if (Test-Path $srvDir) {
    foreach ($ini in (Get-ChildItem $srvDir -Filter "*.ini" -File -ErrorAction SilentlyContinue)) {
        foreach ($line in (Get-Content $ini.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($line -match "^WorkshopItems=(.*)$") {
                $iniSayisi++
                foreach ($id in $matches[1].Split(";")) { if ($id -match "^\d+$") { [void]$gerekli.Add($id) } }
            }
        }
    }
}
if ($gerekli.Count -eq 0) {
    Yaz "  [BILGI] Sunucu ayar dosyalarinda WorkshopItems listesi bulunamadi." Yellow
    Yaz "          Coop sunucusunu bir kez baslatmayi deneyin (kapansa bile)," Yellow
    Yaz "          boylece ayar dosyasi olusur; sonra bu araci tekrar calistirin." Yellow
    Read-Host "`nCikmak icin Enter"; exit 0
}
Yaz ("  " + $iniSayisi + " sunucu ayar dosyasindan " + $gerekli.Count + " mod bulundu.")

# ---------------------------------------------------------------- 7) Karsilastirma
Baslik "7) Eksik 'kurulu' kayitlari tespit ediliyor"
$clientRec = Get-InstalledRecords $clientAcf
$serverRec = Get-InstalledRecords $serverAcf
Yaz ("  Istemcide kurulu kaydi olan : " + $clientRec.Count)
Yaz ("  Sunucuda kurulu kaydi olan  : " + $serverRec.Count)

$eksik = New-Object System.Collections.Generic.List[string]
foreach ($id in $gerekli) {
    if ($serverRec.ContainsKey($id)) { continue }
    if (-not $clientRec.ContainsKey($id)) { continue }   # istemcide de yoksa dokunamayiz
    $eksik.Add($id)
}
Yaz ("  DUZELTILEBILIR eksik kayit  : " + $eksik.Count) $(if ($eksik.Count -gt 0) { "Yellow" } else { "Green" })

$icerikEksik = New-Object System.Collections.Generic.List[string]
foreach ($id in $gerekli) {
    $sc = Join-Path $serverContent $id
    $cc = Join-Path $clientContent $id
    if ((-not (Test-Path $sc)) -and (Test-Path $cc)) { $icerikEksik.Add($id) }
}
Yaz ("  Kopyalanacak eksik icerik   : " + $icerikEksik.Count) $(if ($icerikEksik.Count -gt 0) { "Yellow" } else { "Green" })

$serverRaw = [System.IO.File]::ReadAllText($serverAcf, [System.Text.Encoding]::UTF8)
$askidaSayisi = ([regex]::Matches($serverRaw, '"(BytesDownloaded|BytesToDownload)"')).Count
$durumBozuk = ($serverRaw -match '"NeedsUpdate"\s+"1"') -or
              ($serverRaw -match '"NeedsDownload"\s+"1"') -or
              ($askidaSayisi -gt 0)
Yaz ("  Askida kalan durum isareti  : " + $askidaSayisi) $(if ($durumBozuk) { "Yellow" } else { "Green" })

if ($eksik.Count -eq 0 -and $icerikEksik.Count -eq 0 -and -not $durumBozuk) {
    Yaz ""
    Yaz "  Duzeltilecek bir sey yok - kayitlar zaten tutarli." Green
    Yaz "  Sunucu hala acilmiyorsa sorun baska bir yerde." Green
    Read-Host "`nCikmak icin Enter"; exit 0
}

# ---------------------------------------------------------------- 8) Onay
Baslik "8) Onay"
Yaz "  Yapilacaklar:"
if ($icerikEksik.Count -gt 0) { Yaz ("   - " + $icerikEksik.Count + " modun icerigi Steam klasorunden sunucu klasorune KOPYALANACAK") }
if ($eksik.Count -gt 0)       { Yaz ("   - " + $eksik.Count + " mod icin 'kurulu' kaydi EKLENECEK") }
Yaz "   - Askida kalan indirme isaretleri ve genel indirme durumu temizlenecek"
Yaz "   - Sunucunun indirme/onbellek klasorleri yeniden hazirlanacak"
Yaz "   - Once tam yedek alinacak"
Yaz ""
Yaz "  Hicbir sey internetten indirilmez." DarkGray
$onay = Read-Host "  Devam edilsin mi? (E/H)"
if ($onay -notmatch "^[EeYy]") { Yaz "  Iptal edildi." Yellow; Read-Host "`nCikmak icin Enter"; exit 0 }

# ---------------------------------------------------------------- 9) Yedek
Baslik "9) Yedekleniyor"
$yedek = Join-Path ([Environment]::GetFolderPath("Desktop")) ("PZ_AtolyeKayit_Yedek_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force -Path $yedek | Out-Null
Copy-Item $serverAcf (Join-Path $yedek ("appworkshop_" + $APPID + ".acf")) -Force
Yaz ("  [OK] " + $yedek) Green

# ---------------------------------------------------------------- 10) Icerik kopyalama
if ($icerikEksik.Count -gt 0) {
    Baslik "10) Eksik mod icerigi kopyalaniyor"
    $n = 0
    foreach ($id in $icerikEksik) {
        $n++
        Write-Progress -Activity "Mod icerigi kopyalaniyor" -Status ($id + "  (" + $n + "/" + $icerikEksik.Count + ")") -PercentComplete (($n / $icerikEksik.Count) * 100)
        $src = Join-Path $clientContent $id
        $dst = Join-Path $serverContent $id
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        & robocopy $src $dst "/MIR" "/NFL" "/NDL" "/NJH" "/NJS" "/R:1" "/W:1" | Out-Null
    }
    Write-Progress -Activity "Mod icerigi kopyalaniyor" -Completed
    Yaz ("  [OK] " + $icerikEksik.Count + " mod kopyalandi.") Green
}

# ---------------------------------------------------------------- 11) Kayit duzeltme
Baslik "11) Sunucu kaydi duzeltiliyor"
$lines = [System.IO.File]::ReadAllLines($serverAcf, [System.Text.Encoding]::UTF8)
$s = -1
for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match '"WorkshopItemsInstalled"') { $s = $i; break } }
if ($s -lt 0) {
    Yaz "  [HATA] Kayit dosyasinda 'WorkshopItemsInstalled' bolumu yok." Red
    Read-Host "`nCikmak icin Enter"; exit 1
}
$d = 0; $e = -1
for ($i = $s + 1; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '\{') { $d++ }
    if ($lines[$i] -match '\}') { $d--; if ($d -eq 0) { $e = $i; break } }
}

$yeni = New-Object System.Collections.Generic.List[string]
foreach ($id in $eksik) {
    $r = $clientRec[$id]
    $yeni.Add("`t`t`"" + $id + "`"")
    $yeni.Add("`t`t{")
    $yeni.Add("`t`t`t`"size`"`t`t`"" + $r.size + "`"")
    $yeni.Add("`t`t`t`"timeupdated`"`t`t`"" + $r.timeupdated + "`"")
    $yeni.Add("`t`t`t`"manifest`"`t`t`"" + $r.manifest + "`"")
    $yeni.Add("`t`t}")
}

$out = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($i -eq $e -and $yeni.Count -gt 0) { foreach ($x in $yeni) { $out.Add($x) } }
    if ($lines[$i] -match '"(BytesDownloaded|BytesToDownload)"') { continue }   # askida indirme isareti
    if ($lines[$i] -match '^(\s*)"(NeedsUpdate|NeedsDownload)"\s+"[01]"') {
        $out.Add($matches[1] + '"' + $matches[2] + '"' + "`t`t" + '"0"')
        continue
    }
    $out.Add($lines[$i])
}

# Dogrulama: parantez dengesi
$o = 0; $c = 0
foreach ($l in $out) { $o += ([regex]::Matches($l, '\{')).Count; $c += ([regex]::Matches($l, '\}')).Count }
if ($o -ne $c) {
    Yaz ("  [HATA] Kayit dosyasi bozulacakti (parantez " + $o + "/" + $c + ") - DEGISIKLIK YAPILMADI.") Red
    Yaz ("         Yedek: " + $yedek) Red
    Read-Host "`nCikmak icin Enter"; exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($serverAcf, $out, $utf8NoBom)
New-Item -ItemType Directory -Force -Path (Join-Path $serverWs "downloads\$APPID") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $serverWs "temp\$APPID") | Out-Null
Yaz ("  [OK] " + $eksik.Count + " kayit eklendi, askida isaretler ve genel durum temizlendi.") Green
Yaz "  [OK] Indirme/onbellek klasorleri hazirlandi." Green
Yaz ("  [OK] Parantez dengesi dogrulandi (" + $o + "/" + $c + ").") Green

# ---------------------------------------------------------------- Bitis
Baslik "TAMAMLANDI"
Yaz "  Simdi sirasiyla:" White
Yaz "    1. Steam'i tamamen kapatip acin"
Yaz "    2. Project Zomboid'i acin"
Yaz "    3. Coop sunucusunu baslatin"
Yaz ""
Yaz ("  Bir sey ters giderse yedek: " + $yedek) DarkGray
Yaz "  (Yedekteki .acf dosyasini eski yerine kopyalamaniz yeterli)" DarkGray
Read-Host "`nCikmak icin Enter"
