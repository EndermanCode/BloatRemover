# BloatRemover

Windows-Tool fuer die Erstinstallation und System-Setup mit GUI.

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
