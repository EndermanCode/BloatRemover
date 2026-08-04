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
- WinGet-Paketliste anzeigen
- Energy Center mit drei Profilen und individuellen Einstellungen

Im Hauptmenue koennen mehrere Aktionen auf einmal ausgewaehlt werden, zum Beispiel
`1,2,4,6`. Die Aktionen laufen danach in der angezeigten Menue-Reihenfolge. Mit
`alle` oder `a` werden die Menuepunkte 1 bis 7 der Reihe nach gestartet. Das
Energy Center wird dabei als interaktives Untermenue geoeffnet; nach der Rueckkehr
laufen die nachfolgenden Aktionen weiter. Eine zusaetzliche Sammelbestaetigung
ist nicht erforderlich.

Beim HP-Debloat werden Store-Apps, provisionierte Pakete und klassische
Desktop-Programme in mehreren Durchlaeufen entfernt. Danach werden verwaiste
HP-Dienste, Aufgaben, Verknuepfungen und Produktordner bereinigt. HP Support
Assistant sowie seine Support-Framework-Komponenten bleiben erhalten. Treiber,
Firmware und BIOS-Komponenten werden aus Sicherheitsgruenden nicht entfernt.

Die Standard-Apps werden ueber WinGet installiert. Das Skript beendet oder
startet Windows Explorer waehrend der Bereinigung nicht automatisch. Erst am
Ende der ausgewaehlten Aktionen kann optional ein Explorer-Neustart ausgefuehrt
werden.

## PowerShell JSON Config Builder

Im Hauptmenue stehen zusaetzliche JSON-Werkzeuge bereit:

- `B`: Erstellt gefuehrt ein externes JSON-Profil und speichert es lokal oder
  unter `BloatRemoverConfigs` auf einem erkannten USB-Stick.
- `C`: Waehlt ein vorhandenes JSON-Profil aus und fuehrt danach alle enthaltenen
  Aktionen ohne weitere Rueckfragen aus.
- `E`: Oeffnet den Config Editor mit einer Uebersicht aller aktuellen Settings
  und Aktionen. Dort koennen Programme, Deinstallationen, Reihenfolge und
  Energieeinstellungen nachtraeglich bearbeitet werden.
- `U`: Aktualisiert eine einzelne, manuell angegebene oder alle gefundenen
  Configs auf das aktuell vom Skript unterstuetzte JSON-Schema.

Der Schema-Upgrader migriert unter anderem alte `applications`-Listen nach
`actions`, ergaenzt Startverhalten, Zielzustandspruefung, Erkennungsnamen und
Standardwerte neuer Aktionstypen. Unbekannte eigene JSON-Felder bleiben erhalten.
Vor jeder tatsaechlichen Aenderung wird neben der Config eine datierte
`*.schema-vN-backup-*.bak`-Sicherung angelegt. Configs mit einer neueren, dem
Skript unbekannten Schema-Version werden niemals heruntergestuft. Bereits aktuelle
Dateien werden ohne neue Sicherung uebersprungen.

Beim normalen Skriptstart werden gueltige Custom-Configs automatisch gesucht.
Gefunden werden JSON-Dateien neben dem Skript, in lokalen `Configs`-Ordnern,
unter `BloatRemoverConfigs` und direkt im Stamm eingebundener Laufwerke. Fremde,
ungueltige und `*.example.json`-Dateien werden ignoriert. Das Feld `startupMode`
legt das Verhalten eines gefundenen Profils fest: `prompt` fragt vor der Ausfuehrung,
`automatic` startet es sofort ohne Eingabe. Bestehende Profile ohne dieses Feld
verwenden weiterhin den sicheren Standard `prompt`. Sind mehrere Profile explizit
auf `automatic` gesetzt, werden sie der Reihe nach ausgefuehrt.

Profile koennen WinGet-, EXE- und MSI-Installationen sowie Deinstallationen per
exakter WinGet-ID, installiertem Programmnamen oder Appx/MSIX-Paketnamen enthalten. Store-Apps
werden im Builder und Editor direkt aus einer Checkliste der auf dem PC installierten,
entfernbaren Apps gewaehlt. Die Auswahl entfernt auch ein passendes provisioniertes
Paket, damit die App nicht bei einem neuen Benutzer erneut auftaucht. Windows-Kernpakete,
Frameworks, Microsoft Store, App Installer und HP Support Assistant werden nicht angeboten.
Klassische Programme aus `Systemsteuerung > Programme und Features` stehen ebenfalls
als Checkliste bereit. Das Profil speichert deren Anzeigenamen und ermittelt den aktuellen
Deinstallationsbefehl erst auf dem jeweiligen Ziel-PC. MSI-Pakete und bekannte Uninstaller
werden dabei mit stillen Parametern gestartet.
Microsoft-365-Click-to-Run-Eintraege werden gesondert behandelt: Der originale
`OfficeClickToRun.exe`-Befehl aus der Registry bleibt erhalten und wird um
`displaylevel=false` sowie `forceappshutdown=true` ergaenzt. Dadurch werden keine
ungueltigen generischen `/quiet`-Parameter mehr angehaengt. Offene Office-Programme
koennen dabei geschlossen werden; nicht gespeicherte Dokumente sollten daher vor
der unbeaufsichtigten Ausfuehrung vermieden werden.
EXE/MSI-Dateien
koennen in den portablen Unterordner `Installers` kopiert werden. Dabei werden
relative Pfade und eine SHA-256-Pruefsumme in der JSON-Datei gespeichert.
WinGet-Pakete werden im Builder aus einer fertigen Checkliste gewaehlt: mit den
Pfeiltasten navigieren, mit der Leertaste markieren und mit Enter uebernehmen.
Die WinGet-IDs muessen dabei nicht manuell gesucht oder eingegeben werden.
Lange Checklisten scrollen automatisch; Bild auf/ab, Pos1 und Ende werden ebenfalls
unterstuetzt. Unter der Liste werden sichtbarer Bereich und Anzahl der Markierungen angezeigt.

