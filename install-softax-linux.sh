#!/usr/bin/env bash
# ============================================================================
# SofTax GR 2025 JP – Linux Installer
# Extrahiert die MSI-Datei und richtet eine lauffähige Linux-Umgebung ein.
#
# Verwendung:
#   ./install-softax-linux.sh [SofTax2025JP.msi]
#
# Wenn kein Argument angegeben wird, sucht das Skript nach einer .msi-Datei
# im gleichen Verzeichnis.
# ============================================================================

set -e

ZULU_VERSION="zulu21.46.19-ca-fx-jdk21.0.9-linux_x64"
ZULU_URL="https://cdn.azul.com/zulu/bin/${ZULU_VERSION}.tar.gz"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Farben und Formatierung ---

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null)" -ge 8 ] 2>/dev/null; then
    BOLD=$(tput bold)
    DIM=$(tput dim)
    RESET=$(tput sgr0)
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
else
    BOLD="" DIM="" RESET="" GREEN="" RED="" YELLOW="" CYAN="" WHITE=""
fi

print_banner() {
    echo ""
    echo "${CYAN}${BOLD}  ╔═══════════════════════════════════════════════════╗${RESET}"
    echo "${CYAN}${BOLD}  ║                                                   ║${RESET}"
    echo "${CYAN}${BOLD}  ║       SofTax GR 2025 JP  –  Linux Installer       ║${RESET}"
    echo "${CYAN}${BOLD}  ║       Steuererklärung Kanton Graubünden (JP)       ║${RESET}"
    echo "${CYAN}${BOLD}  ║                                                   ║${RESET}"
    echo "${CYAN}${BOLD}  ╚═══════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    local step="$1" total="$2" desc="$3"
    echo "${BOLD}${WHITE}  [${CYAN}${step}${WHITE}/${total}]${RESET}  ${desc}"
}

print_ok() {
    echo "${GREEN}${BOLD}    ✔${RESET}  ${DIM}$1${RESET}"
}

print_skip() {
    echo "${YELLOW}${BOLD}    ➜${RESET}  ${DIM}$1${RESET}"
}

print_error() {
    echo ""
    echo "${RED}${BOLD}  ✖ FEHLER:${RESET} $1"
}

print_warn() {
    echo ""
    echo "${YELLOW}${BOLD}  ⚠ WARNUNG:${RESET} $1"
}

print_info() {
    echo "${DIM}       $1${RESET}"
}

print_separator() {
    echo "${DIM}  ─────────────────────────────────────────────────${RESET}"
}

# --- Distributions-Erkennung ---

detect_distro() {
    DISTRO_ID=""
    DISTRO_LIKE=""
    DISTRO_NAME=""

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_LIKE="$ID_LIKE"
        DISTRO_NAME="$NAME"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_ID="$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')"
        DISTRO_NAME="$DISTRIB_DESCRIPTION"
    fi
}

