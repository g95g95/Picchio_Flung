param(
    [Parameter(Mandatory = $true)][ValidateSet('installa', 'ferma', 'riavvia', 'controlla')][string]$Azione,
    [string]$Installatore = ''
)
# Generato dalla skill riavvia-servizi. Legge servizio.json accanto a questo file.
#   installa   registra (o aggiorna) le attivita' pianificate all'accensione e le avvia (INSTALLA.bat)
#   ferma      ferma i programmi del repo (FERMA.bat)
#   riavvia    ferma, git pull --ff-only, reinstalla le dipendenze se il codice e' cambiato, riavvia (RIAVVIA.bat)
#   controlla  controlla che i programmi rispondano sulle loro porte
# Contratto AutoDeploy: con AUTODEPLOY=1 non chiede niente, non aspetta tasti, esce con 0 solo se tutto risponde.
# Solo ASCII in questo file: PowerShell 5.1 legge i .ps1 senza BOM con la codepage ANSI.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Qui = $PSScriptRoot
$Root = Split-Path -Parent $Qui
$SpecPath = Join-Path $Qui 'servizio.json'
$Spec = [IO.File]::ReadAllText($SpecPath) | ConvertFrom-Json
$Account = $(if ($Spec.account) { [string]$Spec.account } else { 'SYSTEM' })
$Automatico = [bool]$env:AUTODEPLOY
$Elevato = [bool]$Installatore   # lanciato da questo script dopo l'UAC: la finestra si chiuderebbe da sola
$Programmi = @($Spec.programmi)

# --- Elevazione: tutto tranne "controlla" richiede l'amministratore. AutoDeploy gira gia' come SYSTEM.
if ($Azione -ne 'controlla') {
    $identita = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$identita).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # Il SID di chi installa si passa prima dell'UAC: dopo, l'utente corrente e' l'amministratore.
        $argomenti = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
            '-Azione', $Azione, '-Installatore', $identita.User.Value)
        $p = Start-Process -FilePath powershell.exe -ArgumentList $argomenti -Verb RunAs -Wait -PassThru
        exit $p.ExitCode
    }
}

function Get-NomeAttivita($p) {
    if ($Programmi.Count -eq 1) { [string]$Spec.nome } else { "$($Spec.nome)-$($p.nome)" }
}
function Get-Bat($p) { Join-Path $Qui "avvia-$($p.nome).bat" }
function Get-Cartella($p) {
    if ($p.cartella -and $p.cartella -ne '.') { [IO.Path]::GetFullPath((Join-Path $Root $p.cartella)) } else { $Root }
}

# Percorsi assoluti dei file del comando (python della .venv, script): li contiene la riga di comando del processo.
function Get-Firme($p) {
    $dir = Get-Cartella $p
    foreach ($arg in @($p.comando)) {
        $a = [string]$arg
        if ($a.StartsWith('-')) { continue }
        $pieno = $(if ([IO.Path]::IsPathRooted($a)) { $a } else { [IO.Path]::GetFullPath((Join-Path $dir $a)) })
        if (Test-Path -LiteralPath $pieno -PathType Leaf) { $pieno }
    }
}

function Get-Antenati {
    # Mai fermare chi ci ha lanciato (RIAVVIA.bat, AutoDeploy).
    $tutti = @{}
    foreach ($x in Get-CimInstance Win32_Process) { $tutti[[int]$x.ProcessId] = [int]$x.ParentProcessId }
    $salvi = New-Object 'System.Collections.Generic.HashSet[int]'
    $id = $PID
    while ($id -and $salvi.Add($id) -and $tutti.ContainsKey($id)) { $id = $tutti[$id] }
    , $salvi
}

