#!/bin/bash

clear

# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------

TMPDIR="/tmp/resolve-tumbleweed"
RESOLVE_DIR="/opt/resolve"
LAUNCHER_DIR="$HOME/.local/share/DaVinciResolve"
LAUNCHER="$LAUNCHER_DIR/davinci-launcher-chillsmeit.sh"
DESKTOP_FILE="/usr/share/applications/com.blackmagicdesign.resolve.desktop"

# Resolve needs this exact build of gdk-pixbuf2. Newer versions may work, try it for yourself
# Build info: https://koji.fedoraproject.org/koji/buildinfo?buildID=2115750
GDK_RPM="gdk-pixbuf2-2.42.10-2.fc38.x86_64.rpm"
GDK_URL="https://kojipkgs.fedoraproject.org//packages/gdk-pixbuf2/2.42.10/2.fc38/x86_64/$GDK_RPM"

# ------------------------------------------------------------------
# Terminal colors
# ------------------------------------------------------------------

get_term_colors(){
    [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]
}

set_term_colors(){
    if get_term_colors; then
        # 256 ANSI Custom Colors
        orange='\e[38;5;214m'
        # 256 ANSI Regular Colors
        black='\e[38;5;235m'
        red='\e[38;5;167m'
        green='\e[38;5;143m'
        yellow='\e[38;5;221m'
        blue='\e[38;5;110m'
        magenta='\e[38;5;182m'
        cyan='\e[38;5;79m'
        lightgray='\e[38;5;251m'
        # 256 ANSI Bold Colors
        darkgray='\e[38;5;242m'
        lightred='\e[38;5;167m'
        lightgreen='\e[38;5;149m'
        lightyellow='\e[38;5;221m'
        lightblue='\e[38;5;111m'
        lightmagenta='\e[38;5;183m'
        lightcyan='\e[38;5;79m'
        white='\e[38;5;231m'
    else
        # 16 ANSI Regular Colors
        black='\e[0;30m'
        red='\e[0;31m'
        green='\e[0;32m'
        yellow='\e[0;33m'
        blue='\e[0;34m'
        magenta='\e[0;35m'
        cyan='\e[0;36m'
        lightgray='\e[0;37m'
        # 16 ANSI Bold Colors
        darkgray='\e[1;30m'
        lightred='\e[1;31m'
        lightgreen='\e[1;32m'
        lightyellow='\e[1;33m'
        lightblue='\e[1;34m'
        lightmagenta='\e[1;35m'
        lightcyan='\e[1;36m'
        white='\e[1;37m'
    fi
    # ANSI Reset Color
    reset='\e[0m'
}

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

pause(){
    read -p "$(printf "\n%b\n" "$1")" < /dev/tty
}

fail(){
    pause "${red}$1${reset}"
    return 1
}

check_root(){
    if [[ $EUID -eq 0 ]]; then
        printf "\n${red}Please do not run this script as sudo!${reset}\n\n"
        exit 1
    fi
}

check_commands(){
    local missing=()
    local cmd
    for cmd in unzip unzip wget rpm2cpio cpio xdg-user-dir sudo; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        printf "\n${red}Missing required commands: ${missing[*]}${reset}\n"
        printf "${orange}Install them with: sudo zypper install ${missing[*]}${reset}\n\n"
        exit 1
    fi
}

# ------------------------------------------------------------------
# Resolve processes
# ------------------------------------------------------------------

kill_resolve(){
    pkill -f "^$RESOLVE_DIR/bin/resolve" 2>/dev/null || true
    sleep 1
    pkill -9 -f "^$RESOLVE_DIR/bin/resolve" 2>/dev/null || true
}

# ------------------------------------------------------------------
# Find the installer zip
# ------------------------------------------------------------------

