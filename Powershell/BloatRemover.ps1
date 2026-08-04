[CmdletBinding()]
param(
    [string]$ConfigPath
)

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

$DefaultWingetPackages = @(
    [pscustomobject]@{ DisplayName = "Google Chrome"; Id = "Google.Chrome"; Name = $null; Source = "winget" }
    [pscustomobject]@{ DisplayName = "Adobe Acrobat Reader (64-Bit)"; Id = "Adobe.Acrobat.Reader.64-bit"; Name = $null; Source = "winget" }
    [pscustomobject]@{ DisplayName = "7-Zip"; Id = "7zip.7zip"; Name = $null; Source = "winget" }
    [pscustomobject]@{ DisplayName = "Mozilla Firefox"; Id = "Mozilla.Firefox"; Name = $null; Source = "winget" }
    [pscustomobject]@{ DisplayName = "TeamViewer Host"; Id = "TeamViewer.TeamViewer.Host"; Name = $null; Source = "winget" }
    [pscustomobject]@{ DisplayName = "Notepad++"; Id = "Notepad++.Notepad++"; Name = $null; Source = "winget" }
    # HP Support Assistant hat derzeit kein Community-Manifest. WinGet greift
    # deshalb ueber den Namen auf die Microsoft-Store-Quelle zu.
    [pscustomobject]@{ DisplayName = "HP Support Assistant"; Id = $null; Name = "HP Support Assistant"; Source = "msstore" }
    [pscustomobject]@{ DisplayName = "Microsoft 365"; Id = "Microsoft.Office"; Name = $null; Source = "winget" }
)

$OsVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
$pathTaskbar = "$env:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\"
$pathStartmenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\"
$ErrorActionPreference = 'Continue'
$script:CustomConfigExecuted = $false
$script:LastCustomConfigSucceeded = $false
$ScriptDirectory = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }

function Test-Yes {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return $Value.Trim() -match '^(?i:j|ja|y|yes)$'
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [Parameter(Mandatory)][string]$Source,
        [switch]$ThrowOnError
    )

    if ([string]::IsNullOrWhiteSpace($Id) -and [string]::IsNullOrWhiteSpace($Name)) {
        throw "Fuer das WinGet-Paket fehlt ID oder Name."
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "WinGet wurde nicht gefunden."
    }

    $arguments = @(
        "install"
        "--exact"
        "--source", $Source
        "--silent"
        "--accept-package-agreements"
        "--accept-source-agreements"
        "--disable-interactivity"
    )
    if ($Id) { $arguments += @("--id", $Id) } else { $arguments += @("--name", $Name) }

    $packageLabel = if ($Id) { $Id } else { $Name }
    Write-Host "  Installiere mit WinGet: $packageLabel"
    & winget.exe @arguments 2>&1 | ForEach-Object { Write-Host "  $_" }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $message = "WinGet-Installation von '$packageLabel' ist fehlgeschlagen (Exitcode $exitCode)."
        if ($ThrowOnError) { throw $message }
        Write-Status -Type Warning -Message $message
    }
}

function Uninstall-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Id) -and [string]::IsNullOrWhiteSpace($Name)) {
        throw "Fuer die WinGet-Deinstallation fehlt ID oder Name."
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "WinGet wurde nicht gefunden."
    }

    $arguments = @(
        "uninstall"
        "--exact"
        "--silent"
        "--accept-source-agreements"
        "--disable-interactivity"
    )
    if ($Id) { $arguments += @("--id", $Id) } else { $arguments += @("--name", $Name) }

    $packageLabel = if ($Id) { $Id } else { $Name }
    Write-Host "  Deinstalliere mit WinGet: $packageLabel"
    & winget.exe @arguments 2>&1 | ForEach-Object { Write-Host "  $_" }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "WinGet-Deinstallation von '$packageLabel' ist fehlgeschlagen (Exitcode $exitCode)."
    }
}

function Remove-ApplicationsTaskbar {
    foreach ($name in $names) {
        $shortcut = Join-Path $pathTaskbar ($name.Trim() + ".lnk")
        Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Name FavoritesRemovedChanges -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\ -Force -ErrorAction SilentlyContinue

    foreach ($package in $HPBloat) {
        Get-AppxPackage *$package* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    }

    Write-Status -Type Info -Message "Taskleisten-Aenderungen werden ohne automatischen Explorer-Neustart uebernommen."
}

function Remove-ApplicationsStartMenu {
    foreach ($name in $names) {
        Get-ChildItem -Path $pathStartmenu -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -match [regex]::Escape($name.Trim()) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Install-DefaultApps {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "WinGet wurde nicht gefunden. Bitte zuerst 'App Installer' aus dem Microsoft Store installieren oder aktualisieren."
    }

    foreach ($package in $DefaultWingetPackages) {
        Install-WingetPackage -Id $package.Id -Name $package.Name -Source $package.Source
    }
}

function Show-WingetPackageList {
    Write-Status -Type Info -Message "Diese WinGet-Pakete werden bei 'Standard-Apps installieren' der Reihe nach installiert:"
    Write-Host ""

    for ($index = 0; $index -lt $DefaultWingetPackages.Count; $index++) {
        $package = $DefaultWingetPackages[$index]
        $identifier = if ($package.Id) { $package.Id } else { "Name: $($package.Name)" }
        Write-Host ("  {0,2}. {1}  [{2}: {3}]" -f ($index + 1), $package.DisplayName, $package.Source, $identifier) -ForegroundColor White
    }
}

function Select-WingetPackagesFallback {
    param([Parameter(Mandatory)][object[]]$Packages)

    Write-Status -Type Warning -Message "Pfeiltasten-Auswahl ist in diesem Host nicht verfuegbar. Bitte Nummern eingeben."
    for ($index = 0; $index -lt $Packages.Count; $index++) {
        Write-MenuItem -Key ([string]($index + 1)) -Label $Packages[$index].DisplayName -Hint $Packages[$index].Id
    }

    do {
        $rawSelection = (Read-Host "  Eintraege (z. B. 1,3,5 oder alle; 0 = Abbrechen)").Trim()
        if ($rawSelection -eq '0') { return @() }
        if ($rawSelection -match '^(?i:a|all|alle)$') { return @($Packages) }

        $selected = [System.Collections.Generic.List[object]]::new()
        $invalid = $false
        foreach ($part in @($rawSelection -split '[,;\s]+' | Where-Object { $_ })) {
            $number = 0
            if (-not [int]::TryParse($part, [ref]$number) -or $number -lt 1 -or $number -gt $Packages.Count) {
                $invalid = $true
                break
            }
            $package = $Packages[$number - 1]
            if (-not $selected.Contains($package)) { $selected.Add($package) }
        }
        if (-not $invalid -and $selected.Count -gt 0) { return @($selected) }
        Write-Status -Type Warning -Message "Ungueltige Auswahl."
    } while ($true)
}

function Select-WingetPackages {
    param([object[]]$Packages = $DefaultWingetPackages)

    if ($Packages.Count -eq 0) { return @() }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return @(Select-WingetPackagesFallback -Packages $Packages)
    }

    $selected = New-Object bool[] $Packages.Count
    $currentIndex = 0
    $listTop = 0
    $originalCursorVisible = $true

    try {
        $originalCursorVisible = [Console]::CursorVisible
        [Console]::CursorVisible = $false
        Write-Host ""
        Write-Status -Type Info -Message "Pfeiltasten: bewegen | Leertaste: ankreuzen | A: alle | Enter: uebernehmen | Esc: abbrechen"
        $listTop = [Console]::CursorTop

        while ($true) {
            $width = [Math]::Max(20, [Console]::WindowWidth - 1)
            for ($index = 0; $index -lt $Packages.Count; $index++) {
                $cursor = if ($index -eq $currentIndex) { '>' } else { ' ' }
                $check = if ($selected[$index]) { '[x]' } else { '[ ]' }
                $identifier = if ($Packages[$index].Id) { $Packages[$index].Id } else { $Packages[$index].Name }
                $line = " $cursor $check $($Packages[$index].DisplayName)  [$identifier]"
                if ($line.Length -gt $width) { $line = $line.Substring(0, $width) }
                [Console]::SetCursorPosition(0, $listTop + $index)
                [Console]::Write($line.PadRight($width))
            }

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' {
                    $currentIndex = if ($currentIndex -le 0) { $Packages.Count - 1 } else { $currentIndex - 1 }
                }
                'DownArrow' {
                    $currentIndex = if ($currentIndex -ge ($Packages.Count - 1)) { 0 } else { $currentIndex + 1 }
                }
                'Spacebar' {
                    $selected[$currentIndex] = -not $selected[$currentIndex]
                }
                'A' {
                    $selectAll = $selected -contains $false
                    for ($index = 0; $index -lt $selected.Count; $index++) { $selected[$index] = $selectAll }
                }
                'Enter' {
                    [Console]::SetCursorPosition(0, $listTop + $Packages.Count)
                    $result = for ($index = 0; $index -lt $Packages.Count; $index++) {
                        if ($selected[$index]) { $Packages[$index] }
                    }
                    return @($result)
                }
                'Escape' {
                    [Console]::SetCursorPosition(0, $listTop + $Packages.Count)
                    return @()
                }
            }
        }
    }
    catch {
        try { [Console]::SetCursorPosition(0, $listTop + $Packages.Count) } catch {}
        return @(Select-WingetPackagesFallback -Packages $Packages)
    }
    finally {
        try { [Console]::CursorVisible = $originalCursorVisible } catch {}
    }
}