get_pkg_info() {
    PKG_INSTALL_CMD=""
    PKG_NAME_PREFIX=""
    PKG_GUI_NAME=""
    PKG_GUI_HINT=""
    PKG_NIX_HINT=""

    case "$DISTRO_ID" in
        ubuntu)
            PKG_INSTALL_CMD="sudo apt install"
            PKG_GUI_NAME="Ubuntu Software"
            ;;
        linuxmint)
            PKG_INSTALL_CMD="sudo apt install"
            PKG_GUI_NAME="Anwendungsverwaltung (mintinstall)"
            ;;
        debian)
            PKG_INSTALL_CMD="sudo apt install"
            PKG_GUI_NAME="GNOME Software"
            ;;
        fedora)
            PKG_INSTALL_CMD="sudo dnf install"
            PKG_GUI_NAME="GNOME Software"
            ;;
        rhel|centos|rocky|alma|almalinux)
            PKG_INSTALL_CMD="sudo dnf install"
            ;;
        opensuse*|sles)
            PKG_INSTALL_CMD="sudo zypper install"
            PKG_GUI_NAME="YaST Software"
            ;;
        arch|manjaro|endeavouros)
            PKG_INSTALL_CMD="sudo pacman -S"
            PKG_GUI_NAME="Software hinzufügen/entfernen (Pamac)"
            ;;
        void)
            PKG_INSTALL_CMD="sudo xbps-install"
            ;;
        nixos)
            PKG_INSTALL_CMD="nix-env -iA"
            PKG_NAME_PREFIX="nixpkgs."
            PKG_NIX_HINT="  ${DIM}Tipp: Für temporäre Nutzung ohne Installation:${RESET}
  ${BOLD}nix-shell -p${RESET}"
            ;;
        *)
            # Fallback über ID_LIKE
            case "$DISTRO_LIKE" in
                *debian*|*ubuntu*)
                    PKG_INSTALL_CMD="sudo apt install"
                    ;;
                *rhel*|*fedora*|*centos*)
                    PKG_INSTALL_CMD="sudo dnf install"
                    ;;
                *suse*)
                    PKG_INSTALL_CMD="sudo zypper install"
                    ;;
                *arch*)
                    PKG_INSTALL_CMD="sudo pacman -S"
                    ;;
                *)
                    PKG_INSTALL_CMD="sudo apt install"
                    ;;
            esac
            ;;
    esac

    if [ -n "$PKG_GUI_NAME" ]; then
        PKG_GUI_HINT="  Alternativ können Sie die Pakete auch über die
  «${BOLD}${PKG_GUI_NAME}${RESET}» (grafische Paketverwaltung) installieren."
    fi
}

# Formatiert Paketnamen mit optionalem Prefix (z.B. "nixpkgs." für NixOS)
format_pkg_list() {
    local result=""
    for pkg in $1; do
        result="$result ${PKG_NAME_PREFIX}${pkg}"
    done
    echo "$result"
}

# Prüft, ob der aktuelle Benutzer sudo verwenden kann.
# Gibt 0 zurück wenn sudo möglich/nicht nötig, 1 wenn nicht.
check_sudo() {
    # Kein sudo nötig wenn bereits root
    [ "$(id -u)" -eq 0 ] && return 0

    # Kein sudo nötig wenn der Befehl kein sudo enthält (z.B. NixOS)
    case "$PKG_INSTALL_CMD" in
        sudo\ *) ;;
        *) return 0 ;;
    esac

    # Prüfe ob sudo überhaupt installiert ist
    if ! command -v sudo >/dev/null 2>&1; then
        print_error "«sudo» ist nicht installiert."
        echo ""
        echo "  Die automatische Installation benötigt Root-Rechte."
        echo "  Bitte installieren Sie die Pakete als Root manuell."
        echo ""
        return 1
    fi

    # Prüfe Gruppenmitgliedschaft (sudo/wheel)
    local user_groups
    user_groups="$(id -nG)"
    local has_sudo_group=false
    for grp in $user_groups; do
        case "$grp" in
            sudo|wheel) has_sudo_group=true; break ;;
        esac
    done

    if ! $has_sudo_group; then
        # Letzte Chance: sudo -n prüft ob sudoers-Eintrag existiert (z.B. per Benutzername)
        if ! sudo -n true 2>/dev/null; then
            print_error "Ihr Benutzer «$(whoami)» hat keine sudo-Berechtigung."
            echo ""
            echo "  Die automatische Installation benötigt Root-Rechte (sudo)."
            echo "  Ihr Benutzer ist weder in der Gruppe «sudo» noch «wheel»."
            echo ""
            echo "  ${BOLD}Lösung:${RESET} Bitten Sie einen Administrator, folgenden Befehl auszuführen:"
            echo ""
            echo "    ${BOLD}sudo usermod -aG sudo $(whoami)${RESET}  ${DIM}(Debian/Ubuntu/Mint)${RESET}"
            echo "    ${BOLD}sudo usermod -aG wheel $(whoami)${RESET}  ${DIM}(Fedora/Arch/openSUSE)${RESET}"
            echo ""
            echo "  Danach ab- und wieder anmelden, und das Script erneut starten."
            echo ""
            return 1
        fi
    fi

    return 0
}

detect_distro
get_pkg_info

# --- Abhängigkeiten prüfen ---

