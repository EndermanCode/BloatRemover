$names = @(
    "HP Wolf Security"
    "TCO Certified"
    "HP Sure Click Pro Secure Browser"
    "HP Documentation"
    "Amazon.com"
    "Angebote"
    "HP Audio Control"
    "HP Easy Clean"
    "myHP"
    "HP Desktop Support Utilities"
    "Instagram"
    "Messanger"
    "Poly lens"
    "TCO Edge Certified"
    "Micro Offer"
)

$HPBloat = @(
    "myHP"
    "HPDesktopSupportUtilities"
    "HPPCHardwareDiagnosticsWindows"
    "HPEasyClean"
    "HPPrivacySettings"
    "HPAudioControl"
    "HPWolfSecurity"
    "Clipchamp"
)

$DefaultChocoPackages = @(
    [pscustomobject]@{ DisplayName = "Google Chrome"; Id = "googlechrome"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "Adobe Reader"; Id = "adobereader"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "7-Zip"; Id = "7zip"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "Mozilla Firefox"; Id = "firefox"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "TeamViewer Host"; Id = "teamviewer.host"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "Notepad++"; Id = "notepadplusplus"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "HP Support Assistant"; Id = "hpsupportassistant"; Params = $null; AllowLongInstall = $false }
    [pscustomobject]@{ DisplayName = "Microsoft 365 Business"; Id = "office365business"; Params = "/eula:TRUE"; AllowLongInstall = $true }
)

$OsVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
$pathTaskbar = "$env:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\"
$pathStartmenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\"
$ErrorActionPreference = 'Continue'

function Test-Yes {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return $Value.Trim() -match '^(?i:y|yes|ja)$'
}

function Install-ChocoPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Params,
        [switch]$AllowLongInstall
    )

    $args = @("install", $Name, "-y", "--ignore-checksum", "--no-progress", "--limit-output", "--acceptlicense")
    if ($AllowLongInstall) { $args += "--execution-timeout=0" }
    if ($Params) { $args += @("--params", $Params) }

    Write-Host "Installing $Name..."
    & choco @args
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Chocolatey install failed for $Name (exit code $LASTEXITCODE)."
    }
}

function Remove-ApplicationsTaskbar {

    foreach ($name in $names) {
        $name = $name.Trim()
        $packages += Get-AppxPackage | where name -match $name | Select-Object -ExpandProperty Name | Out-String
        $packages = $packages.Trim()
        Remove-Item "$pathTaskbar$name.lnk"
    }
    Remove-ItemProperty -Name FavoritesRemovedChanges -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\ -Force
    Taskkill -F -IM Explorer.exe
    start Explorer.exe

    foreach ($package in $HPBloat) {
        Get-AppxPackage *$package* | Remove-AppxPackage
    }

}

function Remove-ApplicationsStartMenu {
    
    foreach ($name in $names) {
        $temp = Get-ChildItem -Path $pathStartmenu -Recurse | where name -match $name| Select-Object -ExpandProperty DirectoryName | Out-String
        $temp = $temp.Trim()
        Remove-Item "$temp\$name.lnk"
    }
}

function Install-DefaultApps {
    Write-Host "installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    if (Test-Path "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1") {
        Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -Force
        refreshenv
    }
    foreach ($package in $DefaultChocoPackages) {
        $installArguments = @{ Name = $package.Id }
        if ($package.Params) { $installArguments.Params = $package.Params }
        if ($package.AllowLongInstall) { $installArguments.AllowLongInstall = $true }
        Install-ChocoPackage @installArguments
    }
}

function Show-ChocoPackageList {
    Write-Status -Type Info -Message "Diese Chocolatey-Pakete werden bei 'Standard-Apps installieren' der Reihe nach installiert:"
    Write-Host ""

    for ($index = 0; $index -lt $DefaultChocoPackages.Count; $index++) {
        $package = $DefaultChocoPackages[$index]
        Write-Host ("  {0,2}. {1}  [{2}]" -f ($index + 1), $package.DisplayName, $package.Id) -ForegroundColor White
    }
}

function Install-Updates {

    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Import-Module PSWindowsUpdate
    }

    else {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Install-Module -Name PSWindowsUpdate -Scope CurrentUser -Force -Confirm:$false
        Import-Module PSWindowsUpdate
    }
    Get-WindowsUpdate
    Install-WindowsUpdate -AcceptAll -IgnoreReboot
}