function Get-RemovableStoreApps {
    $protectedPackageNames = @(
        '^Microsoft\.WindowsStore$'
        '^Microsoft\.StorePurchaseApp$'
        '^Microsoft\.DesktopAppInstaller$'
        '^Microsoft\.SecHealthUI$'
        '^Microsoft\.Windows\.ShellExperienceHost$'
        '^Microsoft\.Windows\.StartMenuExperienceHost$'
        '^Microsoft\.Windows\.Search$'
        '^Microsoft\.AAD\.BrokerPlugin$'
        '^Microsoft\.AccountsControl$'
        '^Microsoft\.LockApp$'
        '^Microsoft\.CloudExperienceHost$'
        '^MicrosoftWindows\.Client\.'
        '^MicrosoftWindows\.UndockedDevKit$'
        '^Microsoft\.Win32WebViewHost$'
        '^windows\.immersivecontrolpanel$'
        '^Microsoft\.WindowsAppRuntime\.'
        '^Microsoft\.VCLibs\.'
        '^Microsoft\.NET\.Native\.'
        '^Microsoft\.UI\.Xaml\.'
    )

    $startAppNames = @{}
    foreach ($startApp in @(Get-StartApps -ErrorAction SilentlyContinue)) {
        if ($startApp.AppID -match '^([^!]+)!' -and -not $startAppNames.ContainsKey($Matches[1])) {
            $startAppNames[$Matches[1]] = [string]$startApp.Name
        }
    }

    $packages = @(
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object {
                $package = $_
                $isProtectedName = @($protectedPackageNames | Where-Object { $package.Name -match $_ }).Count -gt 0
                -not $isProtectedName -and
                -not (Test-HPProtectedComponent -Name "$($package.Name) $($package.PackageFamilyName)") -and
                $package.IsFramework -ne $true -and
                $package.IsResourcePackage -ne $true -and
                $package.NonRemovable -ne $true
            } |
            Group-Object Name, PackageFamilyName |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    )

    @(
        foreach ($package in $packages) {
            $friendlyName = $startAppNames[[string]$package.PackageFamilyName]
            if ([string]::IsNullOrWhiteSpace($friendlyName) -or $friendlyName -match '^ms-resource:') {
                $friendlyName = [string]$package.Name
            }
            [pscustomobject]@{
                DisplayName = $friendlyName
                Id = [string]$package.Name
                Name = $null
                Source = 'appx'
                PackageName = [string]$package.Name
                PackageFamilyName = [string]$package.PackageFamilyName
                PublisherDisplayName = [string]$package.PublisherDisplayName
            }
        }
    ) | Sort-Object DisplayName
}

function Add-StoreAppUninstallSelections {
    param([Parameter(Mandatory)]$Actions)

    Write-Host ""
    Write-Status -Type Info -Message "Installierte Store-Apps werden ermittelt..."
    $storeApps = @(Get-RemovableStoreApps)
    if ($storeApps.Count -eq 0) {
        Write-Status -Type Warning -Message "Es wurden keine auswaehlbaren Store-Apps gefunden."
        return
    }

    $selectedApps = @(Select-WingetPackages -Packages $storeApps)
    if ($selectedApps.Count -eq 0) {
        Write-Status -Type Info -Message "Keine Store-Apps ausgewaehlt."
        return
    }

    $addedCount = 0
    foreach ($app in $selectedApps) {
        $duplicate = @($Actions | Where-Object {
            $_.action -eq 'uninstall' -and $_.type -eq 'appx' -and
            $_.packageName -eq $app.PackageName
        }).Count -gt 0
        if ($duplicate) { continue }

        $Actions.Add([pscustomobject][ordered]@{
            action = 'uninstall'
            name = $app.DisplayName
            type = 'appx'
            packageName = $app.PackageName
            packageFamilyName = $app.PackageFamilyName
        })
        $addedCount++
    }
    Write-Status -Type Success -Message "$addedCount Store-App(s) wurden zur Deinstallation vorgemerkt."
}

function Uninstall-StoreAppPackage {
    param(
        [string]$PackageName,
        [string]$PackageFamilyName
    )

    if ([string]::IsNullOrWhiteSpace($PackageName) -and [string]::IsNullOrWhiteSpace($PackageFamilyName)) {
        throw "Fuer die Store-App fehlt packageName oder packageFamilyName."
    }
    if (Test-HPProtectedComponent -Name "$PackageName $PackageFamilyName") {
        throw "HP Support Assistant und seine Support-Komponenten duerfen nicht entfernt werden."
    }

    $installedPackages = @(
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object {
                ($PackageName -and $_.Name -eq $PackageName) -or
                ($PackageFamilyName -and $_.PackageFamilyName -eq $PackageFamilyName)
            } |
            Sort-Object PackageFullName -Unique
    )
    $provisionedPackages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {
                ($PackageName -and $_.DisplayName -eq $PackageName) -or
                ($PackageFamilyName -and $_.PackageName -like "$PackageFamilyName*")
            } |
            Sort-Object PackageName -Unique
    )

    if ($installedPackages.Count -eq 0 -and $provisionedPackages.Count -eq 0) {
        Write-Status -Type Info -Message "Store-App '$PackageName' ist bereits nicht mehr installiert."
        return
    }

    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($package in $installedPackages) {
        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
        }
        catch {
            try {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop | Out-Null
            }
            catch {
                $errors.Add("Installiertes Paket '$($package.PackageFullName)': $($_.Exception.Message)")
            }
        }
    }
    foreach ($package in $provisionedPackages) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -AllUsers -ErrorAction Stop | Out-Null
        }
        catch {
            $errors.Add("Provisioniertes Paket '$($package.PackageName)': $($_.Exception.Message)")
        }
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join ' | ')
    }
}

function Read-RequiredValue {
    param([Parameter(Mandatory)][string]$Prompt)

    do {
        $value = (Read-Host "  $Prompt").Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        Write-Status -Type Warning -Message "Die Eingabe darf nicht leer sein."
    } while ($true)
}

function Get-RemovableConfigDrives {
    @(
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 2' -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DeviceID) } |
            Sort-Object DeviceID
    )
}