function Stop-Albero([int[]]$Radici) {
    # Il cmd del ciclo, il python lanciatore della .venv e il python vero sono processi distinti: si ferma l'albero.
    if (-not $Radici) { return }
    $processi = @(Get-CimInstance Win32_Process)
    $salvi = Get-Antenati
    $fermare = New-Object 'System.Collections.Generic.HashSet[int]'
    $coda = New-Object 'System.Collections.Generic.Queue[int]'
    foreach ($r in $Radici) { if (-not $salvi.Contains($r) -and $fermare.Add($r)) { $coda.Enqueue($r) } }
    while ($coda.Count) {
        $padre = $coda.Dequeue()
        foreach ($c in $processi) {
            $figlio = [int]$c.ProcessId
            if ([int]$c.ParentProcessId -eq $padre -and -not $salvi.Contains($figlio) -and $fermare.Add($figlio)) { $coda.Enqueue($figlio) }
        }
    }
    foreach ($id in $fermare) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}

function Stop-Programmi {
    foreach ($p in $Programmi) {
        $t = Get-NomeAttivita $p
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $t }
    }
    $radici = @()
    foreach ($proc in Get-CimInstance Win32_Process) {
        $riga = [string]$proc.CommandLine
        if (-not $riga) { continue }
        foreach ($p in $Programmi) {
            # Il ciclo avvia-<nome>.bat (altrimenti rilancia il programma dopo 30 s) e i processi avviati a mano.
            $segni = @(Get-Bat $p) + @(Get-Firme $p)
            foreach ($s in $segni) {
                if ($riga.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $radici += [int]$proc.ProcessId }
            }
        }
    }
    Stop-Albero ($radici | Select-Object -Unique)
    Start-Sleep -Seconds 1
    foreach ($p in $Programmi) {
        if (-not $p.porta) { continue }
        foreach ($c in @(Get-NetTCPConnection -State Listen -LocalPort ([int]$p.porta) -ErrorAction SilentlyContinue)) {
            $altro = Get-CimInstance Win32_Process -Filter "ProcessId=$($c.OwningProcess)"
            # Non si ferma un processo che non e' riconoscibilmente di questo repo: lo si segnala.
            Write-Warning "La porta $($p.porta) e' ancora occupata da $($altro.Name) (PID $($c.OwningProcess)): non e' di questo repo, non lo fermo."
        }
    }
}

function New-Password {
    $casuali = New-Object byte[] 24
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($casuali) } finally { $rng.Dispose() }
    # Il prefisso soddisfa i criteri di complessita' delle password, se attivi.
    'Sv1!' + [Convert]::ToBase64String($casuali)
}