Der Editor fuer die Aktionsreihenfolge zeigt ebenfalls die vollstaendige, scrollbare
Aktionsliste. Mit Leertaste oder Enter wird eine Aktion aufgenommen, mit Pfeiltasten,
Bild auf/ab, Pos1 oder Ende an die gewuenschte Position verschoben und mit Leertaste
oder Enter wieder abgelegt. Danach koennen weitere Aktionen verschoben werden. `S`
uebernimmt die neue Reihenfolge in den Config Editor; `Esc` verwirft sie.

Mit `Datei automatisch ersetzen` koennen Profile Dateien vom USB-Stick auf feste
Zielpfade kopieren, beispielsweise Anwendungs-Konfigurationen nach
`%ProgramData%\Hersteller\config.ini`. Der Builder legt portable Quelldateien im
Unterordner `Files` neben der JSON ab und speichert deren SHA-256-Pruefsumme.
Zielordner koennen automatisch angelegt werden. Eine vorhandene Zieldatei wird
standardmaessig zuvor unter `.BloatRemoverBackups` im Zielordner gesichert. Die
eigentliche Ersetzung erfolgt erst beim unbeaufsichtigten Config-Start und ohne
weitere Rueckfrage.

Der vollstaendige HP-Debloat kann als geordnete Config-Aktion `runTask` mit dem
Task `hpDebloat` aufgenommen werden. Er laeuft an seiner Position in der
Aktionsreihenfolge automatisch ab. HP Support Assistant, seine Support-Frameworks
sowie Treiber, Firmware und BIOS-Komponenten bleiben wie beim Hauptmenue erhalten.

Mit `skipIfAlreadyApplied: true` prueft das Skript vor jeder Config-Aktion den
aktuellen Zielzustand. Bereits installierte Programme, entfernte Store- oder
Desktop-Apps, identische Dateien, ein abgeschlossener HP-Debloat und bereits
passende Energieeinstellungen werden mit `[SKIP]` protokolliert und nicht erneut
ausgefuehrt. Wenn dadurch keine Aenderung notwendig war, wird auch ein im Profil
aktivierter Explorer-Neustart ausgelassen. Bei lokalen EXE/MSI-Installern legt
`detectName` den Erkennungsnamen aus `Programme und Features` fest. Bestehende
Profile ohne `skipIfAlreadyApplied` behalten das bisherige Verhalten.

Der Energieblock eines Profils unterstuetzt die Profile Energiesparend,
Ausgeglichen und Leistung, eigene Zeitlimits fuer Netz- und Akkubetrieb sowie
Schnellstart, Ruhezustand und selektives USB-Energiesparen. Nicht gesetzte Werte
bleiben am Zielrechner unveraendert.

Fuer einen komplett unbeaufsichtigten Start kann die JSON-Datei direkt als
Parameter uebergeben werden:

```powershell
.\Powershell\BloatRemover.ps1 -ConfigPath "E:\BloatRemoverConfigs\SAP-Arbeitsplatz.json"
```

Nach dem Laden laufen alle Aktionen in der Reihenfolge der JSON-Datei. Es gibt
keine Programmauswahl, Bestaetigung oder abschliessende Eingabe. Ob Explorer
anschliessend neu gestartet wird, legt das Feld `restartExplorer` im Profil fest.
Das Skript selbst muss fuer neue Programme oder Profile nicht bearbeitet werden.
Bei EXE-Paketen muessen funktionierende Silent-Parameter eingetragen werden;
andernfalls kann der Hersteller-Installer selbst weiterhin Eingaben verlangen.
Der Aufbau ist zusaetzlich in `Powershell\CustomConfig.example.json` dokumentiert;
die dortigen Namen und SAP-Parameter sind nur Beispiele und muessen zum echten
Herstellerpaket passen.

Im Energy Center lassen sich Netz- und Akkubetrieb getrennt konfigurieren:
- Bildschirm-, Standby-, Ruhezustand- und Festplatten-Zeitlimits
- Prozessor-Minimum und -Maximum
- Selektives USB-Energiesparen
- PCI-Express-Energiesparen ueber die Profile
- Schnellstart und Ruhezustand jeweils aktivieren oder deaktivieren

## Zweck
- Installiert vordefinierte Software (PowerShell ueber WinGet, GUI ueber Chocolatey)
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

## GUI Config-Datei
- Datei: `config.ini` im gleichen Ordner wie die EXE
- Enthalten: App-Liste, Presets, Power-Optionen, Custom-Presets, User, Join
- Nicht enthalten: Browser-Backup Einstellungen (Absicht)

## Voraussetzungen
- Windows (lokale GUI)
- Administratorrechte (App startet sonst nicht)
- App Installer/WinGet fuer die Paketinstallation im PowerShell-Skript
- Optional: Internet fuer WinGet- beziehungsweise Chocolatey-Installationen

## Build
Aus dem Ordner `Executable`:
```powershell
.\build.ps1
```

## Sicherheit / Haftung
Dieses Tool kann Systemzustand und Benutzerprofile aendern. Vor produktivem Einsatz Backup pruefen.