function Select-ConfigOutputDirectory {
    $usbDrives = @(Get-RemovableConfigDrives)

    Write-Host ""
    Write-Section -Title "SPEICHERZIEL"
    if ($usbDrives.Count -gt 0) {
        for ($index = 0; $index -lt $usbDrives.Count; $index++) {
            $drive = $usbDrives[$index]
            $label = if ($drive.VolumeName) { $drive.VolumeName } else { "USB-Laufwerk" }
            Write-MenuItem -Key ([string]($index + 1)) -Label "$($drive.DeviceID)  $label"
        }
    }
    else {
        Write-Status -Type Warning -Message "Es wurde kein Wechseldatentraeger automatisch erkannt."
    }
    Write-MenuItem -Key "M" -Label "Ordnerpfad manuell eingeben"

    do {
        $choice = (Read-Host "  Speicherziel").Trim()
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $usbDrives.Count) {
            $directory = Join-Path $usbDrives[$number - 1].DeviceID 'BloatRemoverConfigs'
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
            return $directory
        }
        if ($choice -match '^(?i:m|manuell)$') {
            $directory = Read-RequiredValue -Prompt "Zielordner, z. B. E:\BloatRemoverConfigs"
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
            return (Resolve-Path -LiteralPath $directory -ErrorAction Stop).Path
        }
        Write-Status -Type Warning -Message "Bitte ein USB-Laufwerk oder M waehlen."
    } while ($true)
}

function Get-UniqueInstallerDestination {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$FileName
    )

    $destination = Join-Path $Directory $FileName
    if (-not (Test-Path -LiteralPath $destination)) { return $destination }

    $baseName = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [IO.Path]::GetExtension($FileName)
    for ($suffix = 2; $suffix -lt 1000; $suffix++) {
        $destination = Join-Path $Directory ("{0}-{1}{2}" -f $baseName, $suffix, $extension)
        if (-not (Test-Path -LiteralPath $destination)) { return $destination }
    }
    throw "Fuer '$FileName' konnte kein freier Dateiname erzeugt werden."
}

function Read-EnergyToggleSetting {
    param([Parameter(Mandatory)][string]$Label)

    Write-Host ""
    Write-Host "  $Label" -ForegroundColor White
    Write-MenuItem -Key "0" -Label "Nicht aendern"
    Write-MenuItem -Key "1" -Label "Aktivieren"
    Write-MenuItem -Key "2" -Label "Deaktivieren"
    $choice = Read-MenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2")
    switch ($choice) {
        "1" { return "enabled" }
        "2" { return "disabled" }
        default { return "unchanged" }
    }
}

function Read-CustomConfigEnergy {
    Write-Host ""
    Write-Section -Title "ENERGIEEINSTELLUNGEN"
    Write-MenuItem -Key "0" -Label "Kein Energieprofil / nicht aendern"
    Write-MenuItem -Key "1" -Label "Profil: Energiesparend"
    Write-MenuItem -Key "2" -Label "Profil: Ausgeglichen"
    Write-MenuItem -Key "3" -Label "Profil: Leistung"
    Write-MenuItem -Key "4" -Label "Eigene AC/DC-Zeitlimits"
    $profileChoice = Read-MenuChoice -Prompt "Energieprofil" -AllowedValues @("0", "1", "2", "3", "4")

    $preset = $null
    $timeouts = $null
    switch ($profileChoice) {
        "1" { $preset = "Eco" }
        "2" { $preset = "Balanced" }
        "3" { $preset = "Performance" }
        "4" {
            Write-Status -Type Info -Message "Alle Zeitwerte sind Minuten; 0 bedeutet Nie."
            $timeouts = [ordered]@{
                monitorAc = Read-Integer -Prompt "Bildschirm aus (Netzbetrieb)" -Default 15
                monitorDc = Read-Integer -Prompt "Bildschirm aus (Akku)" -Default 5
                standbyAc = Read-Integer -Prompt "Standby (Netzbetrieb)" -Default 30
                standbyDc = Read-Integer -Prompt "Standby (Akku)" -Default 15
                hibernateAc = Read-Integer -Prompt "Ruhezustand (Netzbetrieb)" -Default 120
                hibernateDc = Read-Integer -Prompt "Ruhezustand (Akku)" -Default 60
                diskAc = Read-Integer -Prompt "Festplatte aus (Netzbetrieb)" -Default 20
                diskDc = Read-Integer -Prompt "Festplatte aus (Akku)" -Default 10
            }
        }
    }

    [pscustomobject][ordered]@{
        preset = $preset
        timeouts = $timeouts
        fastStartup = Read-EnergyToggleSetting -Label "Schnellstart"
        hibernation = Read-EnergyToggleSetting -Label "Ruhezustand"
        usbPowerSaving = Read-EnergyToggleSetting -Label "Selektives USB-Energiesparen"
    }
}

function Get-CustomConfigEnergySummary {
    param($Energy)

    if ($null -eq $Energy) { return "Nicht konfiguriert" }
    $profile = if ($Energy.preset) { [string]$Energy.preset } elseif ($Energy.timeouts) { "Eigene Zeitlimits" } else { "Kein Profil" }
    return ("{0}; Schnellstart={1}; Ruhezustand={2}; USB={3}" -f
        $profile,
        $(if ($Energy.fastStartup) { $Energy.fastStartup } else { 'unchanged' }),
        $(if ($Energy.hibernation) { $Energy.hibernation } else { 'unchanged' }),
        $(if ($Energy.usbPowerSaving) { $Energy.usbPowerSaving } else { 'unchanged' }))
}

function Invoke-CustomConfigEnergy {
    param([Parameter(Mandatory)]$Energy)

    if ($Energy.preset) {
        $preset = [string]$Energy.preset
        if ($preset -notin @('Eco', 'Balanced', 'Performance')) { throw "Unbekanntes Energieprofil '$preset'." }
        Set-PowerPreset -Preset $preset
    }
    elseif ($Energy.timeouts) {
        Set-PowerTimeouts `
            -MonitorAc ([int]$Energy.timeouts.monitorAc) -MonitorDc ([int]$Energy.timeouts.monitorDc) `
            -StandbyAc ([int]$Energy.timeouts.standbyAc) -StandbyDc ([int]$Energy.timeouts.standbyDc) `
            -HibernateAc ([int]$Energy.timeouts.hibernateAc) -HibernateDc ([int]$Energy.timeouts.hibernateDc) `
            -DiskAc ([int]$Energy.timeouts.diskAc) -DiskDc ([int]$Energy.timeouts.diskDc)
        Update-ActivePowerScheme
        Write-Status -Type Success -Message "Eigene Energie-Zeitlimits wurden angewendet."
    }

    $hibernation = if ($Energy.hibernation) { [string]$Energy.hibernation } else { 'unchanged' }
    $fastStartup = if ($Energy.fastStartup) { [string]$Energy.fastStartup } else { 'unchanged' }
    $usbPowerSaving = if ($Energy.usbPowerSaving) { [string]$Energy.usbPowerSaving } else { 'unchanged' }

    if ($hibernation -eq 'enabled') { Set-Hibernation -Enabled $true }
    elseif ($hibernation -eq 'disabled') { Set-Hibernation -Enabled $false }

    if ($fastStartup -eq 'enabled') { Set-FastStartup -Enabled $true }
    elseif ($fastStartup -eq 'disabled') { Set-FastStartup -Enabled $false }

    if ($usbPowerSaving -eq 'enabled') { Set-UsbPowerSaving -Enabled $true }
    elseif ($usbPowerSaving -eq 'disabled') { Set-UsbPowerSaving -Enabled $false }
}