MISSING_PKGS=""
MISSING_INFO=""

if ! command -v msiextract >/dev/null 2>&1; then
    MISSING_PKGS="$MISSING_PKGS msitools"
    MISSING_INFO="${MISSING_INFO}    ${RED}•${RESET} msitools ${DIM}(MSI-Dateien entpacken)${RESET}\n"
fi

if ! command -v curl >/dev/null 2>&1; then
    MISSING_PKGS="$MISSING_PKGS curl"
    MISSING_INFO="${MISSING_INFO}    ${RED}•${RESET} curl     ${DIM}(JDK herunterladen)${RESET}\n"
fi

if [ -n "$MISSING_PKGS" ]; then
    INSTALL_PKGS="$(format_pkg_list "$MISSING_PKGS")"
    print_banner
    print_error "Folgende Pakete fehlen:"
    echo ""
    echo -e "$MISSING_INFO"
    echo "  Installieren Sie die fehlenden Pakete über das Terminal:"
    echo ""
    echo "    ${BOLD}${PKG_INSTALL_CMD}${INSTALL_PKGS}${RESET}"
    echo ""
    if [ -n "$PKG_NIX_HINT" ]; then
        echo -e "${PKG_NIX_HINT}${MISSING_PKGS}${RESET}"
        echo ""
    fi
    if [ -n "$PKG_GUI_HINT" ]; then
        echo -e "$PKG_GUI_HINT"
        echo "  Suchen Sie dort nach:${BOLD}${MISSING_PKGS}${RESET}"
        echo ""
    fi
    if [ -t 0 ]; then
        if check_sudo; then
            read -r -p "  Soll dieses Script die Pakete jetzt automatisch installieren? [${BOLD}j${RESET}/N] " auto_install
            if [ "$auto_install" = "j" ] || [ "$auto_install" = "J" ]; then
                echo ""
                echo "  ${DIM}Führe aus: ${PKG_INSTALL_CMD}${INSTALL_PKGS}${RESET}"
                echo ""
                if $PKG_INSTALL_CMD $INSTALL_PKGS; then
                    echo ""
                    echo "  ${GREEN}${BOLD}✔${RESET}  Pakete erfolgreich installiert."
                    echo ""
                else
                    echo ""
                    print_error "Installation fehlgeschlagen."
                    echo "  Bitte installieren Sie die Pakete manuell und starten Sie das Script erneut."
                    echo ""
                    exit 1
                fi
            else
                echo ""
                echo "  Abgebrochen. Bitte installieren Sie die Pakete und starten Sie das Script erneut."
                echo ""
                exit 1
            fi
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

# --- MSI-Datei finden ---

if [ -n "$1" ]; then
    MSI_FILE="$(realpath "$1")"
else
    MSI_FILE="$(find "$SCRIPT_DIR" -maxdepth 1 -name '*.msi' -print -quit)"
fi

if [ -z "$MSI_FILE" ] || [ ! -f "$MSI_FILE" ]; then
    print_banner
    print_error "Keine MSI-Datei gefunden."
    echo ""
    echo "  Verwendung: ${BOLD}$0 [Pfad/zur/SofTax2025JP.msi]${RESET}"
    echo ""
    exit 1
fi

INSTALL_DIR="$SCRIPT_DIR"
APP_DIR="$INSTALL_DIR/SofTax GR 2025 JP"
MENU_FILE="$HOME/.local/share/applications/softax-gr-2025-jp.desktop"

TOTAL_STEPS=5

# --- Banner und Infos ---

print_banner

echo "  ${BOLD}MSI-Datei:${RESET}   ${DIM}$MSI_FILE${RESET}"
echo "  ${BOLD}Zielordner:${RESET}  ${DIM}$APP_DIR${RESET}"

print_separator
echo ""

# --- Verknüpfungsauswahl ---

