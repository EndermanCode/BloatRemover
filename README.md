# BloatRemover

Windows-Tool fuer die Erstinstallation und das System-Setup als GUI und PowerShell-CLI.

## PowerShell-CLI
Start als Administrator:
```powershell
.\Powershell\BloatRemover.ps1
```

Das nummerierte Menue bietet:
- HP-Bloatware entfernen
- Standard-Apps und Windows Updates installieren
- Taskleiste und Startmenue bereinigen
- .NET Framework 3.5 installieren
- Energy Center mit drei Profilen und individuellen Einstellungen

Im Hauptmenue koennen mehrere Aktionen auf einmal ausgewaehlt werden, zum Beispiel
`1,2,4,6`. Die Aktionen laufen danach in der angezeigten Menue-Reihenfolge. Mit
`alle` oder `a` werden alle automatischen Aktionen gestartet; das interaktive
Energy Center bleibt davon ausgenommen.

Beim HP-Debloat werden Store-Apps, provisionierte Pakete und klassische
Desktop-Programme in mehreren Durchlaeufen entfernt. Danach werden verwaiste
HP-Dienste, Aufgaben, Verknuepfungen und Produktordner bereinigt. HP Support
Assistant sowie seine Support-Framework-Komponenten bleiben erhalten. Treiber,
Firmware und BIOS-Komponenten werden aus Sicherheitsgruenden nicht entfernt.

Im Energy Center lassen sich Netz- und Akkubetrieb getrennt konfigurieren:
- Bildschirm-, Standby-, Ruhezustand- und Festplatten-Zeitlimits
- Prozessor-Minimum und -Maximum
- Selektives USB-Energiesparen
- PCI-Express-Energiesparen ueber die Profile
- Schnellstart und Ruhezustand jeweils aktivieren oder deaktivieren

## Zweck
- Installiert vordefinierte Software (inkl. Chocolatey)
- Fuehrt Custom-Installer aus
- Verwalten lokaler Benutzer und Domain/Workgroup-Join
- Setzt Energieoptionen
- Speichert/Laedt eine Config-Datei
- Sichert/Restored Browser-Profile inkl. optionalem Passwort-Backup
- Migration lokaler Benutzerdaten (ohne komplettes Profil)

## GUI-Tabs
1. Install
2. Custom
3. System
4. Migration
5. Browser
6. Energie
7. Config

## Browser-Backup / Restore
- Sichert Browser-Profile in einen Backup-Ordner (lokal + roaming Pfade).
- Unterstuetzte Browser (automatische Erkennung):
  - Chrome, Edge, Brave, Chromium, Vivaldi
  - Firefox
  - Opera, Opera GX
- Optionaler DPAPI-Backup/Restore fuer Passwoerter (Chromium-basiert).

Wichtig:
- Browser vor Backup/Restore schliessen.
- DPAPI funktioniert nur fuer den gleichen Windows-Benutzer (SID).
- Restore ueberschreibt vorhandene Profile.

## Migration (lokal)
- Kopiert nur ausgewaehlte Ordner (z.B. Dokumente, Desktop, Downloads).
- Exportiert eine Programmliste (Registry) fuer Neuinstallation.
- Optional: Thunderbird und Outlook (PST/OST) wenn gefunden.
- Kein komplettes Benutzerprofil (weniger Risiko).
- Backup aendert den Quellrechner nicht (nur Kopie).
- Programminstallation beim Restore: optional ueber lokalen Installer-Ordner (EXE/MSI).
- Falls dort nichts gefunden wird, wird automatisch im Downloads-Ordner gesucht.
- Wenn weiterhin keine Installer gefunden werden, kann optional ueber winget (Internet) installiert werden.
- InstallReport wird unter `MigrationBackup\\Programs\\InstallReport.txt` abgelegt.

## Config-Datei
- Datei: `config.ini` im gleichen Ordner wie die EXE
- Enthalten: App-Liste, Presets, Power-Optionen, Custom-Presets, User, Join
- Nicht enthalten: Browser-Backup Einstellungen (Absicht)

## Voraussetzungen
- Windows (lokale GUI)
- Administratorrechte (App startet sonst nicht)
- Optional: Internet fuer Chocolatey-Install

## Build
Aus dem Ordner `Executable`:
```powershell
.\build.ps1
```

## Sicherheit / Haftung
Dieses Tool kann Systemzustand und Benutzerprofile aendern. Vor produktivem Einsatz Backup pruefen.