function Set-Account {
    # Password nuova a ogni installazione: la conserva solo l'attivita' pianificata, in nessun file.
    $password = New-Password
    $sicura = ConvertTo-SecureString $password -AsPlainText -Force
    if (Get-LocalUser -Name $Account -ErrorAction SilentlyContinue) {
        Set-LocalUser -Name $Account -Password $sicura
    } else {
        New-LocalUser -Name $Account -Password $sicura -PasswordNeverExpires -UserMayNotChangePassword `
            -AccountNeverExpires -Description "Servizio $($Spec.nome)" | Out-Null
        Write-Host "Account $Account creato"
    }
    # Fuori da Utenti (S-1-5-32-545, nome tradotto): l'account non entra nel PC ne' in RDP.
    try { Remove-LocalGroupMember -SID 'S-1-5-32-545' -Member $Account -ErrorAction Stop }
    catch { if ($_.FullyQualifiedErrorId -notlike 'MemberNotFound*') { throw } }
    $password
}

function Grant-AccessoBatch {
    # Un'attivita' con utente e password parte solo se l'account ha "Accesso come processo batch".
    # Senza, Windows non la avvia e non scrive niente nei log (ultimo avvio fermo, log vuoti).
    $sid = (Get-LocalUser -Name $Account).SID.Value
    $dir = Join-Path $env:TEMP ('secpol-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        $esportato = Join-Path $dir 'esportato.inf'
        & secedit.exe /export /cfg $esportato /areas USER_RIGHTS /quiet
        if ($LASTEXITCODE -ne 0) { throw "Lettura dei diritti utente non riuscita (secedit $LASTEXITCODE)" }
        $riga = Get-Content -LiteralPath $esportato | Where-Object { $_ -match '^SeBatchLogonRight\s*=' } | Select-Object -First 1
        $attuali = $(if ($riga) { ($riga -split '=', 2)[1].Trim() } else { '' })
        if (($attuali -split '\s*,\s*') -contains "*$sid") { return }
        $nuovi = $(if ($attuali) { "$attuali,*$sid" } else { "*$sid" })
        $modello = Join-Path $dir 'batch.inf'
        Set-Content -LiteralPath $modello -Encoding Unicode -Value @(
            '[Unicode]', 'Unicode=yes', '[Version]', 'signature="$CHICAGO$"', 'Revision=1',
            '[Privilege Rights]', "SeBatchLogonRight = $nuovi")
        & secedit.exe /configure /db (Join-Path $dir 'secedit.sdb') /cfg $modello /areas USER_RIGHTS /quiet
        if ($LASTEXITCODE -ne 0) { throw "Diritto 'accesso come processo batch' non assegnato (secedit $LASTEXITCODE)" }
        Write-Host "Diritto 'accesso come processo batch' assegnato a $Account"
    } finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Icacls([string[]]$Argomenti) {
    & icacls.exe @Argomenti /Q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls $($Argomenti[0]) non riuscito (codice $LASTEXITCODE)" }
}

function Set-Permessi {
    $utente = $(if ($Installatore) { $Installatore } else { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value })
    $servizio = "$env:COMPUTERNAME\$Account"
    Write-Host "Permessi di $Root (puo' richiedere un minuto)..."
    # Niente eredita' dal padre (C:\ da' la modifica a tutti gli Authenticated Users). SID: i nomi dei gruppi sono tradotti.
    Invoke-Icacls @($Root, '/inheritance:r', '/grant:r', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F',
        "*${utente}:(OI)(CI)F", "${servizio}:(OI)(CI)RX")
    foreach ($figlio in Get-ChildItem -LiteralPath $Root -Force) {
        & icacls.exe $figlio.FullName /reset /T /C /Q | Out-Null
    }
    $scrivibili = @('logs') + @($Spec.cartelle_scrivibili | Where-Object { $_ })
    foreach ($c in $scrivibili | Select-Object -Unique) {
        $percorso = Join-Path $Root $c
        New-Item -ItemType Directory -Force -Path $percorso | Out-Null
        Invoke-Icacls @($percorso, '/grant', "${servizio}:(OI)(CI)M")
    }
    # Programmi fuori dal repo: il Python di base di ogni .venv e gli eseguibili con percorso assoluto.
    # C:\Program Files\PythonXY lo legge solo il gruppo Utenti, da cui l'account e' stato tolto.
    $esterni = @()
    foreach ($cfg in Get-ChildItem -LiteralPath $Root -Filter pyvenv.cfg -Recurse -Depth 3 -Force -ErrorAction SilentlyContinue) {
        $home_ = ((Get-Content -LiteralPath $cfg.FullName | Where-Object { $_ -match '^\s*home\s*=' } |
            Select-Object -First 1) -replace '^\s*home\s*=\s*', '').Trim()
        if ($home_) { $esterni += $home_ }
    }
    foreach ($p in $Programmi) {
        $exe = [string]@($p.comando)[0]
        if ([IO.Path]::IsPathRooted($exe)) { $esterni += (Split-Path -Parent $exe) }
    }
    foreach ($e in $esterni | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $e -PathType Container)) { Write-Warning "Cartella $e non trovata"; continue }
        if ($e.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { continue }
        Invoke-Icacls @($e, '/grant', "${servizio}:(OI)(CI)RX")
        Write-Host "Lettura di $e data a $Account"
    }
}

function Register-Attivita([string]$Password) {
    foreach ($p in $Programmi) {
        $nome = Get-NomeAttivita $p
        $azione = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\cmd.exe" `
            -Argument ('/c ""' + (Get-Bat $p) + '""') -WorkingDirectory (Get-Cartella $p)
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $impostazioni = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
        if ($Account -eq 'SYSTEM') {
            $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName $nome -Action $azione -Trigger $trigger -Principal $principal `
                -Settings $impostazioni -Force | Out-Null
        } else {
            Register-ScheduledTask -TaskName $nome -Action $azione -Trigger $trigger -Settings $impostazioni `
                -User "$env:COMPUTERNAME\$Account" -Password $Password -RunLevel Limited -Force | Out-Null
        }
        Write-Host "Attivita' pianificata $nome registrata ($Account)"
    }
    # Impronta di servizio.json: se cambia, RIAVVIA.bat registra di nuovo le attivita'.
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Get-ImprontaPath)) | Out-Null
    Set-Content -LiteralPath (Get-ImprontaPath) -Value (Get-Impronta)
}