function New-CustomInstallConfig {
    Write-Banner
    Write-Section -Title "JSON CONFIG BUILDER"
    Write-Host ""
    Write-Status -Type Info -Message "Unterstuetzt werden WinGet-Pakete, Store-App-Deinstallationen sowie lokale oder freigegebene EXE-/MSI-Installer."
    Write-Status -Type Info -Message "EXE-Parameter muessen zum jeweiligen Hersteller-Installer passen."
    Write-Host ""

    $configName = Read-RequiredValue -Prompt "Name der Konfiguration"
    $actions = [System.Collections.Generic.List[object]]::new()

    do {
        Write-Host ""
        Write-Section -Title "AKTION HINZUFUEGEN"
        Write-MenuItem -Key "1" -Label "WinGet-Pakete aus Liste auswaehlen"
        Write-MenuItem -Key "2" -Label "EXE-Installer ausfuehren"
        Write-MenuItem -Key "3" -Label "MSI-Installer ausfuehren"
        Write-MenuItem -Key "4" -Label "Programm deinstallieren" -Hint "per WinGet-ID oder exaktem Programmnamen"
        Write-MenuItem -Key "5" -Label "Store-Apps deinstallieren" -Hint "installierte Apps per Checkliste auswaehlen"
        Write-MenuItem -Key "0" -Label "Builder abschliessen"
        $typeChoice = Read-MenuChoice -Prompt "Aktion" -AllowedValues @("0", "1", "2", "3", "4", "5")
        if ($typeChoice -eq "0") { break }

        if ($typeChoice -eq "1") {
            $selectedPackages = @(Select-WingetPackages)
            if ($selectedPackages.Count -eq 0) {
                Write-Status -Type Info -Message "Keine WinGet-Pakete ausgewaehlt."
                continue
            }

            $addedCount = 0
            foreach ($package in $selectedPackages) {
                $alreadyAdded = @($actions | Where-Object {
                    $_.Action -eq 'install' -and $_.Type -eq 'winget' -and
                    (($_.Id -and $_.Id -eq $package.Id) -or ($_.MatchName -and $_.MatchName -eq $package.Name))
                }).Count -gt 0
                if ($alreadyAdded) { continue }

                $actions.Add([pscustomobject]@{
                    Action = "install"
                    Name = $package.DisplayName
                    Type = "winget"
                    Id = $package.Id
                    MatchName = $package.Name
                    Source = $package.Source
                    SourcePath = $null
                    Arguments = $null
                    CopyToConfig = $false
                })
                $addedCount++
            }
            Write-Status -Type Success -Message "$addedCount WinGet-Paket(e) wurden vorgemerkt."
            $continueAnswer = Read-Host "  Weitere Aktion hinzufuegen? [J/n]"
            if ($continueAnswer -match '^(?i:n|nein|no)$') { break }
            continue
        }

        if ($typeChoice -eq "5") {
            Add-StoreAppUninstallSelections -Actions $actions
            $continueAnswer = Read-Host "  Weitere Aktion hinzufuegen? [J/n]"
            if ($continueAnswer -match '^(?i:n|nein|no)$') { break }
            continue
        }

        $displayName = Read-RequiredValue -Prompt "Anzeigename der Aktion"
        if ($typeChoice -eq "4") {
            Write-MenuItem -Key "1" -Label "Ueber exakte WinGet-ID suchen"
            Write-MenuItem -Key "2" -Label "Ueber exakten installierten Programmnamen suchen"
            $matchChoice = Read-MenuChoice -Prompt "Suchmethode" -AllowedValues @("1", "2")
            if ($matchChoice -eq "1") {
                $uninstallId = Read-RequiredValue -Prompt "Exakte WinGet-ID"
                $uninstallName = $null
            }
            else {
                $uninstallId = $null
                $uninstallName = Read-RequiredValue -Prompt "Exakter installierter Programmname"
            }
            $actions.Add([pscustomobject]@{
                Action = "uninstall"
                Name = $displayName
                Type = "winget"
                Id = $uninstallId
                MatchName = $uninstallName
                Source = $null
                SourcePath = $null
                Arguments = $null
                CopyToConfig = $false
            })
        }
        else {
            $installerType = if ($typeChoice -eq "2") { "exe" } else { "msi" }
            $installerPath = Read-RequiredValue -Prompt "Vollstaendiger Pfad zum $($installerType.ToUpper())-Installer"
            if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
                Write-Status -Type Warning -Message "Datei wurde nicht gefunden. Das Programm wird nicht hinzugefuegt."
                continue
            }

            $defaultArguments = if ($installerType -eq "msi") { "/qn /norestart" } else { "" }
            $arguments = (Read-Host "  Installationsparameter [$defaultArguments]").Trim()
            if ([string]::IsNullOrWhiteSpace($arguments)) { $arguments = $defaultArguments }
            if ($installerType -eq "exe" -and [string]::IsNullOrWhiteSpace($arguments)) {
                Write-Status -Type Warning -Message "Fuer einen unbeaufsichtigten Ablauf werden Silent-Parameter benoetigt."
                $arguments = Read-RequiredValue -Prompt "Silent-Installationsparameter"
            }

            $copyAnswer = Read-Host "  Installer mit in den Config-Ordner kopieren? [J/n]"
            $copyToConfig = $copyAnswer -notmatch '^(?i:n|nein|no)$'
            $actions.Add([pscustomobject]@{
                Action = "install"
                Name = $displayName
                Type = $installerType
                Id = $null
                MatchName = $null
                Source = $null
                SourcePath = (Resolve-Path -LiteralPath $installerPath).Path
                Arguments = $arguments
                CopyToConfig = $copyToConfig
            })
        }

        Write-Status -Type Success -Message "'$displayName' wurde vorgemerkt."
        $continueAnswer = Read-Host "  Weitere Aktion hinzufuegen? [J/n]"
    } while ($continueAnswer -notmatch '^(?i:n|nein|no)$')

    $energy = $null
    $energyAnswer = Read-Host "  Energieeinstellungen in das Profil aufnehmen? [j/N]"
    if (Test-Yes $energyAnswer) {
        $energy = Read-CustomConfigEnergy
    }

    if ($actions.Count -eq 0 -and $null -eq $energy) {
        Write-Status -Type Warning -Message "Keine Aktionen oder Energieeinstellungen hinzugefuegt. Es wurde keine JSON-Datei erstellt."
        return
    }

    $restartAnswer = Read-Host "  Windows Explorer nach dem Profil automatisch neu starten? [j/N]"
    $restartExplorer = Test-Yes $restartAnswer

    $outputDirectory = Select-ConfigOutputDirectory
    $installerDirectory = Join-Path $outputDirectory 'Installers'
    $serializedActions = [System.Collections.Generic.List[object]]::new()

    foreach ($action in $actions) {
        if ($action.Action -eq 'uninstall') {
            if ($action.Type -eq 'appx') {
                $serializedActions.Add([ordered]@{
                    action = 'uninstall'
                    name = $action.Name
                    type = 'appx'
                    packageName = $action.PackageName
                    packageFamilyName = $action.PackageFamilyName
                })
            }
            else {
                $serializedActions.Add([ordered]@{
                    action = 'uninstall'
                    name = $action.Name
                    type = 'winget'
                    id = $action.Id
                    matchName = $action.MatchName
                })
            }
            continue
        }

        if ($action.Type -eq 'winget') {
            $serializedActions.Add([ordered]@{
                action = 'install'
                name = $action.Name
                type = 'winget'
                id = $action.Id
                matchName = $action.MatchName
                source = $action.Source
            })
            continue
        }

        $savedPath = $action.SourcePath
        $hash = $null
        if ($action.CopyToConfig) {
            New-Item -ItemType Directory -Path $installerDirectory -Force -ErrorAction Stop | Out-Null
            $destination = Get-UniqueInstallerDestination -Directory $installerDirectory -FileName ([IO.Path]::GetFileName($action.SourcePath))
            Write-Host "  Kopiere Installer: $($action.Name)"
            Copy-Item -LiteralPath $action.SourcePath -Destination $destination -ErrorAction Stop
            $savedPath = "Installers\$([IO.Path]::GetFileName($destination))"
            $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256 -ErrorAction Stop).Hash
        }

        $serializedActions.Add([ordered]@{
            action = 'install'
            name = $action.Name
            type = $action.Type
            path = $savedPath
            arguments = $action.Arguments
            sha256 = $hash
            successExitCodes = @(0, 1641, 3010)
        })
    }

    $config = [ordered]@{
        schemaVersion = 2
        name = $configName
        createdAt = (Get-Date).ToString('o')
        restartExplorer = $restartExplorer
        energy = $energy
        actions = $serializedActions
    }
    $safeName = ($configName -replace '[<>:"/\\|?*]', '_').Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = 'CustomSetup' }
    $configPath = Join-Path $outputDirectory ($safeName + '.json')
    if (Test-Path -LiteralPath $configPath) {
        $configPath = Join-Path $outputDirectory ("{0}-{1}.json" -f $safeName, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }

    $json = $config | ConvertTo-Json -Depth 8
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($configPath, $json, $utf8WithoutBom)
    Write-Host ""
    Write-Status -Type Success -Message "Konfiguration gespeichert: $configPath"
    if ($actions | Where-Object { $_.CopyToConfig }) {
        Write-Status -Type Success -Message "Die ausgewaehlten Installer wurden portabel in den Unterordner 'Installers' kopiert."
    }
}