function Remove-HPBloat {
    Write-Status -Type Info -Message "HP-Software wird ermittelt. HP Support Assistant und seine Support-Frameworks bleiben erhalten."

    # Mehrere Durchlaeufe sind absichtlich: Manche HP-Deinstallationen legen nachgelagerte
    # Komponenten erst frei, nachdem das Hauptprodukt entfernt wurde.
    for ($pass = 1; $pass -le 3; $pass++) {
        $provisionedPackages = @(Get-HPProvisionedPackages)
        $installedPackages = @(Get-HPAppxPackages)
        $installedPrograms = @(Get-HPInstalledPrograms)
        $candidateCount = $provisionedPackages.Count + $installedPackages.Count + $installedPrograms.Count

        if ($candidateCount -eq 0) { break }

        Write-Status -Type Info -Message ("HP-Durchlauf {0}: {1} provisionierte Apps, {2} installierte Apps, {3} Desktop-Programme." -f $pass, $provisionedPackages.Count, $installedPackages.Count, $installedPrograms.Count)

        foreach ($package in $provisionedPackages) {
            Write-Host "  Entferne provisionierte App: $($package.DisplayName)"
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -AllUsers -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Status -Type Warning -Message "Provisionierte App '$($package.DisplayName)' konnte nicht entfernt werden: $($_.Exception.Message)"
            }
        }

        foreach ($package in $installedPackages) {
            Write-Host "  Entferne Store-App: $($package.Name)"
            try {
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
            }
            catch {
                # Auf aelteren Windows-Builds steht -AllUsers nicht immer verlaesslich zur
                # Verfuegung. Der zweite Versuch entfernt zumindest das aktuelle Benutzerpaket.
                try {
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                }
                catch {
                    Write-Status -Type Warning -Message "Store-App '$($package.Name)' konnte nicht entfernt werden: $($_.Exception.Message)"
                }
            }
        }

        foreach ($program in $installedPrograms) {
            Invoke-HPProgramUninstall -Program $program
        }
    }

    Remove-HPDocumentation
    Remove-HPOrphans

    $remainingProvisioned = @(Get-HPProvisionedPackages)
    $remainingPackages = @(Get-HPAppxPackages)
    $remainingPrograms = @(Get-HPInstalledPrograms)
    $remaining = $remainingProvisioned.Count + $remainingPackages.Count + $remainingPrograms.Count

    if ($remaining -gt 0) {
        $remainingNames = @(
            $remainingProvisioned | ForEach-Object { $_.DisplayName }
            $remainingPackages | ForEach-Object { $_.Name }
            $remainingPrograms | ForEach-Object { $_.DisplayName }
        ) | Sort-Object -Unique
        Write-Status -Type Warning -Message "Einige HP-Komponenten melden sich weiterhin als installiert: $($remainingNames -join ', ')"
        throw "$remaining HP-Komponente(n) konnten nicht vollstaendig entfernt werden. Details stehen oben im Protokoll."
    }

    Write-Status -Type Success -Message "HP-Software wurde entfernt; HP Support Assistant und seine Support-Frameworks wurden beibehalten."
}

function Test-HPProtectedComponent {
    param([AllowNull()][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    return $Name -match '(?i)(HP\s*Support\s*Assistant|HPSupportAssistant|HP\s*Support\s*Solutions\s*Framework|HP\s*Support\s*Framework|HPSF)'
}

function Test-HPDriverOrFirmware {
    param([AllowNull()][string]$Name, [AllowNull()][string]$Path)

    $text = "$Name $Path"
    return $text -match '(?i)(\bdriver\b|firmware|\bBIOS\b|chipset|System32\\drivers)'
}

function Test-HPComponent {
    param(
        [AllowNull()][string]$Name,
        [AllowNull()][string]$Publisher,
        [AllowNull()][string]$Identity
    )

    $text = "$Name $Publisher $Identity"
    if (Test-HPProtectedComponent -Name $text) { return $false }
    if (Test-HPDriverOrFirmware -Name $Name -Path $Identity) { return $false }

    return (
        $Name -match '(?i)(^|[\s._-])HP($|[\s._-])|Hewlett[ -]Packard|^myHP$|^AD2F1837\.|HPAudioControl|HPWolfSecurity' -or
        $Publisher -match '(?i)(^|\b)(HP Inc\.?|Hewlett[ -]Packard|HP Development Company|Poly)(\b|$)' -or
        $Identity -match '(?i)(^|[\\._-])HP($|[\\._-])|AD2F1837|Hewlett[ -]Packard'
    )
}

function Get-HPAppxPackages {
    @(
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object {
                Test-HPComponent -Name $_.Name -Publisher $_.PublisherDisplayName -Identity $_.PackageFamilyName
            } |
            Sort-Object PackageFullName -Unique
    )
}

function Get-HPProvisionedPackages {
    @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {
                Test-HPComponent -Name $_.DisplayName -Publisher $_.PublisherId -Identity $_.PackageName
            } |
            Sort-Object PackageName -Unique
    )
}

function Get-HPInstalledPrograms {
    $uninstallRoots = @(
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $userSids = @(
        Get-ChildItem -Path 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^S-1-5-21-' } |
            Select-Object -ExpandProperty PSChildName
    )
    foreach ($sid in $userSids) {
        $uninstallRoots += "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $uninstallRoots += "Registry::HKEY_USERS\$sid\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }

    $programs = foreach ($root in $uninstallRoots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.DisplayName) -and
                (Test-HPComponent -Name $_.DisplayName -Publisher $_.Publisher -Identity "$($_.InstallLocation) $($_.PSChildName)")
            }
    }

    @($programs | Sort-Object PSPath -Unique)
}