function Get-ImprontaPath { Join-Path $env:ProgramData "riavvia-servizi\$($Spec.nome).sha256" }
function Get-Impronta { (Get-FileHash -LiteralPath $SpecPath -Algorithm SHA256).Hash }

function Start-Programmi {
    foreach ($p in $Programmi) {
        $nome = Get-NomeAttivita $p
        if (-not (Get-ScheduledTask -TaskName $nome -ErrorAction SilentlyContinue)) {
            throw "Manca l'attivita' pianificata ${nome}: lanciare INSTALLA.bat"
        }
        Start-ScheduledTask -TaskName $nome
    }
}

function Invoke-Preparazione {
    foreach ($passo in @($Spec.preparazione)) {
        if (-not $passo) { continue }
        $dir = $(if ($passo.cartella -and $passo.cartella -ne '.') { Join-Path $Root $passo.cartella } else { $Root })
        if ($passo.se_manca -and (Test-Path -LiteralPath (Join-Path $dir $passo.se_manca))) { continue }
        $cmd = @($passo.comando)
        Write-Host "> $($cmd -join ' ')   (in $dir)"
        Push-Location -LiteralPath $dir
        try {
            $exe = [string]$cmd[0]
            $resto = @($cmd | Select-Object -Skip 1)
            & $exe @resto
            if ($LASTEXITCODE -ne 0) { throw "$($cmd -join ' ') non riuscito (codice $LASTEXITCODE)" }
        } finally {
            Pop-Location
        }
    }
}

function Update-Codice {
    if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        Write-Host "$Root non e' un repo git: niente aggiornamento"
        return
    }
    $git = @("$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    # La finestra e' elevata (o SYSTEM): senza safe.directory git rifiuta una cartella di un altro utente.
    $gitArgs = @('-c', "safe.directory=$($Root -replace '\\', '/')", '-C', $Root)
    $cambiato = $false
    try {
        if (-not $git) { throw 'Git non trovato' }
        $prima = & $git @gitArgs rev-parse HEAD
        & $git @gitArgs pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull non riuscito (codice $LASTEXITCODE)" }
        $cambiato = (& $git @gitArgs rev-parse HEAD) -ne $prima
        Write-Host $(if ($cambiato) { 'Codice aggiornato' } else { "Codice gia' aggiornato" })
    } catch {
        Write-Warning "Aggiornamento non riuscito: $($_.Exception.Message). Riparto con la versione attuale."
    }
    # Il marcatore resta se la preparazione non finisce: il RIAVVIA.bat successivo la ripete.
    $marcatore = Join-Path $Root 'logs\.preparazione_da_rifare'
    if (-not $cambiato -and -not (Test-Path -LiteralPath $marcatore)) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $marcatore) | Out-Null
    Set-Content -LiteralPath $marcatore -Value (Get-Date -Format s)
    try {
        Invoke-Preparazione
        Remove-Item -LiteralPath $marcatore
    } catch {
        Write-Warning "Preparazione non riuscita: $($_.Exception.Message). Avvio comunque, RIAVVIA.bat la ripete."
    }
}

