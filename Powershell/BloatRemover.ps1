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
    Install-ChocoPackage -Name "googlechrome"
    Install-ChocoPackage -Name "adobereader"
    Install-ChocoPackage -Name "7zip"
    Install-ChocoPackage -Name "firefox"
    Install-ChocoPackage -Name "teamviewer.host"
    Install-ChocoPackage -Name "notepadplusplus"
    Install-ChocoPackage -Name "hpsupportassistant"
    Install-ChocoPackage -Name "office365business" -Params "/eula:TRUE" -AllowLongInstall
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
    ##HP Specific
    $UninstallPrograms = @(
        "HP Client Security Manager"
        "HP Notifications"
        "HP Security Update Service"
        "HP System Default Settings"
        "HP Wolf Security"
        "HP Wolf Security Application Support for Sure Sense"
        "HP Wolf Security Application Support for Windows"
        "AD2F1837.HPPCHardwareDiagnosticsWindows"
        "AD2F1837.HPPowerManager"
        "AD2F1837.HPPrivacySettings"
        "AD2F1837.HPQuickDrop"
        "AD2F1837.HPSystemInformation"
        "AD2F1837.myHP"
        "RealtekSemiconductorCorp.HPAudioControl"
        "HP Sure Recover"
        "HP Sure Run Module"
        ""
    )

    $HPidentifier = "AD2F1837"

    $InstalledPackages = @(Get-AppxPackage -AllUsers | Where-Object {($UninstallPrograms -contains $_.Name) -or ($_.Name -match "^$HPidentifier")})

    $ProvisionedPackages = @(Get-AppxProvisionedPackage -Online | Where-Object {($UninstallPrograms -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier")})

    $InstalledPrograms = @(Get-Package | Where-Object {$UninstallPrograms -contains $_.Name})

    Write-Host ("HP Apps (installed): {0}, provisioned: {1}, programs: {2}" -f $InstalledPackages.Count, $ProvisionedPackages.Count, $InstalledPrograms.Count)
    if (($InstalledPackages.Count + $ProvisionedPackages.Count + $InstalledPrograms.Count) -eq 0) {
        Write-Host "No HP apps found to remove."
    }

    # Remove provisioned packages first
    ForEach ($ProvPackage in $ProvisionedPackages) {

        Write-Host -Object "Attempting to remove provisioned package: [$($ProvPackage.DisplayName)]..."

        Try {
            $Null = Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online -ErrorAction Stop
            Write-Host -Object "Successfully removed provisioned package: [$($ProvPackage.DisplayName)]"
        }
        Catch {Write-Warning -Message "Failed to remove provisioned package: [$($ProvPackage.DisplayName)]"}
    }

    # Remove appx packages
    ForEach ($AppxPackage in $InstalledPackages) {
                                            
        Write-Host -Object "Attempting to remove Appx package: [$($AppxPackage.Name)]..."

        Try {
            $Null = Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers -ErrorAction Stop
            Write-Host -Object "Successfully removed Appx package: [$($AppxPackage.Name)]"
        }
        Catch {Write-Warning -Message "Failed to remove Appx package: [$($AppxPackage.Name)]"}
    }

    # Remove installed programs
    $InstalledPrograms | ForEach-Object {

        Write-Host -Object "Attempting to uninstall: [$($_.Name)]..."

        Try {
            $Null = $_ | Uninstall-Package -AllVersions -Force -ErrorAction Stop
            Write-Host -Object "Successfully uninstalled: [$($_.Name)]"
        }
        Catch {Write-Warning -Message "Failed to uninstall: [$($_.Name)]"}
    }


    #Remove HP Documentation
    $A = Start-Process -FilePath "C:\Program Files\HP\Documentation\Doc_uninstall.cmd" -Wait -passthru -NoNewWindow;$a.ExitCode

    ##Remove Standard HP apps via msiexec
    $InstalledPrograms | ForEach-Object {
    $appname = $_.Name
        Write-Host -Object "Attempting to uninstall: [$($_.Name)]..."

        Try {
            $Prod = Get-WMIObject -Classname Win32_Product | Where-Object Name -Match $appname
            $Prod.UnInstall()
            Write-Host -Object "Successfully uninstalled: [$($_.Name)]"
        }
        Catch {Write-Warning -Message "Failed to uninstall: [$($_.Name)]"}
    }
    Write-Host "Removed HP bloat"
}

function Write-Banner {
    Clear-Host
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

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Message)

    $answer = Read-Host "  $Message [j/N]"
    return (Test-Yes $answer)
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
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Banner
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
    Wait-ForUser
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
        Write-MenuItem -Key "0" -Label "Beenden"

        $choice = Read-MenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2", "3", "4", "5", "6")
        switch ($choice) {
            "1" {
                if (Confirm-Action -Message "Wirklich alle gefundenen HP-Komponenten entfernen?") {
                    Invoke-MenuAction -Title "HP-BLOATWARE ENTFERNEN" -Action { Remove-HPBloat }
                }
            }
            "2" {
                if (Confirm-Action -Message "Standard-Apps jetzt installieren?") {
                    Invoke-MenuAction -Title "STANDARD-APPS INSTALLIEREN" -Action { Install-DefaultApps }
                }
            }
            "3" {
                if (Confirm-Action -Message "Verfuegbare Windows Updates jetzt installieren?") {
                    Invoke-MenuAction -Title "WINDOWS UPDATES" -Action { Install-Updates }
                }
            }
            "4" {
                if (Confirm-Action -Message "Verknuepfungen aus Taskleiste und Startmenue entfernen?") {
                    Invoke-MenuAction -Title "TASKLEISTE UND STARTMENUE BEREINIGEN" -Action {
                        Remove-ApplicationsTaskbar
                        Remove-ApplicationsStartMenu
                    }
                }
            }
            "5" { Show-PowerMenu }
            "6" {
                Invoke-MenuAction -Title ".NET FRAMEWORK 3.5" -Action { Install-NetFramework35 }
            }
        }
    } while ($choice -ne "0")
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