function Invoke-HPProgramUninstall {
    param([Parameter(Mandatory)]$Program)

    $name = $Program.DisplayName
    $command = $Program.QuietUninstallString
    $productCode = if ($Program.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') { $Program.PSChildName } else { $null }

    if ($productCode) {
        $filePath = 'msiexec.exe'
        $arguments = "/x $productCode /qn /norestart"
    }
    else {
        if ([string]::IsNullOrWhiteSpace($command)) { $command = $Program.UninstallString }
        if ([string]::IsNullOrWhiteSpace($command)) {
            Write-Status -Type Warning -Message "Fuer '$name' wurde kein Deinstallationsbefehl gefunden."
            return
        }

        if ($command -match '(?i)msiexec(?:\.exe)?\s+.*?(\{[0-9A-F-]{36}\})') {
            $filePath = 'msiexec.exe'
            $arguments = "/x $($Matches[1]) /qn /norestart"
        }
        else {
            $filePath = "$env:SystemRoot\System32\cmd.exe"
            if ($command -notmatch '(?i)(/quiet|/qn|/silent|/verysilent|/s(?:\s|$))') {
                $command += ' /quiet /norestart'
            }
            $arguments = @('/d', '/s', '/c', $command)
        }
    }

    Write-Host "  Deinstalliere Desktop-Programm: $name"
    try {
        $process = Start-Process -FilePath $filePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($process.ExitCode -notin @(0, 1605, 1614, 1641, 3010)) {
            Write-Status -Type Warning -Message "Deinstallation von '$name' endete mit Exitcode $($process.ExitCode)."
        }
    }
    catch {
        Write-Status -Type Warning -Message "Deinstallation von '$name' ist fehlgeschlagen: $($_.Exception.Message)"
    }
}

function Remove-HPDocumentation {
    $uninstaller = 'C:\Program Files\HP\Documentation\Doc_uninstall.cmd'
    if (-not (Test-Path -LiteralPath $uninstaller)) { return }

    Write-Host "  Entferne HP Documentation"
    try {
        $command = '"' + $uninstaller + '"'
        $process = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList @('/d', '/s', '/c', $command) -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            Write-Status -Type Warning -Message "HP Documentation endete mit Exitcode $($process.ExitCode)."
        }
    }
    catch {
        Write-Status -Type Warning -Message "HP Documentation konnte nicht entfernt werden: $($_.Exception.Message)"
    }
}