function Test-CustomConfigFile {
    param([Parameter(Mandatory)][string]$Path)

    if ([IO.Path]::GetFileName($Path) -match '(?i)\.example\.json$') { return $false }
    try {
        $config = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $hasActions = @($config.actions).Count -gt 0 -or @($config.applications).Count -gt 0
        $hasEnergy = ($config.PSObject.Properties.Name -contains 'energy') -and $null -ne $config.energy
        return (
            -not [string]::IsNullOrWhiteSpace([string]$config.name) -and
            ($hasActions -or $hasEnergy)
        )
    }
    catch {
        return $false
    }
}

function Get-AvailableCustomConfigs {
    $directories = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $ScriptDirectory) { $directories.Add($ScriptDirectory) }
    $localConfigDirectory = Join-Path $ScriptDirectory 'Configs'
    if (Test-Path -LiteralPath $localConfigDirectory) { $directories.Add($localConfigDirectory) }

    if (-not [string]::IsNullOrWhiteSpace($env:BLOATREMOVER_CONFIG_DIR) -and (Test-Path -LiteralPath $env:BLOATREMOVER_CONFIG_DIR)) {
        $directories.Add($env:BLOATREMOVER_CONFIG_DIR)
    }

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($drive.Root) -or -not (Test-Path -LiteralPath $drive.Root)) { continue }
        $directories.Add($drive.Root)
        $configDirectory = Join-Path $drive.Root 'BloatRemoverConfigs'
        if (Test-Path -LiteralPath $configDirectory) { $directories.Add($configDirectory) }
    }

    @(
        foreach ($directory in ($directories | Sort-Object -Unique)) {
            Get-ChildItem -LiteralPath $directory -Filter '*.json' -File -ErrorAction SilentlyContinue |
                Where-Object { Test-CustomConfigFile -Path $_.FullName }
        }
    ) | Sort-Object FullName -Unique
}

function Select-CustomConfigFile {
    param([object[]]$Configs)

    $configs = if ($null -ne $Configs) { @($Configs) } else { @(Get-AvailableCustomConfigs) }
    Write-Host ""
    Write-Section -Title "KONFIGURATION WAEHLEN"
    if ($configs.Count -gt 0) {
        for ($index = 0; $index -lt $configs.Count; $index++) {
            Write-MenuItem -Key ([string]($index + 1)) -Label $configs[$index].BaseName -Hint $configs[$index].DirectoryName
        }
    }
    else {
        Write-Status -Type Warning -Message "In lokalen oder USB-Config-Ordnern wurden keine JSON-Dateien gefunden."
    }
    Write-MenuItem -Key "M" -Label "JSON-Pfad manuell eingeben"
    Write-MenuItem -Key "0" -Label "Abbrechen"

    do {
        $choice = (Read-Host "  Auswahl").Trim()
        if ($choice -eq '0') { return $null }
        if ($choice -match '^(?i:m|manuell)$') {
            $manualPath = Read-RequiredValue -Prompt "Vollstaendiger Pfad zur JSON-Datei"
            if (Test-Path -LiteralPath $manualPath -PathType Leaf) {
                return (Resolve-Path -LiteralPath $manualPath).Path
            }
            Write-Status -Type Warning -Message "JSON-Datei wurde nicht gefunden."
            continue
        }

        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $configs.Count) {
            return $configs[$number - 1].FullName
        }
        Write-Status -Type Warning -Message "Ungueltige Auswahl."
    } while ($true)
}

function Invoke-StartupConfigCheck {
    $configs = @(Get-AvailableCustomConfigs)
    if ($configs.Count -eq 0) {
        return [pscustomobject]@{ Executed = $false; Succeeded = $true }
    }

    Write-Banner
    Write-Section -Title "JSON-KONFIGURATION GEFUNDEN"
    Write-Host ""
    if ($configs.Count -eq 1) {
        Write-Status -Type Info -Message "Gefunden: $($configs[0].BaseName)  [$($configs[0].DirectoryName)]"
        $answer = Read-Host "  Diese Konfiguration jetzt unbeaufsichtigt ausfuehren? [j/N]"
        if (-not (Test-Yes $answer)) {
            return [pscustomobject]@{ Executed = $false; Succeeded = $true }
        }
        $configPath = $configs[0].FullName
    }
    else {
        Write-Status -Type Info -Message "$($configs.Count) gueltige Konfigurationen wurden gefunden."
        $answer = Read-Host "  Eine Konfiguration jetzt unbeaufsichtigt ausfuehren? [j/N]"
        if (-not (Test-Yes $answer)) {
            return [pscustomobject]@{ Executed = $false; Succeeded = $true }
        }
        $configPath = Select-CustomConfigFile -Configs $configs
        if ([string]::IsNullOrWhiteSpace($configPath)) {
            return [pscustomobject]@{ Executed = $false; Succeeded = $true }
        }
    }

    Write-Status -Type Info -Message "Starte Konfiguration: $([IO.Path]::GetFileName($configPath))"
    $null = Install-CustomConfig -Path $configPath
    return [pscustomobject]@{ Executed = $true; Succeeded = $script:LastCustomConfigSucceeded }
}

function Get-CustomActionSummary {
    param([Parameter(Mandatory)]$Action)

    $mode = if (([string]$Action.action).ToLowerInvariant() -eq 'uninstall') { 'Deinstallieren' } else { 'Installieren' }
    $type = ([string]$Action.type).ToUpperInvariant()
    $target = if ($Action.id) { $Action.id } elseif ($Action.matchName) { $Action.matchName } elseif ($Action.packageName) { $Action.packageName } elseif ($Action.path) { $Action.path } else { '-' }
    return "$mode | $type | $target"
}

function Show-CustomConfigEditorState {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][object[]]$Actions,
        [Parameter(Mandatory)][string]$Path
    )

    Write-Banner
    Write-Section -Title "CUSTOM CONFIG EDITOR"
    Write-Host ""
    Write-Status -Type Info -Message "Datei: $Path"
    Write-Status -Type Info -Message "Profilname: $($Config.name)"
    Write-Status -Type Info -Message "Explorer-Neustart: $(if ($Config.restartExplorer -eq $true) { 'Ja' } else { 'Nein' })"
    Write-Status -Type Info -Message "Energie: $(Get-CustomConfigEnergySummary -Energy $Config.energy)"
    Write-Host ""
    Write-Section -Title "AKTUELLE AKTIONEN"
    if ($Actions.Count -eq 0) {
        Write-Status -Type Info -Message "Keine Programm-Aktionen konfiguriert."
    }
    else {
        for ($index = 0; $index -lt $Actions.Count; $index++) {
            Write-MenuItem -Key ([string]($index + 1)) -Label $Actions[$index].name -Hint (Get-CustomActionSummary -Action $Actions[$index])
        }
    }
}