echo "  ${BOLD}Welche Verknüpfungen sollen erstellt werden?${RESET}"
echo ""
echo "    ${BOLD}${CYAN}1${RESET})  Desktop-Verknüpfung"
echo "       ${DIM}Erstellt ein Icon auf dem Desktop zum Doppelklicken${RESET}"
echo ""
echo "    ${BOLD}${CYAN}2${RESET})  Menü-Verknüpfung"
echo "       ${DIM}Erscheint im Anwendungsmenü unter \"Büro\"${RESET}"
echo ""
echo "    ${BOLD}${CYAN}3${RESET})  Beides ${DIM}(empfohlen)${RESET}"
echo "       ${DIM}Desktop-Icon und Menüeintrag${RESET}"
echo ""
echo "    ${BOLD}${CYAN}4${RESET})  Keine Verknüpfung"
echo "       ${DIM}Nur Installation – Start über die Kommandozeile${RESET}"
echo ""

while true; do
    read -r -p "  ${BOLD}Auswahl [1-4, Standard: 3]:${RESET} " shortcut_choice
    shortcut_choice="${shortcut_choice:-3}"
    case "$shortcut_choice" in
        1|2|3|4) break ;;
        *) echo "  ${RED}Bitte 1, 2, 3 oder 4 eingeben.${RESET}" ;;
    esac
done

echo ""
print_separator
echo ""

# --- MSI entpacken ---

if [ -d "$APP_DIR" ]; then
    print_warn "Zielordner existiert bereits."
    read -r -p "  Überschreiben? [${BOLD}j${RESET}/N] " answer
    if [ "$answer" != "j" ] && [ "$answer" != "J" ]; then
        echo ""
        echo "  Abgebrochen."
        echo ""
        exit 0
    fi
    rm -rf "$APP_DIR"
    echo ""
fi

print_step 1 $TOTAL_STEPS "MSI-Datei extrahieren"
cd "$INSTALL_DIR"
msiextract "$MSI_FILE" >/dev/null 2>&1
print_ok "Dateien entpackt"

# --- Windows-JRE entfernen ---

print_step 2 $TOTAL_STEPS "Windows-Komponenten entfernen"
rm -rf "$APP_DIR/jre"
rm -f "$APP_DIR/softaxjp2025.exe"
print_ok "Windows-JRE und EXE entfernt"

# --- Linux-JRE herunterladen ---

print_step 3 $TOTAL_STEPS "Linux Java-Laufzeitumgebung einrichten"

if [ -d "$APP_DIR/$ZULU_VERSION" ]; then
    print_skip "Azul Zulu JDK FX bereits vorhanden"
else
    print_info "Lade Azul Zulu JDK FX 21.0.9 herunter (~311 MB)..."
    echo ""
    TMP_FILE=$(mktemp /tmp/zulu21-fx-XXXXXX.tar.gz)
    trap 'rm -f "$TMP_FILE"' EXIT
    curl -L --progress-bar -o "$TMP_FILE" "$ZULU_URL"
    echo ""
    print_info "Entpacke JDK..."
    tar xzf "$TMP_FILE" -C "$APP_DIR"
    rm -f "$TMP_FILE"
    trap - EXIT
fi

ln -sf "$ZULU_VERSION" "$APP_DIR/jre"
print_ok "Java 21.0.9 mit JavaFX bereit"

# --- Startskript erstellen ---

print_step 4 $TOTAL_STEPS "Startskript erstellen"

cat > "$APP_DIR/softaxjp2025.sh" << 'STARTSCRIPT'
#!/bin/bash
# Linux-Startskript für SofTax GR 2025 JP

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

JAVA="$SCRIPT_DIR/jre/bin/java"

if [ ! -x "$JAVA" ]; then
    echo "FEHLER: Java nicht gefunden unter $JAVA"
    echo "Bitte install-softax-linux.sh erneut ausführen."
    exit 1
fi