function Test-Risponde($p) {
    if ($p.controllo) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri ([string]$p.controllo) -TimeoutSec 5 | Out-Null
            return $true
        } catch [System.Net.WebException] {
            # Qualunque risposta HTTP (401, 302, 404...) vuol dire che il programma e' acceso.
            return [bool]$_.Exception.Response
        } catch {
            return $false
        }
    }
    if ($p.porta) {
        $tcp = New-Object Net.Sockets.TcpClient
        try { $tcp.ConnectAsync('127.0.0.1', [int]$p.porta).Wait(3000) -and $tcp.Connected } catch { $false } finally { $tcp.Dispose() }
    } else {
        $null   # niente da controllare: programma senza porta (es. un worker)
    }
}

function Test-Programmi {
    $esiti = @{}
    $scadenza = [DateTime]::UtcNow.AddSeconds(90)
    do {
        foreach ($p in $Programmi) {
            if ($esiti[$p.nome] -eq 'OK') { continue }
            $r = Test-Risponde $p
            $esiti[$p.nome] = $(if ($null -eq $r) { 'OK' } elseif ($r) { 'OK' } else { 'KO' })
        }
        if (@($esiti.Values | Where-Object { $_ -ne 'OK' }).Count -eq 0) { break }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $scadenza)
    $ko = @()
    foreach ($p in $Programmi) {
        $dove = $(if ($p.controllo) { $p.controllo } elseif ($p.porta) { "porta $($p.porta)" } else { 'nessun controllo' })
        Write-Host ('{0,-15} {1}  {2}' -f $p.nome, $dove, $esiti[$p.nome])
        if ($esiti[$p.nome] -ne 'OK') { $ko += $p }
    }
    foreach ($p in $ko) {
        # Un'attivita' che Windows non avvia non scrive log: lo dicono solo ultimo avvio e risultato (da amministratore).
        $t = Get-ScheduledTask -TaskName (Get-NomeAttivita $p) -ErrorAction SilentlyContinue
        if ($t) {
            $i = $t | Get-ScheduledTaskInfo
            Write-Host ("Attivita' {0}: {1}, ultimo avvio {2}, risultato 0x{3:X8}" -f $t.TaskName, $t.State, $i.LastRunTime, $i.LastTaskResult)
        }
        $log = Join-Path $Root "logs\$($p.nome).log"
        if (Test-Path -LiteralPath $log) {
            Write-Host "Ultime righe di ${log}:"
            Get-Content -LiteralPath $log -Tail 15
        } else {
            Write-Host "$log non esiste: il programma non e' mai partito (permessi o diritto di accesso batch?)"
        }
    }
    if ($ko.Count) { throw "Non rispondono: $(($ko | ForEach-Object { $_.nome }) -join ', ')" }
}

function Install-Tutto {
    if ($Root -like '*OneDrive*') { throw "$Root e' in OneDrive: spostare il repo fuori da OneDrive e rilanciare." }
    Stop-Programmi
    Invoke-Preparazione
    $password = ''
    if ($Account -ne 'SYSTEM') {
        $password = Set-Account
        Grant-AccessoBatch
        Set-Permessi
    }
    Register-Attivita $password
    Start-Programmi
    Test-Programmi
}

$errore = $false
try {
    switch ($Azione) {
        'installa' { Install-Tutto }
        'ferma' {
            Stop-Programmi
            Write-Host "Fermi. Ripartono con RIAVVIA.bat o alla prossima accensione del PC."
        }
        'riavvia' {
            Stop-Programmi
            Update-Codice
            $impronta = $(if (Test-Path -LiteralPath (Get-ImprontaPath)) { (Get-Content -LiteralPath (Get-ImprontaPath) -Raw).Trim() } else { '' })
            if ($impronta -ne (Get-Impronta)) {
                Write-Host "servizio.json e' cambiato: registro di nuovo le attivita'"
                Install-Tutto
            } else {
                Start-Programmi
                Test-Programmi
            }
        }
        'controlla' { Test-Programmi }
    }
} catch {
    $errore = $true
    Write-Host ''
    Write-Host "ERRORE: $($_.Exception.Message)" -ForegroundColor Red
}
if ($Elevato -and -not $Automatico) {
    Write-Host ''
    Read-Host 'Premi invio per chiudere' | Out-Null
}
if ($errore) { exit 1 }
exit 0