function Select-CustomActionIndex {
    param(
        [Parameter(Mandatory)][object[]]$Actions,
        [Parameter(Mandatory)][string]$Prompt
    )

    if ($Actions.Count -eq 0) {
        Write-Status -Type Warning -Message "Es sind keine Aktionen vorhanden."
        return -1
    }
    do {
        $rawValue = Read-Host "  $Prompt (1-$($Actions.Count), 0 = Abbrechen)"
        $number = 0
        if ([int]::TryParse($rawValue, [ref]$number) -and $number -eq 0) { return -1 }
        if ($number -ge 1 -and $number -le $Actions.Count) { return ($number - 1) }
        Write-Status -Type Warning -Message "Ungueltige Aktionsnummer."
    } while ($true)
}

function Save-CustomConfigObject {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][object[]]$Actions,
        [Parameter(Mandatory)][string]$Path
    )

    $Config | Add-Member -NotePropertyName schemaVersion -NotePropertyValue 2 -Force
    $Config | Add-Member -NotePropertyName modifiedAt -NotePropertyValue ((Get-Date).ToString('o')) -Force
    $Config | Add-Member -NotePropertyName actions -NotePropertyValue @($Actions) -Force
    if ($Config.PSObject.Properties.Name -contains 'applications') {
        $Config.PSObject.Properties.Remove('applications')
    }
    $json = $Config | ConvertTo-Json -Depth 10
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $json, $utf8WithoutBom)
}

function Edit-CustomConfig {
    $configPath = Select-CustomConfigFile
    if ([string]::IsNullOrWhiteSpace($configPath)) { return }

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Status -Type Error -Message "Konfiguration konnte nicht geladen werden: $($_.Exception.Message)"
        return
    }

    $sourceActions = @($config.actions)
    if ($sourceActions.Count -eq 0 -and @($config.applications).Count -gt 0) {
        $sourceActions = @($config.applications | ForEach-Object {
            $_ | Add-Member -NotePropertyName action -NotePropertyValue 'install' -PassThru -Force
        })
    }
    $actions = [System.Collections.Generic.List[object]]::new()
    foreach ($action in $sourceActions) { $actions.Add($action) }
    $configDirectory = Split-Path -Parent $configPath

    while ($true) {
        Show-CustomConfigEditorState -Config $config -Actions @($actions) -Path $configPath
        Write-Host ""
        Write-MenuItem -Key "1" -Label "Profilnamen aendern"
        Write-MenuItem -Key "2" -Label "Explorer-Neustart umschalten"
        Write-MenuItem -Key "3" -Label "Energieeinstellungen bearbeiten"
        Write-MenuItem -Key "4" -Label "WinGet-Pakete hinzufuegen"
        Write-MenuItem -Key "5" -Label "Desktop-Programm deinstallieren" -Hint "WinGet"
        Write-MenuItem -Key "6" -Label "Store-Apps deinstallieren" -Hint "installierte Apps per Checkliste"
        Write-MenuItem -Key "7" -Label "EXE/MSI-Installer hinzufuegen"
        Write-MenuItem -Key "8" -Label "Aktion bearbeiten"
        Write-MenuItem -Key "9" -Label "Aktion entfernen"
        Write-MenuItem -Key "10" -Label "Aktionsreihenfolge aendern"
        Write-MenuItem -Key "S" -Label "Speichern und Editor schliessen"
        Write-MenuItem -Key "0" -Label "Ohne Speichern schliessen"
        $choice = (Read-Host "  Auswahl").Trim().ToLowerInvariant()

        switch ($choice) {
            "1" {
                $newName = (Read-Host "  Neuer Profilname [$($config.name)]").Trim()
                if ($newName) { $config | Add-Member -NotePropertyName name -NotePropertyValue $newName -Force }
            }
            "2" {
                $config | Add-Member -NotePropertyName restartExplorer -NotePropertyValue (-not ($config.restartExplorer -eq $true)) -Force
            }
            "3" {
                Write-MenuItem -Key "1" -Label "Energieeinstellungen neu setzen"
                Write-MenuItem -Key "2" -Label "Energieeinstellungen entfernen"
                $energyChoice = Read-MenuChoice -Prompt "Auswahl" -AllowedValues @("1", "2")
                $energy = if ($energyChoice -eq "1") { Read-CustomConfigEnergy } else { $null }
                $config | Add-Member -NotePropertyName energy -NotePropertyValue $energy -Force
            }
            "4" {
                foreach ($package in @(Select-WingetPackages)) {
                    $duplicate = @($actions | Where-Object {
                        $_.action -eq 'install' -and $_.type -eq 'winget' -and
                        (($_.id -and $_.id -eq $package.Id) -or ($_.matchName -and $_.matchName -eq $package.Name))
                    }).Count -gt 0
                    if (-not $duplicate) {
                        $actions.Add([pscustomobject][ordered]@{
                            action = 'install'; name = $package.DisplayName; type = 'winget'
                            id = $package.Id; matchName = $package.Name; source = $package.Source
                        })
                    }
                }
            }
            "5" {
                $displayName = Read-RequiredValue -Prompt "Anzeigename der Deinstallation"
                Write-MenuItem -Key "1" -Label "Exakte WinGet-ID"
                Write-MenuItem -Key "2" -Label "Exakter installierter Programmname"
                $matchChoice = Read-MenuChoice -Prompt "Suchmethode" -AllowedValues @("1", "2")
                $id = if ($matchChoice -eq "1") { Read-RequiredValue -Prompt "WinGet-ID" } else { $null }
                $matchName = if ($matchChoice -eq "2") { Read-RequiredValue -Prompt "Installierter Programmname" } else { $null }
                $actions.Add([pscustomobject][ordered]@{
                    action = 'uninstall'; name = $displayName; type = 'winget'; id = $id; matchName = $matchName
                })
            }
            "6" {
                Add-StoreAppUninstallSelections -Actions $actions
            }
            "7" {
                $installerChoice = Read-MenuChoice -Prompt "1 = EXE, 2 = MSI" -AllowedValues @("1", "2")
                $type = if ($installerChoice -eq "1") { 'exe' } else { 'msi' }
                $name = Read-RequiredValue -Prompt "Anzeigename"
                $sourcePath = Read-RequiredValue -Prompt "Vollstaendiger Installer-Pfad"
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                    Write-Status -Type Warning -Message "Installer wurde nicht gefunden."
                    break
                }
                $defaultArguments = if ($type -eq 'msi') { '/qn /norestart' } else { '' }
                $arguments = (Read-Host "  Installationsparameter [$defaultArguments]").Trim()
                if (-not $arguments) { $arguments = $defaultArguments }
                if ($type -eq 'exe' -and -not $arguments) { $arguments = Read-RequiredValue -Prompt "Silent-Installationsparameter" }

                $copyAnswer = Read-Host "  Installer in den portablen Config-Ordner kopieren? [J/n]"
                $savedPath = (Resolve-Path -LiteralPath $sourcePath).Path
                $hash = $null
                if ($copyAnswer -notmatch '^(?i:n|nein|no)$') {
                    $installerDirectory = Join-Path $configDirectory 'Installers'
                    New-Item -ItemType Directory -Path $installerDirectory -Force -ErrorAction Stop | Out-Null
                    $destination = Get-UniqueInstallerDestination -Directory $installerDirectory -FileName ([IO.Path]::GetFileName($savedPath))
                    Copy-Item -LiteralPath $savedPath -Destination $destination -ErrorAction Stop
                    $savedPath = "Installers\$([IO.Path]::GetFileName($destination))"
                    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256 -ErrorAction Stop).Hash
                }
                $actions.Add([pscustomobject][ordered]@{
                    action = 'install'; name = $name; type = $type; path = $savedPath
                    arguments = $arguments; sha256 = $hash; successExitCodes = @(0, 1641, 3010)
                })
            }
            "8" {
                $index = Select-CustomActionIndex -Actions @($actions) -Prompt "Aktion bearbeiten"
                if ($index -ge 0) {
                    $action = $actions[$index]
                    $newName = (Read-Host "  Anzeigename [$($action.name)]").Trim()
                    if ($newName) { $action | Add-Member -NotePropertyName name -NotePropertyValue $newName -Force }
                    if (([string]$action.action).ToLowerInvariant() -eq 'uninstall') {
                        if (([string]$action.type).ToLowerInvariant() -eq 'appx') {
                            Write-Status -Type Info -Message "Store-App-Kennung: $($action.packageName) (wird ueber die Checkliste festgelegt)"
                        }
                        elseif ($action.id) {
                            $newId = (Read-Host "  WinGet-ID [$($action.id)]").Trim()
                            if ($newId) { $action | Add-Member -NotePropertyName id -NotePropertyValue $newId -Force }
                        }
                        else {
                            $newMatchName = (Read-Host "  Installierter Programmname [$($action.matchName)]").Trim()
                            if ($newMatchName) { $action | Add-Member -NotePropertyName matchName -NotePropertyValue $newMatchName -Force }
                        }
                    }
                    elseif ($action.path) {
                        $newPath = (Read-Host "  Installer-Pfad [$($action.path)]").Trim()
                        if ($newPath) {
                            $action | Add-Member -NotePropertyName path -NotePropertyValue $newPath -Force
                            $action | Add-Member -NotePropertyName sha256 -NotePropertyValue $null -Force
                        }
                        $newArguments = (Read-Host "  Parameter [$($action.arguments)]").Trim()
                        if ($newArguments) { $action | Add-Member -NotePropertyName arguments -NotePropertyValue $newArguments -Force }
                    }
                }
            }
            "9" {
                $index = Select-CustomActionIndex -Actions @($actions) -Prompt "Aktion entfernen"
                if ($index -ge 0) { $actions.RemoveAt($index) }
            }
            "10" {
                $index = Select-CustomActionIndex -Actions @($actions) -Prompt "Aktion verschieben"
                if ($index -ge 0) {
                    $direction = Read-MenuChoice -Prompt "1 = nach oben, 2 = nach unten" -AllowedValues @("1", "2")
                    $target = if ($direction -eq "1") { $index - 1 } else { $index + 1 }
                    if ($target -ge 0 -and $target -lt $actions.Count) {
                        $temporary = $actions[$target]
                        $actions[$target] = $actions[$index]
                        $actions[$index] = $temporary
                    }
                }
            }
            "s" {
                if ($actions.Count -eq 0 -and $null -eq $config.energy) {
                    Write-Status -Type Warning -Message "Mindestens eine Programm-Aktion oder Energieeinstellung ist erforderlich."
                    break
                }
                Save-CustomConfigObject -Config $config -Actions @($actions) -Path $configPath
                Write-Status -Type Success -Message "Konfiguration wurde gespeichert."
                return
            }
            "0" { return }
            default { Write-Status -Type Warning -Message "Ungueltige Editor-Auswahl." }
        }
    }
}

