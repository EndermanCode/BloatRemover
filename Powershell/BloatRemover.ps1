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

$OsVersion = Get-ComputerInfo | select WindowsProductName
$pathTaskbar = "$env:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\"
$pathStartmenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\"
$ErrorActionPreference = 'SilentlyContinue'

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

    $args = @("install", $Name, "-y", "--ignore-checksum", "-f")
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

    $InstalledPackages = Get-AppxPackage -AllUsers | Where-Object {($UninstallPackages -contains $_.Name) -or ($_.Name -match "^$HPidentifier")}

    $ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object {($UninstallPackages -contains $_.DisplayName) -or ($_.DisplayName -match "^$HPidentifier")}

    $InstalledPrograms = Get-Package | Where-Object {$UninstallPrograms -contains $_.Name}

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

function Set-PowerSettings {
    Write-Host "Disabling Fast Startup..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -Type DWord -Value 0

    Write-Host "Setting hibernate timeout on AC to never..."
    powercfg /change -hibernate-timeout-ac 0

    Write-Host "Setting monitor timeout on AC to 30 minutes..."
    powercfg /change -monitor-timeout-ac 30
}

$hpbloat = Read-Host("Sollen sämmtliche HP Apps deinstalliert werden? [Y][N]")
$apps = Read-Host("Sollen default Apps installiert werden? [Y][N]")
$updates = Read-Host("Sollen sämmtliche Windows Updates installiert werden? [Y][N]")
$cleantaskbar = Read-Host("Sollen sämmtliche Apps aus der Taskleiste und Startmenu entfernt werden? [Y][N]")
$power = Read-Host("Sollen Schnellstart deaktiviert und Energieoptionen (Netzbetrieb) gesetzt werden? [Y][N]")

if (Test-Yes $hpbloat) {
    Remove-HPBloat
}
if (Test-Yes $apps) {
    Install-DefaultApps
}
if (Test-Yes $cleantaskbar) {
    Remove-ApplicationsTaskbar
    Remove-ApplicationsStartMenu
}
if (Test-Yes $updates) {
    Install-Updates
}
if (Test-Yes $power) {
    Set-PowerSettings
}
Read-Host("Drücke Enter um das Script zu beenden...")


