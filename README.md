# BloatRemover

BloatRemover ist ein Windows-Werkzeug für die Ersteinrichtung, Bereinigung und
Konfiguration von PCs. Das Projekt enthält eine interaktive PowerShell-CLI und
eine klassische Windows-GUI.

## Schnellstart aus dem `main`-Branch

Den folgenden Befehl in eine normale PowerShell kopieren. Er öffnet eine neue
PowerShell mit Administratorrechten und startet direkt die aktuelle
`BloatRemover.ps1` aus dem `main`-Branch:

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -Command "irm https://raw.githubusercontent.com/EndermanCode/BloatRemover/main/Powershell/BloatRemover.ps1 | iex"'
```

Windows zeigt dabei eine Abfrage der Benutzerkontensteuerung (UAC) an. Für den
Download ist eine Internetverbindung erforderlich.

> [!IMPORTANT]
> Der Schnellstart lädt Code aus diesem Repository und führt ihn direkt aus.
> Prüfe bei produktiven Systemen vorher den Inhalt der
> [`BloatRemover.ps1`](https://github.com/EndermanCode/BloatRemover/blob/main/Powershell/BloatRemover.ps1).

## Lokaler Start

Repository herunterladen oder klonen, PowerShell als Administrator öffnen und
im Projektordner ausführen:

```powershell
.\Powershell\BloatRemover.ps1
```

Eine bestimmte JSON-Konfiguration kann vollständig unbeaufsichtigt gestartet
werden:

```powershell
.\Powershell\BloatRemover.ps1 -ConfigPath "E:\BloatRemoverConfigs\SAP-Arbeitsplatz.json"
```

## Funktionen der PowerShell-CLI

Das Hauptmenü stellt folgende Aktionen bereit:

| Auswahl | Funktion |
| --- | --- |
| `1` | HP-Bloatware entfernen |
| `2` | Standard-Apps über WinGet installieren |
| `3` | Windows-Updates installieren |
| `4` | Taskleiste und Startmenü bereinigen |
| `5` | Energy Center öffnen |
| `6` | .NET Framework 3.5 installieren |
| `7` | WinGet-Paketliste anzeigen |
| `A` | Menüpunkte 1 bis 7 nacheinander ausführen |
| `B` | JSON-Konfiguration erstellen |
| `C` | JSON-Konfiguration auswählen und ausführen |
| `E` | JSON-Konfiguration bearbeiten |
| `U` | JSON-Konfiguration auf das aktuelle Schema aktualisieren |

Mehrere Aktionen können kommasepariert gewählt werden, zum Beispiel `1,2,4,6`.
Sie werden anschließend in der angezeigten Menüreihenfolge ausgeführt. Nach dem
Abschluss kann Windows Explorer optional neu gestartet werden.

### HP-Bloatware entfernen

Die Bereinigung entfernt passende Store-Apps, provisionierte Pakete und
klassische Desktop-Programme in mehreren Durchläufen. Anschließend werden
verwaiste HP-Dienste, Aufgaben, Verknüpfungen und Produktordner bereinigt.

Folgende Komponenten bleiben bewusst erhalten:

- HP Support Assistant und die zugehörigen Support-Frameworks
- Treiber
- Firmware- und BIOS-Komponenten

### Energy Center

Das Energy Center bietet drei vorkonfigurierte Profile:

- Energiesparend
- Ausgeglichen
- Leistung

Zusätzlich lassen sich Werte für Netz- und Akkubetrieb getrennt anpassen:

- Bildschirm-, Standby-, Ruhezustand- und Festplatten-Zeitlimits
- Prozessor-Minimum und -Maximum
- selektives USB-Energiesparen
- PCI-Express-Energiesparen über die Profile
- Schnellstart und Ruhezustand

## JSON-Konfigurationen

Mit JSON-Profilen können wiederkehrende PC-Einrichtungen vorbereitet und
unbeaufsichtigt ausgeführt werden. Eine Beispieldatei befindet sich unter
[`Powershell/CustomConfig.example.json`](Powershell/CustomConfig.example.json).

### Builder, Editor und Schema-Upgrader

- Der **Config Builder** erstellt ein neues Profil und speichert es lokal oder
  unter `BloatRemoverConfigs` auf einem erkannten USB-Laufwerk.
- Der **Config Editor** bearbeitet Einstellungen, Aktionen, Programme,
  Deinstallationen, Reihenfolge und Energieoptionen.
- Der **Schema-Upgrader** aktualisiert eine einzelne oder alle gefundenen
  Konfigurationen auf das aktuelle Schema. Vor Änderungen wird eine datierte
  `*.schema-vN-backup-*.bak`-Sicherung angelegt. Neuere, unbekannte
  Schema-Versionen werden nicht heruntergestuft.

### Automatische Erkennung und Startverhalten

Beim lokalen Skriptstart werden gültige Konfigurationen an folgenden Orten
gesucht:

- neben dem Skript
- in lokalen `Configs`-Ordnern
- in `BloatRemoverConfigs` auf eingebundenen Laufwerken
- direkt im Stamm eingebundener Laufwerke

Ungültige Dateien und `*.example.json` werden ignoriert. Das Feld `startupMode`
bestimmt das Verhalten:

- `prompt`: vor dem Ausführen nachfragen
- `automatic`: Profil sofort und ohne Rückfrage ausführen

Mit `continueToMainMenuAfterStartup: true` wird nach einer automatisch
ausgeführten Startkonfiguration das Hauptmenü geöffnet. Ein expliziter Start mit
`-ConfigPath` bleibt dagegen unbeaufsichtigt und beendet das Skript anschließend.

### Unterstützte Aktionen

Ein Profil kann unter anderem enthalten:

- WinGet-Pakete installieren oder deinstallieren
- lokale EXE- und MSI-Installer ausführen
- Appx-/MSIX-Pakete entfernen
- klassische Desktop-Programme deinstallieren
- Dateien an feste Zielpfade kopieren und vorhandene Dateien sichern
- den vollständigen HP-Debloat als `runTask` mit `hpDebloat` ausführen
- Energieprofile und einzelne Energieoptionen konfigurieren

Portable Installer werden im Ordner `Installers`, Quelldateien für Ersetzungen
im Ordner `Files` neben der JSON-Datei abgelegt. Relative Pfade und optionale
SHA-256-Prüfsummen sorgen dafür, dass ein Profil gemeinsam mit seinen Dateien
transportiert werden kann.

Mit `skipIfAlreadyApplied: true` prüft das Skript vor jeder Aktion den
Zielzustand. Bereits erledigte Aktionen werden mit `[SKIP]` protokolliert. Wenn
keine Änderung erforderlich war, wird auch ein konfigurierter Explorer-Neustart
übersprungen.

### Hinweise zu Installationen und Deinstallationen

- WinGet-Programme können im Builder aus einer Checkliste gewählt werden.
- Store-Apps und klassische Programme werden aus den auf dem PC erkannten,
  entfernbaren Anwendungen ausgewählt.
- Windows-Kernpakete, Frameworks, Microsoft Store, App Installer und HP Support
  Assistant werden nicht zur Entfernung angeboten.
- EXE-Installer benötigen passende Silent-Parameter des Herstellers.
- Microsoft-365-Click-to-Run wird mit dem registrierten
  `OfficeClickToRun.exe`-Befehl deinstalliert. Offene Office-Anwendungen können
  dabei geschlossen werden; ungespeicherte Dokumente sollten vorher gesichert
  werden.

## Windows-GUI

Die GUI bündelt die Funktionen in folgenden Bereichen:

1. Install
2. Custom
3. System
4. Migration
5. Browser
6. Energie
7. Config

### Browser-Backup und -Wiederherstellung

Unterstützt werden automatisch erkannte Profile von:

- Chrome, Edge, Brave, Chromium und Vivaldi
- Firefox
- Opera und Opera GX

Für Chromium-basierte Browser ist optional ein DPAPI-Backup der Passwörter
möglich. DPAPI funktioniert nur mit demselben Windows-Benutzer beziehungsweise
derselben SID. Browser müssen vor dem Backup oder der Wiederherstellung beendet
werden. Eine Wiederherstellung überschreibt vorhandene Profile.

### Lokale Migration

Die Migration kopiert ausgewählte Benutzerordner wie Dokumente, Desktop und
Downloads, aber kein vollständiges Benutzerprofil. Zusätzlich können eine
Programmliste sowie gefundene Thunderbird- und Outlook-Daten gesichert werden.

Bei der Wiederherstellung werden Programme optional aus einem lokalen
Installer-Ordner, dem Downloads-Ordner oder über WinGet installiert. Der Bericht
wird unter `MigrationBackup\Programs\InstallReport.txt` gespeichert.

### GUI-Konfiguration

Die Datei `config.ini` liegt neben der EXE und enthält unter anderem App-Listen,
Presets, Energieoptionen, Benutzer- und Join-Einstellungen. Einstellungen für
Browser-Backups werden bewusst nicht darin gespeichert.

## Voraussetzungen

- Windows
- Administratorrechte
- App Installer beziehungsweise WinGet für Installationen per PowerShell
- Internetzugang für den Schnellstart sowie WinGet- oder
  Chocolatey-Installationen

## Projektstruktur

```text
BloatRemover/
├── Executable/                 # Windows-GUI, Konfiguration und Build-Skript
├── Powershell/
│   ├── BloatRemover.ps1        # PowerShell-CLI
│   └── CustomConfig.example.json
└── README.md
```

## GUI bauen

Im Ordner `Executable` ausführen:

```powershell
.\build.ps1
```

## Sicherheit und Haftung

BloatRemover verändert installierte Programme, Windows-Komponenten,
Energieoptionen und gegebenenfalls Benutzerdateien. Vor dem produktiven Einsatz
sollte ein aktuelles und geprüftes Backup vorhanden sein. Konfigurationen und
Silent-Parameter sollten zuerst auf einem Testsystem geprüft werden.