find_resolve(){
    local downloads_dir choice i
    downloads_dir=$(xdg-user-dir DOWNLOAD)

    if [ -z "$downloads_dir" ] || [ ! -d "$downloads_dir" ]; then
        fail "Error: could not find the Downloads folder."
        return 1
    fi

    cd "$downloads_dir" || { fail "Error: could not enter $downloads_dir"; return 1; }

    shopt -s nullglob
    matches=(DaVinci_Resolve_*_Linux.zip)
    shopt -u nullglob

    if [ ${#matches[@]} -eq 0 ]; then
        fail "No matching files found.\n\n${orange}Please put the DaVinci Resolve zip in your Downloads folder."
        return 1
    fi

    printf "\n\n${orange}Found the following matches:${reset}\n"
    for i in "${!matches[@]}"; do
        printf "%s) %s\n" "$((i+1))" "${matches[$i]}"
    done

    while true; do
        read -p "$(printf "\nChoose an option (0 to cancel): ")" choice < /dev/tty
        if [[ $choice == "0" ]]; then
            return 1
        elif [[ $choice =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#matches[@]}" ]; then
            davinci_ext="${matches[$((choice-1))]}"
            davinci_dir="$downloads_dir"
            return 0
        else
            printf "\n${red}Invalid choice, please try again.${reset}\n"
        fi
    done
}

# ------------------------------------------------------------------
# Uninstall
# ------------------------------------------------------------------

remove_resolve(){
    sudo rm -rf "$RESOLVE_DIR"
    sudo rm -rf /usr/share/applications/com.blackmagicdesign.*
    sudo rm -rf /var/BlackmagicDesign
    sudo rm -rf "$TMPDIR"
    sudo rm -f /usr/share/icons/hicolor/128x128/apps/DV_Resolve.png
    sudo rm -f /usr/share/icons/hicolor/scalable/apps/DV_Resolve.png
    rm -rf "$LAUNCHER_DIR"
    rm -f "$HOME/Desktop/com.blackmagicdesign.resolve.desktop"
}

# ------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------

install_dependencies(){
    sudo zypper install -y libapr1-0 libapr-util1-0 "libopencl-clang*" libOpenCL1 libOpenCL1-32bit \
        Mesa-libOpenCL libpango-1_0-0 libpango-1_0-0-32bit libpangomm-1_4-1 libpangomm-2_48-1 \
        libjpeg62 libjpeg62-devel || {
            fail "Failed to install dependencies. Check your zypper repositories."
            return 1
        }
}

# ------------------------------------------------------------------
# Launcher and desktop entry
# ------------------------------------------------------------------

create_launcher(){
    mkdir -p "$LAUNCHER_DIR" || return 1

    cat << 'EOF' > "$LAUNCHER"
#!/bin/bash

RESOLVE_BIN="/opt/resolve/bin/resolve"
PIDFILE="/tmp/resolve.pid"

# Stop any previous instance, matching the real binary path only
pkill -f "^$RESOLVE_BIN" 2>/dev/null || true

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" > /dev/null 2>&1; then
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
fi

echo $$ > "$PIDFILE"
sleep 1

exec "$RESOLVE_BIN" "$@"
EOF

    chmod +x "$LAUNCHER" || return 1
}

create_desktop(){
    local tmpfile
    tmpfile=$(mktemp) || return 1

    cat << EOF > "$tmpfile"
[Desktop Entry]
Version=1.0
Type=Application
Name=DaVinci Resolve
GenericName=DaVinci Resolve
Comment=Revolutionary new tools for editing, visual effects, color correction, and professional audio post production.
Exec=$LAUNCHER
Terminal=false
MimeType=application/x-resolveproj;
Icon=DV_Resolve
StartupNotify=false
Name[en_US]=DaVinci Resolve
StartupWMClass=resolve
EOF

    sudo install -m 644 "$tmpfile" "$DESKTOP_FILE"
    local result=$?
    rm -f "$tmpfile"
    return $result
}

# ------------------------------------------------------------------
# Install
# ------------------------------------------------------------------

install_gdk_pixbuf(){
    # Resolve ships against an older gdk-pixbuf2 than Tumbleweed provides.
    # This pulls the specific Fedora 38 build it needs into Resolve's own library folder.

    printf "\n${orange}Downloading gdk-pixbuf2 (required by Resolve)...${reset}\n"

    cd "$TMPDIR" || return 1

    if ! wget -q --show-progress "$GDK_URL"; then
        fail "Could not download $GDK_RPM\n\n${orange}Resolve needs this exact build to start.\nCheck your connection, or that the Fedora archive still has it:\n$GDK_URL"
        return 1
    fi

    if ! rpm2cpio "./$GDK_RPM" | cpio -idm --quiet; then
        fail "Could not unpack $GDK_RPM"
        return 1
    fi

    if [ ! -d "$TMPDIR/usr/lib64" ]; then
        fail "Unpacked package did not contain usr/lib64 as expected."
        return 1
    fi

    sudo cp -r "$TMPDIR/usr/lib64/." "$RESOLVE_DIR/libs/" || return 1
    sudo cp -a /lib64/libglib-2.0.* "$RESOLVE_DIR/libs/" || return 1
}

install_resolve(){
    local davinci_no_ext="${davinci_ext%.zip}"

    rm -rf "$TMPDIR"
    mkdir -p "$TMPDIR" || { fail "Could not create $TMPDIR"; return 1; }

    printf "\n${orange}Extracting installer...${reset}\n"
    if ! unzip -q "$davinci_dir/$davinci_ext" -d "$TMPDIR"; then
        fail "Could not extract $davinci_ext"
        return 1
    fi

    cd "$TMPDIR" || return 1

    if [ ! -f "$davinci_no_ext.run" ]; then
        fail "Installer $davinci_no_ext.run not found inside the zip."
        return 1
    fi

    printf "\n${orange}Running the Blackmagic installer...${reset}\n"
    if ! sudo SKIP_PACKAGE_CHECK=1 "./$davinci_no_ext.run" -y; then
        fail "The Blackmagic installer failed."
        return 1
    fi

    rm -f "$HOME/Desktop/com.blackmagicdesign.resolve.desktop"

    create_launcher || { fail "Could not create the launcher script."; return 1; }
    create_desktop  || { fail "Could not create the desktop entry."; return 1; }

    if [ -f "$RESOLVE_DIR/graphics/DV_Resolve.png" ]; then
        sudo cp "$RESOLVE_DIR/graphics/DV_Resolve.png" /usr/share/icons/hicolor/128x128/apps/
        sudo cp "$RESOLVE_DIR/graphics/DV_Resolve.png" /usr/share/icons/hicolor/scalable/apps/
        sudo gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
    fi

    install_gdk_pixbuf || return 1

    cd "$HOME" || true
    rm -rf "$TMPDIR"

    pause "\n${green}Installed!${reset}\n"
}

# ------------------------------------------------------------------
# Menu
# ------------------------------------------------------------------

menu_loop(){
    while true; do
        clear
		printf "${orange}     ██████████████████████████████████████████████\n"
		printf "${orange}     █▓▓▒▒░░ Chillsmeit DaVinci Resolve Fix ░░▒▒▓▓█\n"
		printf "${orange}|██████████████████████████████████████████████████████|\n"
		printf "${orange}|█▓▓${white}                                                ${orange}▓▓█|\n"
		printf "${orange}|█▓▓${white}        1: Install DaVinci Resolve              ${orange}▓▓█|\n"
		printf "${orange}|█▓▓${white}        2: Uninstall DaVinci Resolve            ${orange}▓▓█|\n"
		printf "${orange}|█▓▓${white}        0: Exit                                 ${orange}▓▓█|\n"
		printf "${orange}|█▓▓${white}                                                ${orange}▓▓█|\n"
		printf "${orange}|██████████████████████████████████████████████████████|${reset}\n\n"

        read -p "Choose an option: " menuoption < /dev/tty

        case "$menuoption" in
            1)
                find_resolve || continue
                kill_resolve
                remove_resolve
                install_dependencies || continue
                install_resolve || continue
                ;;
            2)
                kill_resolve
                remove_resolve
                pause "\n${green}Uninstalled!${reset}\n"
                ;;
            0)
                printf "Exiting\n"
                exit 0
                ;;
            *)
                ;;
        esac
    done
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

set_term_colors
check_root
check_commands
menu_loop