function Remove-HPOrphans {
    Write-Status -Type Info -Message "Verwaiste HP-Dienste, Aufgaben, Verknuepfungen und Produktordner werden bereinigt."

    $services = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
        (Test-HPComponent -Name $_.DisplayName -Publisher '' -Identity "$($_.Name) $($_.PathName)") -and
        -not (Test-HPDriverOrFirmware -Name $_.DisplayName -Path $_.PathName)
    })
    foreach ($service in $services) {
        try {
            if ($service.State -ne 'Stopped') {
                Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
            }
            & sc.exe delete $service.Name 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1060) {
                Write-Status -Type Warning -Message "Dienst '$($service.DisplayName)' konnte nicht geloescht werden (Exitcode $LASTEXITCODE)."
            }
        }
        catch {
            Write-Status -Type Warning -Message "Dienst '$($service.DisplayName)' konnte nicht bereinigt werden."
        }
    }

    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        Test-HPComponent -Name $_.TaskName -Publisher '' -Identity $_.TaskPath
    })
    foreach ($task in $tasks) {
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Status -Type Warning -Message "Aufgabe '$($task.TaskPath)$($task.TaskName)' konnte nicht geloescht werden."
        }
    }

    $shortcutRoots = @($pathTaskbar, $pathStartmenu, "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
    foreach ($root in ($shortcutRoots | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { (Test-HPComponent -Name $_.BaseName -Publisher '' -Identity $_.FullName) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $productRoots = @(
        "$env:ProgramFiles\HP"
        "${env:ProgramFiles(x86)}\HP"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) }

    foreach ($root in $productRoots) {
        Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
            Where-Object {
                -not (Test-HPProtectedComponent -Name $_.Name) -and
                -not (Test-HPDriverOrFirmware -Name $_.Name -Path $_.FullName)
            } |
            ForEach-Object {
                try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop }
                catch { Write-Status -Type Warning -Message "Rest '$($_.FullName)' konnte nicht geloescht werden." }
            }
    }
}

function Write-Banner {
    param([switch]$NoClear)

    if (-not $NoClear) { Clear-Host }
    try { $Host.UI.RawUI.WindowTitle = "BloatRemover - Windows Setup" } catch {}

    Write-Host ""
    Write-Host "  +============================================================+" -ForegroundColor DarkCyan
    Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
    Write-Host "               B L O A T  R E M O V E R                  " -NoNewline -ForegroundColor Cyan
    Write-Host "|" -ForegroundColor DarkCyan
    Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
    Write-Host "             Windows Setup & Energy Center                " -NoNewline -ForegroundColor Gray
    Write-Host "|" -ForegroundColor DarkCyan
    Write-Host "  +============================================================+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)

    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * $Title.Length)) -ForegroundColor DarkGray
}

function Write-Status {
    param(
        [Parameter(Mandatory)][ValidateSet("Info", "Success", "Warning", "Error")][string]$Type,
        [Parameter(Mandatory)][string]$Message
    )

    $style = switch ($Type) {
        "Success" { @{ Label = " OK "; Color = "Green" } }
        "Warning" { @{ Label = "WARN"; Color = "Yellow" } }
        "Error"   { @{ Label = "FAIL"; Color = "Red" } }
        default   { @{ Label = "INFO"; Color = "Cyan" } }
    }

    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host $style.Label -NoNewline -ForegroundColor $style.Color
    Write-Host "] $Message"
}

function Write-MenuItem {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Label,
        [string]$Hint
    )

    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host $Key -NoNewline -ForegroundColor Yellow
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Label -NoNewline -ForegroundColor White
    if ($Hint) { Write-Host "  $Hint" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Read-MenuChoice {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string[]]$AllowedValues
    )

    do {
        Write-Host ""
        $choice = (Read-Host "  $Prompt").Trim()
        if ($AllowedValues -contains $choice) { return $choice }
        Write-Status -Type Warning -Message "Ungueltige Auswahl. Erlaubt: $($AllowedValues -join ', ')"
    } while ($true)
}

function Read-MultiMenuChoice {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string[]]$AllowedValues,
        [string[]]$AllValues = @()
    )

    do {
        Write-Host ""
        $rawChoice = (Read-Host "  $Prompt").Trim()
        if ($rawChoice -match '^(?i:a|all|alle)$') {
            if ($AllValues.Count -gt 0) { return $AllValues }
        }

        $values = @(
            $rawChoice -split '[,;\s]+' |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        $invalidValues = @($values | Where-Object { $AllowedValues -notcontains $_ })
        if ($values.Count -eq 0 -or $invalidValues.Count -gt 0) {
            Write-Status -Type Warning -Message "Ungueltige Auswahl. Mehrere Werte mit Komma trennen. Erlaubt: $($AllowedValues -join ', '), alle"
            continue
        }
        if ($values.Count -gt 1 -and $values -contains '0') {
            Write-Status -Type Warning -Message "'0' kann nicht mit anderen Aktionen kombiniert werden."
            continue
        }

        # Aktionen immer in der sichtbaren Menue-Reihenfolge ausfuehren, unabhaengig
        # davon, in welcher Reihenfolge sie eingegeben wurden.
        return @($AllowedValues | Where-Object { $values -contains $_ })
    } while ($true)
}

function Read-Integer {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][int]$Default,
        [int]$Minimum = 0,
        [int]$Maximum = 1440
    )

    do {
        $rawValue = Read-Host "  $Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($rawValue)) { return $Default }

        $number = 0
        if ([int]::TryParse($rawValue, [ref]$number) -and $number -ge $Minimum -and $number -le $Maximum) {
            return $number
        }
        Write-Status -Type Warning -Message "Bitte eine Zahl zwischen $Minimum und $Maximum eingeben."
    } while ($true)
}