function Invoke-CustomFileInstaller {
    param(
        [Parameter(Mandatory)]$Application,
        [Parameter(Mandatory)][string]$ConfigDirectory
    )

    $installerPath = [string]$Application.path
    if ([string]::IsNullOrWhiteSpace($installerPath)) { throw "Installer-Pfad fehlt." }
    if (-not [IO.Path]::IsPathRooted($installerPath)) {
        $installerPath = Join-Path $ConfigDirectory $installerPath
    }
    $installerPath = [IO.Path]::GetFullPath($installerPath)
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "Installer nicht gefunden: $installerPath"
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Application.sha256)) {
        $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($actualHash -ne [string]$Application.sha256) {
            throw "SHA-256-Pruefung fuer '$($Application.name)' ist fehlgeschlagen."
        }
    }

    $arguments = [string]$Application.arguments
    $type = ([string]$Application.type).ToLowerInvariant()
    if ($type -eq 'msi') {
        $filePath = 'msiexec.exe'
        $argumentList = "/i `"$installerPath`" $arguments".Trim()
    }
    elseif ($type -eq 'exe') {
        $filePath = $installerPath
        $argumentList = $arguments
    }
    else {
        throw "Nicht unterstuetzter Installer-Typ '$type'."
    }

    $processArguments = @{ FilePath = $filePath; Wait = $true; PassThru = $true; ErrorAction = 'Stop' }
    if (-not [string]::IsNullOrWhiteSpace($argumentList)) { $processArguments.ArgumentList = $argumentList }
    $process = Start-Process @processArguments

    $successExitCodes = @($Application.successExitCodes | ForEach-Object { [int]$_ })
    if ($successExitCodes.Count -eq 0) { $successExitCodes = @(0, 1641, 3010) }
    if ($process.ExitCode -notin $successExitCodes) {
        throw "Installer endete mit Exitcode $($process.ExitCode)."
    }
}

function Install-CustomConfig {
    param([string]$Path)

    $script:LastCustomConfigSucceeded = $false

    $configPath = $Path
    if ([string]::IsNullOrWhiteSpace($configPath)) {
        $configPath = Select-CustomConfigFile
    }
    if ([string]::IsNullOrWhiteSpace($configPath)) { return $false }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        Write-Status -Type Error -Message "Konfiguration wurde nicht gefunden: $configPath"
        return $false
    }
    $configPath = (Resolve-Path -LiteralPath $configPath).Path

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Status -Type Error -Message "Konfiguration konnte nicht gelesen werden: $($_.Exception.Message)"
        return $false
    }
    $script:CustomConfigExecuted = $true

    $actions = @($config.actions)
    if ($actions.Count -eq 0 -and @($config.applications).Count -gt 0) {
        # Rueckwaertskompatibilitaet mit den zuerst erzeugten Schema-v1-Dateien.
        $actions = @($config.applications | ForEach-Object {
            $_ | Add-Member -NotePropertyName action -NotePropertyValue 'install' -PassThru -Force
        })
    }
    if ($actions.Count -eq 0 -and $null -eq $config.energy) {
        Write-Status -Type Warning -Message "Die Konfiguration enthaelt keine Aktionen oder Energieeinstellungen."
        return $false
    }

    Write-Host ""
    Write-Status -Type Info -Message "Profil: $($config.name)"
    Write-Status -Type Info -Message "$($actions.Count) Programm-Aktion(en) werden jetzt ohne weitere Rueckfragen ausgefuehrt."

    $configDirectory = Split-Path -Parent $configPath
    $failedActions = 0
    foreach ($action in $actions) {
        Write-Host ""
        $actionMode = ([string]$action.action).ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($actionMode)) { $actionMode = 'install' }
        $verb = if ($actionMode -eq 'uninstall') { 'Deinstalliere' } else { 'Installiere' }
        Write-Status -Type Info -Message "$verb`: $($action.name)"
        try {
            if ($actionMode -notin @('install', 'uninstall')) {
                throw "Unbekannte Aktion '$actionMode'. Erlaubt sind install und uninstall."
            }
            if ($actionMode -eq 'uninstall') {
                $type = ([string]$action.type).ToLowerInvariant()
                if ($type -eq 'appx') {
                    Uninstall-StoreAppPackage -PackageName ([string]$action.packageName) -PackageFamilyName ([string]$action.packageFamilyName)
                }
                elseif ($type -eq 'winget' -or [string]::IsNullOrWhiteSpace($type)) {
                    Uninstall-WingetPackage -Id ([string]$action.id) -Name ([string]$action.matchName)
                }
                else {
                    throw "Nicht unterstuetzter Deinstallationstyp '$type'."
                }
            }
            else {
                $type = ([string]$action.type).ToLowerInvariant()
                if ($type -eq 'winget') {
                    $source = if ($action.source) { [string]$action.source } else { 'winget' }
                    Install-WingetPackage -Id ([string]$action.id) -Name ([string]$action.matchName) -Source $source -ThrowOnError
                }
                else {
                    Invoke-CustomFileInstaller -Application $action -ConfigDirectory $configDirectory
                }
            }
            Write-Status -Type Success -Message "'$($action.name)' wurde verarbeitet."
        }
        catch {
            $failedActions++
            Write-Status -Type Error -Message "'$($action.name)' ist fehlgeschlagen: $($_.Exception.Message)"
        }
    }

    if ($null -ne $config.energy) {
        Write-Host ""
        Write-Status -Type Info -Message "Energieeinstellungen werden angewendet: $(Get-CustomConfigEnergySummary -Energy $config.energy)"
        try {
            Invoke-CustomConfigEnergy -Energy $config.energy
            Write-Status -Type Success -Message "Energieeinstellungen wurden verarbeitet."
        }
        catch {
            $failedActions++
            Write-Status -Type Error -Message "Energieeinstellungen sind fehlgeschlagen: $($_.Exception.Message)"
        }
    }

    if ($config.restartExplorer -eq $true) {
        Restart-WindowsExplorer
    }

    if ($failedActions -gt 0) {
        Write-Status -Type Warning -Message "$failedActions Aktion(en) sind fehlgeschlagen; alle uebrigen Aktionen wurden trotzdem ausgefuehrt."
        return $false
    }
    Write-Status -Type Success -Message "Custom-Konfiguration wurde vollstaendig ausgefuehrt."
    $script:LastCustomConfigSucceeded = $true
    return $true
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
        $rawChoice = (Read-Host "  $Prompt").Trim().ToLowerInvariant()
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
        if ($values.Count -gt 1 -and ($values -contains 'b' -or $values -contains 'c' -or $values -contains 'e')) {
            Write-Status -Type Warning -Message "Builder, Editor und Custom-Konfiguration bitte jeweils einzeln auswaehlen."
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

function Restart-WindowsExplorer {
    $explorerPath = Join-Path $env:SystemRoot 'explorer.exe'
    Write-Status -Type Info -Message "Windows Explorer wird auf Wunsch neu gestartet..."

    try {
        $runningExplorers = @(Get-Process -Name explorer -ErrorAction SilentlyContinue)
        if ($runningExplorers.Count -gt 0) {
            $runningExplorers | Stop-Process -Force -ErrorAction Stop

            for ($attempt = 0; $attempt -lt 10; $attempt++) {
                if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { break }
                Start-Sleep -Milliseconds 300
            }
            if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
                throw "Der laufende Explorer-Prozess konnte nicht beendet werden."
            }
        }

        for ($startAttempt = 1; $startAttempt -le 2; $startAttempt++) {
            Start-Process -FilePath $explorerPath -ErrorAction Stop
            for ($check = 0; $check -lt 10; $check++) {
                Start-Sleep -Milliseconds 300
                if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
                    Write-Status -Type Success -Message "Windows Explorer wurde erfolgreich gestartet."
                    return
                }
            }
        }

        throw "Windows Explorer wurde nach zwei Versuchen nicht gestartet."
    }
    catch {
        Write-Status -Type Error -Message "Windows Explorer konnte nicht neu gestartet werden: $($_.Exception.Message)"
    }
}