CP=""
for jar in "$SCRIPT_DIR"/*.jar; do
    if [ -n "$CP" ]; then
        CP="$CP:$jar"
    else
        CP="$jar"
    fi
done

echo "Starte SofTax GR 2025 JP..."
"$JAVA" -version 2>&1 | head -1
echo ""

exec "$JAVA" \
    -cp "$CP" \
    -Djava.library.path="$SCRIPT_DIR" \
    --add-exports=java.base/sun.net.www.protocol.file=ALL-UNNAMED \
    --add-exports=java.desktop/sun.swing=ALL-UNNAMED \
    --add-exports=java.desktop/sun.awt.shell=ALL-UNNAMED \
    --add-exports=java.desktop/com.sun.java.swing.plaf.windows=ALL-UNNAMED \
    --add-exports=java.xml/com.sun.org.apache.xerces.internal.jaxp.datatype=ALL-UNNAMED \
    ch.abraxas.jfw.launch.JfwLauncher
STARTSCRIPT

chmod +x "$APP_DIR/softaxjp2025.sh"
print_ok "softaxjp2025.sh erstellt"

# --- Verknüpfungen erstellen ---

print_step 5 $TOTAL_STEPS "Verknüpfungen erstellen"

create_desktop_entry() {
    local target="$1"
    mkdir -p "$(dirname "$target")"
    cat > "$target" << DESKTOP
[Desktop Entry]
Name=SofTax GR 2025 JP
Comment=Steuererklärung Kanton Graubünden – Juristische Personen
Exec=bash -c 'cd "$APP_DIR" && ./softaxjp2025.sh'
Path=$APP_DIR
Icon=accessories-calculator
Terminal=false
Type=Application
Categories=Office;Finance;
Keywords=Steuern;Tax;Graubünden;SofTax;
DESKTOP
}

SHORTCUT_SUMMARY=""

case "$shortcut_choice" in
    1)
        # Nur Desktop
        DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
        create_desktop_entry "$DESKTOP_DIR/softax-gr-2025-jp.desktop"
        chmod +x "$DESKTOP_DIR/softax-gr-2025-jp.desktop"
        print_ok "Desktop-Verknüpfung erstellt"
        SHORTCUT_SUMMARY="  ${BOLD}Desktop:${RESET}  ${DIM}Icon auf dem Desktop${RESET}"
        ;;
    2)
        # Nur Menü
        create_desktop_entry "$MENU_FILE"
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$(dirname "$MENU_FILE")" 2>/dev/null || true
        fi
        print_ok "Menü-Verknüpfung erstellt (Kategorie: Büro)"
        SHORTCUT_SUMMARY="  ${BOLD}Menü:${RESET}     ${DIM}\"SofTax GR 2025 JP\" unter Büro/Finanzen${RESET}"
        ;;
    3)
        # Beides
        DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
        create_desktop_entry "$DESKTOP_DIR/softax-gr-2025-jp.desktop"
        chmod +x "$DESKTOP_DIR/softax-gr-2025-jp.desktop"
        create_desktop_entry "$MENU_FILE"
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$(dirname "$MENU_FILE")" 2>/dev/null || true
        fi
        print_ok "Desktop-Verknüpfung erstellt"
        print_ok "Menü-Verknüpfung erstellt (Kategorie: Büro)"
        SHORTCUT_SUMMARY="  ${BOLD}Desktop:${RESET}  ${DIM}Icon auf dem Desktop${RESET}\n  ${BOLD}Menü:${RESET}     ${DIM}\"SofTax GR 2025 JP\" unter Büro/Finanzen${RESET}"
        ;;
    4)
        # Keine
        print_skip "Keine Verknüpfungen erstellt (auf Wunsch)"
        ;;
esac

# --- Zusammenfassung ---

echo ""
echo ""
echo "${GREEN}${BOLD}  ╔═══════════════════════════════════════════════════╗${RESET}"
echo "${GREEN}${BOLD}  ║                                                   ║${RESET}"
echo "${GREEN}${BOLD}  ║         Installation abgeschlossen!               ║${RESET}"
echo "${GREEN}${BOLD}  ║                                                   ║${RESET}"
echo "${GREEN}${BOLD}  ╚═══════════════════════════════════════════════════╝${RESET}"
echo ""

if [ -n "$SHORTCUT_SUMMARY" ]; then
    echo -e "$SHORTCUT_SUMMARY"
    echo ""
    print_separator
    echo ""
fi

echo "  ${BOLD}Kommandozeile:${RESET}"
echo "    ${CYAN}cd${RESET} \"$APP_DIR\""
echo "    ${CYAN}./softaxjp2025.sh${RESET}"
echo ""