function Wait-ForUser {
    Write-Host ""
    $null = Read-Host "  Enter druecken, um fortzufahren"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-MenuAction {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$Action,
        [switch]$NoWait
    )

    Write-Banner -NoClear:$NoWait
    Write-Section -Title $Title
    Write-Host ""
    try {
        & $Action
        Write-Host ""
        Write-Status -Type Success -Message "Aktion abgeschlossen."
    }
    catch {
        Write-Host ""
        Write-Status -Type Error -Message $_.Exception.Message
    }
    if (-not $NoWait) { Wait-ForUser }
}

function Invoke-PowerCfg {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Quiet
    )

    $output = @(& powercfg.exe @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | Out-String).Trim()
        if (-not $details) { $details = "powercfg wurde mit Exitcode $LASTEXITCODE beendet." }
        throw $details
    }
    if (-not $Quiet) { $output | ForEach-Object { Write-Host "  $_" } }
}

function Update-ActivePowerScheme {
    $activeScheme = @(& powercfg.exe /getactivescheme 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Der aktive Energiesparplan konnte nicht gelesen werden." }

    $guidMatch = [regex]::Match(($activeScheme -join " "), "[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
    if (-not $guidMatch.Success) { throw "Die GUID des aktiven Energiesparplans wurde nicht gefunden." }
    Invoke-PowerCfg -Arguments @("/setactive", $guidMatch.Value) -Quiet
}

function Set-PowerTimeouts {
    param(
        [int]$MonitorAc, [int]$MonitorDc,
        [int]$StandbyAc, [int]$StandbyDc,
        [int]$HibernateAc, [int]$HibernateDc,
        [int]$DiskAc, [int]$DiskDc
    )

    $settings = @(
        @{ Name = "monitor-timeout-ac"; Value = $MonitorAc },
        @{ Name = "monitor-timeout-dc"; Value = $MonitorDc },
        @{ Name = "standby-timeout-ac"; Value = $StandbyAc },
        @{ Name = "standby-timeout-dc"; Value = $StandbyDc },
        @{ Name = "hibernate-timeout-ac"; Value = $HibernateAc },
        @{ Name = "hibernate-timeout-dc"; Value = $HibernateDc },
        @{ Name = "disk-timeout-ac"; Value = $DiskAc },
        @{ Name = "disk-timeout-dc"; Value = $DiskDc }
    )

    foreach ($setting in $settings) {
        Invoke-PowerCfg -Arguments @("/change", $setting.Name, [string]$setting.Value) -Quiet
    }
}

function Set-AdvancedPowerValue {
    param(
        [Parameter(Mandatory)][string]$SubGroup,
        [Parameter(Mandatory)][string]$Setting,
        [Parameter(Mandatory)][int]$AcValue,
        [Parameter(Mandatory)][int]$DcValue
    )

    Invoke-PowerCfg -Arguments @("/setacvalueindex", "SCHEME_CURRENT", $SubGroup, $Setting, [string]$AcValue) -Quiet
    Invoke-PowerCfg -Arguments @("/setdcvalueindex", "SCHEME_CURRENT", $SubGroup, $Setting, [string]$DcValue) -Quiet
}

function Set-PowerPreset {
    param([Parameter(Mandatory)][ValidateSet("Eco", "Balanced", "Performance")][string]$Preset)

    switch ($Preset) {
        "Eco" {
            Set-PowerTimeouts -MonitorAc 10 -MonitorDc 5 -StandbyAc 20 -StandbyDc 10 -HibernateAc 60 -HibernateDc 30 -DiskAc 10 -DiskDc 5
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMIN" -AcValue 5 -DcValue 5
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMAX" -AcValue 80 -DcValue 60
            Set-AdvancedPowerValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -AcValue 1 -DcValue 1
            Set-AdvancedPowerValue -SubGroup "SUB_PCIEXPRESS" -Setting "ASPM" -AcValue 2 -DcValue 2
            $label = "Energiesparend"
        }
        "Balanced" {
            Set-PowerTimeouts -MonitorAc 15 -MonitorDc 5 -StandbyAc 30 -StandbyDc 15 -HibernateAc 120 -HibernateDc 60 -DiskAc 20 -DiskDc 10
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMIN" -AcValue 5 -DcValue 5
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMAX" -AcValue 100 -DcValue 80
            Set-AdvancedPowerValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -AcValue 1 -DcValue 1
            Set-AdvancedPowerValue -SubGroup "SUB_PCIEXPRESS" -Setting "ASPM" -AcValue 1 -DcValue 2
            $label = "Ausgeglichen"
        }
        "Performance" {
            Set-PowerTimeouts -MonitorAc 30 -MonitorDc 10 -StandbyAc 0 -StandbyDc 30 -HibernateAc 0 -HibernateDc 120 -DiskAc 0 -DiskDc 20
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMIN" -AcValue 5 -DcValue 5
            Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMAX" -AcValue 100 -DcValue 100
            Set-AdvancedPowerValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -AcValue 0 -DcValue 1
            Set-AdvancedPowerValue -SubGroup "SUB_PCIEXPRESS" -Setting "ASPM" -AcValue 0 -DcValue 1
            $label = "Leistung"
        }
    }

    Update-ActivePowerScheme
    Write-Status -Type Success -Message "Profil '$label' wurde auf den aktiven Energiesparplan angewendet."
}

function Set-CustomPowerTimeouts {
    Write-Status -Type Info -Message "Alle Werte sind Minuten. 0 bedeutet: Nie. Enter uebernimmt den Vorgabewert."
    Write-Host ""

    $monitorAc = Read-Integer -Prompt "Bildschirm aus (Netzbetrieb)" -Default 15
    $monitorDc = Read-Integer -Prompt "Bildschirm aus (Akkubetrieb)" -Default 5
    $standbyAc = Read-Integer -Prompt "Standby (Netzbetrieb)" -Default 30
    $standbyDc = Read-Integer -Prompt "Standby (Akkubetrieb)" -Default 15
    $hibernateAc = Read-Integer -Prompt "Ruhezustand (Netzbetrieb)" -Default 120
    $hibernateDc = Read-Integer -Prompt "Ruhezustand (Akkubetrieb)" -Default 60
    $diskAc = Read-Integer -Prompt "Festplatte aus (Netzbetrieb)" -Default 20
    $diskDc = Read-Integer -Prompt "Festplatte aus (Akkubetrieb)" -Default 10

    Set-PowerTimeouts -MonitorAc $monitorAc -MonitorDc $monitorDc -StandbyAc $standbyAc -StandbyDc $standbyDc -HibernateAc $hibernateAc -HibernateDc $hibernateDc -DiskAc $diskAc -DiskDc $diskDc
    Update-ActivePowerScheme
    Write-Status -Type Success -Message "Benutzerdefinierte Zeitlimits wurden gespeichert."
}

function Set-ProcessorLimits {
    Write-Status -Type Info -Message "Werte in Prozent. Niedrigere Maximalwerte sparen Energie, reduzieren aber die Leistung."
    Write-Host ""

    $minAc = Read-Integer -Prompt "Minimum CPU (Netzbetrieb)" -Default 5 -Maximum 100
    $maxAc = Read-Integer -Prompt "Maximum CPU (Netzbetrieb)" -Default 100 -Maximum 100
    $minDc = Read-Integer -Prompt "Minimum CPU (Akkubetrieb)" -Default 5 -Maximum 100
    $maxDc = Read-Integer -Prompt "Maximum CPU (Akkubetrieb)" -Default 80 -Maximum 100

    if ($minAc -gt $maxAc -or $minDc -gt $maxDc) {
        throw "Das CPU-Minimum darf nicht groesser als das jeweilige Maximum sein."
    }

    Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMIN" -AcValue $minAc -DcValue $minDc
    Set-AdvancedPowerValue -SubGroup "SUB_PROCESSOR" -Setting "PROCTHROTTLEMAX" -AcValue $maxAc -DcValue $maxDc
    Update-ActivePowerScheme
    Write-Status -Type Success -Message "Prozessorgrenzen wurden gespeichert."
}

function Set-UsbPowerSaving {
    param([Parameter(Mandatory)][bool]$Enabled)

    $value = if ($Enabled) { 1 } else { 0 }
    Set-AdvancedPowerValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -AcValue $value -DcValue $value
    Update-ActivePowerScheme
    $state = if ($Enabled) { "aktiviert" } else { "deaktiviert" }
    Write-Status -Type Success -Message "Selektives USB-Energiesparen wurde $state."
}

function Set-FastStartup {
    param([Parameter(Mandatory)][bool]$Enabled)

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    if ($Enabled) {
        Invoke-PowerCfg -Arguments @("/hibernate", "on") -Quiet
        Set-ItemProperty -Path $registryPath -Name "HiberbootEnabled" -Type DWord -Value 1 -Force
        Write-Status -Type Success -Message "Schnellstart wurde aktiviert. Der erforderliche Ruhezustand ist ebenfalls aktiv."
    }
    else {
        Set-ItemProperty -Path $registryPath -Name "HiberbootEnabled" -Type DWord -Value 0 -Force
        Write-Status -Type Success -Message "Schnellstart wurde deaktiviert."
    }
}

function Set-Hibernation {
    param([Parameter(Mandatory)][bool]$Enabled)

    if ($Enabled) {
        Invoke-PowerCfg -Arguments @("/hibernate", "on") -Quiet
        Write-Status -Type Success -Message "Ruhezustand wurde aktiviert."
    }
    else {
        Invoke-PowerCfg -Arguments @("/hibernate", "off") -Quiet
        Write-Status -Type Success -Message "Ruhezustand und der davon abhaengige Schnellstart wurden deaktiviert."
    }
}

function Get-FastStartupState {
    try {
        $value = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction Stop
        if ($value -eq 1) { return "Aktiv" }
    }
    catch {}
    return "Inaktiv"
}

function Show-ActivePowerScheme {
    $activeScheme = @(& powercfg.exe /getactivescheme 2>$null)
    if ($LASTEXITCODE -eq 0 -and $activeScheme.Count -gt 0) {
        Write-Status -Type Info -Message (($activeScheme -join " ").Trim())
    }
    Write-Status -Type Info -Message "Schnellstart: $(Get-FastStartupState)"
}

function Install-NetFramework35 {
    Write-Status -Type Info -Message "Status von .NET Framework 3.5 wird geprueft..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction Stop
    if ($feature.State -eq "Enabled") {
        Write-Status -Type Info -Message ".NET Framework 3.5 ist bereits installiert."
        return
    }

    Write-Status -Type Info -Message ".NET Framework 3.5 wird installiert. Das kann einige Minuten dauern..."
    $result = Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) {
        Write-Status -Type Warning -Message "Installation erfolgreich. Zum Abschluss ist ein Neustart erforderlich."
    }
    else {
        Write-Status -Type Success -Message ".NET Framework 3.5 wurde installiert."
    }
}

function Show-ToggleMenu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$EnableAction,
        [Parameter(Mandatory)][scriptblock]$DisableAction
    )

    Write-Banner
    Write-Section -Title $Title
    Write-Host ""
    Write-MenuItem -Key "1" -Label "Aktivieren"
    Write-MenuItem -Key "2" -Label "Deaktivieren"
    Write-MenuItem -Key "0" -Label "Zurueck"
    $choice = Read-MenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2")

    switch ($choice) {
        "1" { Invoke-MenuAction -Title "$Title aktivieren" -Action $EnableAction }
        "2" { Invoke-MenuAction -Title "$Title deaktivieren" -Action $DisableAction }
    }
}

