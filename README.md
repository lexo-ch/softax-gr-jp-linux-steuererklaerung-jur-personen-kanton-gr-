# SofTax GR 2025 JP – Linux Installer

**Die Steuererklärung für den Kanton Graubünden (Juristische Personen) unter Linux nutzen.**

SofTax GR wird offiziell nur für Windows angeboten. Dieses Script ermöglicht es, die Software vollständig unter Linux zu verwenden – ohne Windows, ohne Wine, ohne virtuelle Maschine.

---

## Demo

[SofTax-GR-JP-Linux.webm](https://github.com/user-attachments/assets/4c977ee6-0ad6-453c-96bf-b92b1faab15c)

---

## Was macht das Script?

Das Script führt folgende Schritte durch – **vollautomatisch und transparent**:

| Schritt | Was passiert | Warum |
|---|---|---|
| **1.** | Prüft, ob benötigte Hilfsprogramme installiert sind (`msitools`, `curl`) | Ohne diese kann das Script nicht arbeiten |
| **2.** | Entpackt die offizielle Windows-MSI-Datei | Extrahiert die eigentliche Java-Anwendung |
| **3.** | Entfernt Windows-spezifische Dateien (Windows-JRE, .exe) | Werden unter Linux nicht benötigt |
| **4.** | Lädt eine Linux-Java-Laufzeitumgebung herunter (~311 MB) | [Azul Zulu JDK FX 21](https://www.azul.com/downloads/#zulu) – enthält JavaFX, das SofTax benötigt |
| **5.** | Erstellt ein Start-Script (`softaxjp2025.sh`) | Startet SofTax mit den richtigen Java-Einstellungen |
| **6.** | Erstellt Desktop- und/oder Menü-Verknüpfungen (optional) | Damit SofTax wie ein normales Programm gestartet werden kann |

> **Das Script verändert nichts am System ausserhalb des Installationsordners** (ausser den optionalen Verknüpfungen). Es werden keine Systemdateien angefasst.

---

## Unterstützte Distributionen

| Distribution | Paketmanager | Getestet |
|---|---|---|
| Ubuntu | `apt` | ✔ |
| Linux Mint | `apt` | ✔ |
| Debian | `apt` | – |
| Fedora | `dnf` | – |
| openSUSE | `zypper` | – |
| Arch Linux / Manjaro | `pacman` | – |
| NixOS | `nix-env` | – |
| Void Linux | `xbps-install` | – |
| RHEL / CentOS / Rocky / Alma | `dnf` | – |

## Anleitung

### Voraussetzungen

- Ein Linux-System (64-Bit, x86_64)
- Die offizielle MSI-Datei: **`SofTax2025JP.msi`**
  (Download von der [offiziellen SofTax-Webseite](https://www.softax.ch))

### Installation – Schritt für Schritt

**1. Script herunterladen**

Laden Sie die Datei `install-softax-linux.sh` herunter und legen Sie sie in den **gleichen Ordner** wie die MSI-Datei.

Zum Beispiel in Ihren `Downloads`-Ordner:

```
~/Downloads/
├── install-softax-linux.sh
└── SofTax2025JP.msi
```

**2. Script ausführbar machen**

Klicken Sie mit der **rechten Maustaste** auf `install-softax-linux.sh` → **«Eigenschaften»**.

Setzen Sie den Haken bei **«Der Datei erlauben, sie als Programm auszuführen»** und schliessen Sie das Fenster.

<img width="541" height="386" alt="Eigenschaften-Dialog: Datei als Programm ausführbar machen" src="https://github.com/user-attachments/assets/3caa40ef-f218-453e-8e83-8eb5ede50ebe" />

**3. Script starten**

**Doppelklicken** Sie auf `install-softax-linux.sh`.

Es erscheint ein Dialog – wählen Sie **«Im Terminal ausführen»**.

<img width="653" height="179" alt="Dialog: Im Terminal ausführen" src="https://github.com/user-attachments/assets/57da8260-9f14-4425-a8f9-8fbb9a43a25e" />

<details>
<summary><strong>Alternative: Über das Terminal starten</strong></summary>

&nbsp;

Öffnen Sie ein Terminal (z.B. Rechtsklick in den Ordner → **«Im Terminal öffnen»**) und geben Sie ein:

```bash
cd ~/Downloads
chmod +x install-softax-linux.sh
./install-softax-linux.sh
```

</details>

&nbsp;

Das Script führt Sie durch den Installationsvorgang. Wenn Hilfsprogramme fehlen, bietet es an, diese automatisch zu installieren (dafür wird Ihr Passwort benötigt).

**4. SofTax starten**

Nach der Installation können Sie SofTax starten:

- Über die **Desktop-Verknüpfung** (Doppelklick auf das Icon)
- Über das **Anwendungsmenü** (unter «Büro»)
- Über das **Terminal**:
  ```bash
  cd "SofTax GR 2025 JP"
  ./softaxjp2025.sh
  ```

---

## Häufige Fragen

<details>
<summary><strong>Ist das legal?</strong></summary>

Dieses Script installiert keine raubkopierte Software. Es verwendet die offizielle MSI-Datei, die Sie selbst von der SofTax-Webseite herunterladen. Die Steuersoftware ist kostenlos und für alle Steuerpflichtigen des Kantons Graubünden bestimmt.
</details>

<details>
<summary><strong>Wird Windows oder Wine benötigt?</strong></summary>

Nein. SofTax ist eine Java-Anwendung. Das Script ersetzt lediglich die Windows-Java-Laufzeitumgebung durch eine Linux-Version. Wine wird nicht benötigt.
</details>

<details>
<summary><strong>Kann ich SofTax wieder deinstallieren?</strong></summary>

Ja – löschen Sie einfach den Ordner `SofTax GR 2025 JP` und die Desktop-/Menü-Verknüpfung. Es werden keine Systemdateien verändert.
</details>

<details>
<summary><strong>Das Script meldet «sudo-Berechtigung fehlt»</strong></summary>

Ihr Benutzerkonto hat keine Administratorrechte. Bitten Sie einen Administrator, Ihren Benutzer zur `sudo`-Gruppe hinzuzufügen:

```bash
sudo usermod -aG sudo IhrBenutzername    # Debian/Ubuntu/Mint
sudo usermod -aG wheel IhrBenutzername   # Fedora/Arch/openSUSE
```

Danach ab- und wieder anmelden.
</details>

---

## Haftungsausschluss

> **Dieses Projekt steht in keiner Verbindung zur Steuerverwaltung des Kantons Graubünden, zur Abraxas Informatik AG oder zu SofTax.**
>
> Die Software wird **«as is»** (so wie sie ist) bereitgestellt, **ohne jegliche Gewährleistung**. Die Nutzung erfolgt auf eigene Verantwortung. Der Autor übernimmt keine Haftung für Schäden, Datenverlust oder fehlerhafte Steuererklärungen, die durch die Verwendung dieses Scripts entstehen könnten.
>
> Überprüfen Sie Ihre Steuererklärung immer sorgfältig, unabhängig davon, auf welchem Betriebssystem Sie die Software verwenden.

---

## Lizenz

Dieses Projekt ist unter der [MIT-Lizenz](LICENSE) veröffentlicht – Sie dürfen es frei verwenden, verändern und weitergeben.

Das Script erkennt die Distribution automatisch und zeigt den passenden Installationsbefehl an.