function Request-ExplorerRestart {
    Write-Host ""
    $answer = Read-Host "  Windows Explorer jetzt neu starten? [j/N]"
    if (Test-Yes $answer) {
        Restart-WindowsExplorer
    }
    else {
        Write-Status -Type Info -Message "Windows Explorer wird nicht neu gestartet. Die Aenderungen erscheinen spaetestens bei der naechsten Anmeldung."
    }
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
        Write-MenuItem -Key "2" -Label "Standard-Apps installieren" -Hint "WinGet-Paketliste"
        Write-MenuItem -Key "3" -Label "Windows Updates installieren"
        Write-MenuItem -Key "4" -Label "Taskleiste und Startmenue bereinigen"
        Write-MenuItem -Key "5" -Label "Energy Center" -Hint "Profile und erweiterte Energieoptionen"
        Write-MenuItem -Key "6" -Label ".NET Framework 3.5 installieren"
        Write-MenuItem -Key "7" -Label "WinGet-Paketliste anzeigen"
        Write-MenuItem -Key "A" -Label "Alles ausfuehren" -Hint "Menuepunkte 1 bis 7 nacheinander"
        Write-MenuItem -Key "C" -Label "Custom-JSON ausfuehren" -Hint "danach vollstaendig ohne Rueckfragen"
        Write-MenuItem -Key "B" -Label "JSON Config Builder" -Hint "Profil lokal oder auf USB erstellen"
        Write-MenuItem -Key "E" -Label "JSON Config Editor" -Hint "Settings und Aktionen anzeigen/bearbeiten"
        Write-MenuItem -Key "0" -Label "Beenden"
        Write-Host ""
        Write-Status -Type Info -Message "Mehrfachauswahl mit Komma: z. B. 1,2,4,6"

        $choices = @(Read-MultiMenuChoice -Prompt "Auswahl" -AllowedValues @("0", "1", "2", "3", "4", "5", "6", "7", "c", "b", "e") -AllValues @("1", "2", "3", "4", "5", "6", "7"))
        if ($choices -contains "0") { break }

        if ($choices -contains "b") {
            Invoke-MenuAction -Title "JSON CONFIG BUILDER" -Action { New-CustomInstallConfig }
            continue
        }
        if ($choices -contains "c") {
            Install-CustomConfig | Out-Null
            return
        }
        if ($choices -contains "e") {
            Invoke-MenuAction -Title "JSON CONFIG EDITOR" -Action { Edit-CustomConfig }
            continue
        }

        $actionLabels = @{
            "1" = "HP-Bloatware entfernen"
            "2" = "Standard-Apps installieren"
            "3" = "Windows Updates installieren"
            "4" = "Taskleiste und Startmenue bereinigen"
            "5" = "Energy Center oeffnen"
            "6" = ".NET Framework 3.5 installieren"
            "7" = "WinGet-Paketliste anzeigen"
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
                Invoke-MenuAction -Title "WINGET-PAKETLISTE" -Action { Show-WingetPackageList } -NoWait
            }
        }

        Write-Banner -NoClear
        Write-Section -Title "AUSWAHL ABGESCHLOSSEN"
        Write-Host ""
        Write-Status -Type Success -Message "Alle ausgewaehlten Aktionen wurden der Reihe nach verarbeitet."
        Request-ExplorerRestart
        Wait-ForUser
    } while ($true)
}

Write-Banner
if (-not (Test-IsAdministrator)) {
    Write-Status -Type Error -Message "BloatRemover muss als Administrator gestartet werden."
    Write-Status -Type Info -Message "PowerShell per Rechtsklick als Administrator oeffnen und das Skript erneut starten."
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) { Wait-ForUser }
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    Write-Banner
    Write-Section -Title "UNBEAUFSICHTIGTE JSON-KONFIGURATION"
    $null = Install-CustomConfig -Path $ConfigPath
    if (-not $script:LastCustomConfigSucceeded) { exit 2 }
    exit 0
}

$startupConfigResult = @(Invoke-StartupConfigCheck) | Select-Object -Last 1
if ($startupConfigResult.Executed) {
    if (-not $startupConfigResult.Succeeded) { exit 2 }
    exit 0
}

Show-MainMenu
if (-not $script:CustomConfigExecuted) { Write-Banner }
Write-Status -Type Success -Message "BloatRemover wurde beendet."