function Show-PowerMenu {
    do {
        Write-Banner
        Write-Section -Title "ENERGY CENTER"
        Write-Host ""
        Show-ActivePowerScheme
        Write-Host ""
        Write-MenuItem -Key "1" -Label "Profil: Energiesparend" -Hint "maximale Akkulaufzeit"
        Write-MenuItem -Key "2" -Label "Profil: Ausgeglichen" -Hint "guter Alltagsmix"
        Write-MenuItem -Key "3" -Label "Profil: Leistung" -Hint "weniger Limits im Netzbetrieb"
        Write-MenuItem -Key "4" -Label "Zeitlimits individuell setzen" -Hint "Netz und Akku getrennt"
        Write-MenuItem -Key "5" -Label "Schnellstart" -Hint "aktivieren oder deaktivieren"
        Write-MenuItem -Key "6" -Label "Ruhezustand" -Hint "aktivieren oder deaktivieren"
        Write-MenuItem -Key "7" -Label "Prozessorgrenzen" -Hint "CPU Minimum und Maximum"
        Write-MenuItem -Key "8" -Label "USB-Energiesparen" -Hint "selektives USB-Energiesparen"
        Write-MenuItem -Key "0" -Label "Zurueck zum Hauptmenue"

        $choice = Read-MenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2", "3", "4", "5", "6", "7", "8")
        switch ($choice) {
            "1" { Invoke-MenuAction -Title "ENERGIEPROFIL: ENERGIESPAREND" -Action { Set-PowerPreset -Preset Eco } }
            "2" { Invoke-MenuAction -Title "ENERGIEPROFIL: AUSGEGLICHEN" -Action { Set-PowerPreset -Preset Balanced } }
            "3" { Invoke-MenuAction -Title "ENERGIEPROFIL: LEISTUNG" -Action { Set-PowerPreset -Preset Performance } }
            "4" { Invoke-MenuAction -Title "BENUTZERDEFINIERTE ZEITLIMITS" -Action { Set-CustomPowerTimeouts } }
            "5" { Show-ToggleMenu -Title "SCHNELLSTART" -EnableAction { Set-FastStartup -Enabled $true } -DisableAction { Set-FastStartup -Enabled $false } }
            "6" { Show-ToggleMenu -Title "RUHEZUSTAND" -EnableAction { Set-Hibernation -Enabled $true } -DisableAction { Set-Hibernation -Enabled $false } }
            "7" { Invoke-MenuAction -Title "PROZESSORGRENZEN" -Action { Set-ProcessorLimits } }
            "8" { Show-ToggleMenu -Title "USB-ENERGIESPAREN" -EnableAction { Set-UsbPowerSaving -Enabled $true } -DisableAction { Set-UsbPowerSaving -Enabled $false } }
        }
    } while ($choice -ne "0")
}

