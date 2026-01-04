# NaoBootloader - Bootable USB Media Creation

Dieses Projekt bietet drei Optionen zum Erstellen bootfähiger USB-Laufwerke für verschiedene Systemtypen.

## Verfügbare Modi

### 1. BIOS Bootable (Legacy)
```bash
sudo ./start.sh bootable
```

- **Für wen:** Ältere Computer (2000-2010)
- **Partitionstyp:** MBR (Master Boot Record)
- **Vorteile:** Einfaches Setup, universelle Kompatibilität mit älteren Systemen
- **Nachteile:** Keine UEFI/EFI-Unterstützung

### 2. EFI Bootable (Modern)
```bash
sudo ./start.sh efi
```

- **Für wen:** Moderne Systeme (MacBooks, Windows 8+, Linux Systeme ab 2010)
- **Partitionstyp:** GPT (GUID Partition Table)
- **Vorteile:** Native UEFI/EFI-Unterstützung, größere Boot-Partition
- **Nachteile:** Funktioniert nicht auf älteren BIOS-Systemen

### 3. Hybrid Bootable (Universal)
```bash
sudo ./start.sh hybrid
```

- **Für wen:** Gemischte Umgebungen, wenn Sie nicht sicher sind
- **Partitionstyp:** Hybrid MBR/FAT32
- **Vorteile:** Funktioniert auf sowohl alten BIOS- als auch modernen EFI-Systemen
- **Nachteile:** Etwas komplexeres Setup
- **Empfehlung:** Diese Option verwenden, wenn Sie unsicher sind

## Schnellstart

### Schritt 1: Binaries erstellen
```bash
./start.sh build
```

### Schritt 2: Bootable Medium wählen

**Für MacBooks oder moderne Systeme:**
```bash
sudo ./start.sh hybrid
```

**Für Legacy-Systeme:**
```bash
sudo ./start.sh bootable
```

**Für genaue Kompatibilität:**
```bash
./start.sh info
```

### Schritt 3: Booten

1. USB-Laufwerk in den Zielcomputer einführen
2. Während des Startvorgangs die Boot-Menü-Taste drücken:
   - **MacBooks:** `Option/Alt` beim Starten
   - **Dell/HP/Lenovo:** `F12`, `F9`, oder `ESC`
   - **ASUS:** `DEL` oder `F2`
3. USB-Laufwerk aus Boot-Menü auswählen
4. Bootloader ausführen beobachten

## Anforderungen

### Hardware
- USB-Laufwerk (mind. 100MB)
- Zielcomputer mit funktionierendem BIOS/UEFI

### Software
- macOS Ventura/Sonoma oder neuer
- Kompilierte Binaries (bootloader.bin, kernel.bin)
- Root/sudo-Berechtigung für USB-Schreiben

### Abhängigkeiten
```bash
brew install nasm        # Für Kompilierung
brew install qemu        # Für Tests (optional)
```

## Troubleshooting

### USB-Laufwerk wird nicht erkannt
- Anderer USB-Anschluss testen
- Anderes USB-Laufwerk versuchen
- BIOS Boot-Reihenfolge überprüfen

### Berechtigungsfehler
- Befehl mit `sudo` präfixieren:
  ```bash
  sudo ./start.sh bootable
  ```

### Binaries nicht gefunden
- Erst erstellen: `./start.sh build`
- Status prüfen: `./start.sh status`

### USB immer noch nicht bootbar
```bash
./start.sh info    # Sehen Sie alle Optionen an
./start.sh help    # Alle verfügbaren Befehle
```

## Befehlsreferenz

```bash
./start.sh build           # Bootloader kompilieren
./start.sh clean           # Build-Artefakte löschen
./start.sh bootable        # BIOS bootbares Medium erstellen
./start.sh efi             # EFI bootbares Medium erstellen
./start.sh hybrid          # Hybrid (BIOS+EFI) bootbares Medium erstellen
./start.sh info            # Bootable-Optionen und Anleitung anzeigen
./start.sh test            # Tests in QEMU ausführen
./start.sh slow            # Slow-Motion Debug (für Bootloader-Debugging)
./start.sh qemu            # Schneller QEMU-Test
./start.sh status          # Projekt-Status anzeigen
./start.sh help            # Hilfe anzeigen
```

## Ausgangsdateistruktur

```
NaoBootloader-1/
├── bootloader.bin          # Stage 1 Bootloader (512 bytes)
├── stage2.bin              # Stage 2 Loader (1KB)
├── kernel.bin              # Kernel (1.3KB)
├── scripts/
│   ├── lib.sh              # Gemeinsame Logging-Bibliothek
│   ├── macos_bootable.sh   # BIOS Bootable Creator
│   ├── create_efi_bootable.sh   # EFI Bootable Creator
│   ├── create_hybrid_bootable.sh # Hybrid Bootable Creator
│   ├── bootable_info.sh    # Bootable Optionen Anleitung
│   ├── test_qemu.sh        # QEMU Schnelltest
│   ├── test_slow.sh        # QEMU Slow-Motion Test
│   └── ...
├── start.sh                # Haupteinstiegspunkt
└── Makefile                # Build-Konfiguration
```

## Häufig gestellte Fragen

### F: Welche Option sollte ich verwenden?
A: Wenn Sie nicht sicher sind, verwenden Sie **Hybrid**. Es funktioniert überall.

### F: Kann ich denselben USB auf mehreren Computern booten?
A: Ja! Jeder Modus funktioniert auf allen Geräten, für die er bestimmt ist:
- BIOS: auf allen Legacy-Systemen
- EFI: auf allen modernen Systemen
- Hybrid: auf allen Systemen

### F: Können meine Daten auf dem USB erhalten bleiben?
A: Nein. Das Erstellen eines bootbaren Mediums ** löscht alle Daten** auf dem USB-Laufwerk.

### F: Wie viel Platz benötigt das Bootloader?
A: Nur ein paar KB. Der Rest des USB-Laufwerks ist für zusätzliche Dateien verfügbar.

### F: Kann ich mehrere Bootloader auf einem USB haben?
A: Mit den aktuellen Scripts nein, aber Sie können die Scripts modifizieren, um dies zu unterstützen.

## Weitere Informationen

Führen Sie `./start.sh info` aus, um eine detaillierte Anleitung zu erhalten.

Führen Sie `./start.sh help` aus, um alle verfügbaren Befehle zu sehen.

---

**Letzte Aktualisierung:** Januar 2026