function Show-MainMenu {
    do {
        Write-Banner
        Write-Section -Title "HAUPTMENUE"
        Write-Host ""
        Write-Status -Type Info -Message "Administrator: Ja"
        if ($OsVersion) {
            Write-Status -Type Info -Message "System: $OsVersion"
        }
        Write-Host ""
        Write-MenuItem -Key "1" -Label "HP-Bloatware entfernen" -Hint "HP Apps und Zusatzprogramme"
        Write-MenuItem -Key "2" -Label "Standard-Apps installieren" -Hint "Chocolatey-Paketliste"
        Write-MenuItem -Key "3" -Label "Windows Updates installieren"
        Write-MenuItem -Key "4" -Label "Taskleiste und Startmenue bereinigen"
        Write-MenuItem -Key "5" -Label "Energy Center" -Hint "Profile und erweiterte Energieoptionen"
        Write-MenuItem -Key "6" -Label ".NET Framework 3.5 installieren"
        Write-MenuItem -Key "7" -Label "Chocolatey-Paketliste anzeigen"
        Write-MenuItem -Key "A" -Label "Alles ausfuehren" -Hint "Menuepunkte 1 bis 7 nacheinander"
        Write-MenuItem -Key "0" -Label "Beenden"
        Write-Host ""
        Write-Status -Type Info -Message "Mehrfachauswahl mit Komma: z. B. 1,2,4,6"

        $choices = @(Read-MultiMenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2", "3", "4", "5", "6", "7") -AllValues @("1", "2", "3", "4", "5", "6", "7"))
        if ($choices -contains "0") { break }

        $actionLabels = @{
            "1" = "HP-Bloatware entfernen"
            "2" = "Standard-Apps installieren"
            "3" = "Windows Updates installieren"
            "4" = "Taskleiste und Startmenue bereinigen"
            "5" = "Energy Center oeffnen"
            "6" = ".NET Framework 3.5 installieren"
            "7" = "Chocolatey-Paketliste anzeigen"
        }
        $selectedLabels = @($choices | ForEach-Object { $actionLabels[$_] })
        Write-Host ""
        Write-Status -Type Info -Message "Reihenfolge: $($selectedLabels -join ' -> ')"

        switch ($choices) {
            "1" {
                Invoke-MenuAction -Title "HP-BLOATWARE ENTFERNEN" -Action { Remove-HPBloat } -NoWait
            }
            "2" {
                Invoke-MenuAction -Title "STANDARD-APPS INSTALLIEREN" -Action { Install-DefaultApps } -NoWait
            }
            "3" {
                Invoke-MenuAction -Title "WINDOWS UPDATES" -Action { Install-Updates } -NoWait
            }
            "4" {
                Invoke-MenuAction -Title "TASKLEISTE UND STARTMENUE BEREINIGEN" -Action {
                    Remove-ApplicationsTaskbar
                    Remove-ApplicationsStartMenu
                } -NoWait
            }
            "5" {
                Show-PowerMenu
            }
            "6" {
                Invoke-MenuAction -Title ".NET FRAMEWORK 3.5" -Action { Install-NetFramework35 } -NoWait
            }
            "7" {
                Invoke-MenuAction -Title "CHOCOLATEY-PAKETLISTE" -Action { Show-ChocoPackageList } -NoWait
            }
        }

        Write-Banner -NoClear
        Write-Section -Title "AUSWAHL ABGESCHLOSSEN"
        Write-Host ""
        Write-Status -Type Success -Message "Alle ausgewaehlten Aktionen wurden der Reihe nach verarbeitet."
        Wait-ForUser
    } while ($true)
}

Write-Banner
if (-not (Test-IsAdministrator)) {
    Write-Status -Type Error -Message "BloatRemover muss als Administrator gestartet werden."
    Write-Status -Type Info -Message "PowerShell per Rechtsklick als Administrator oeffnen und das Skript erneut starten."
    Wait-ForUser
    exit 1
}

Show-MainMenu
Write-Banner
Write-Status -Type Success -Message "BloatRemover wurde beendet."


