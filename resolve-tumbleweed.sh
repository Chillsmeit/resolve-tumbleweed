#!/bin/bash
clear

check_root(){
	if [[ $EUID -eq 0 ]]; then
		read -p "$(printf "\n${red}Please do not run this script as sudo!${reset}")" < /dev/tty
		exit 1
	fi
}

check_dir() {
    local dir=$1
    [ -d "$dir" ]
}

get_term_colors(){
    case "$TERM" in
        *256color) return 0;;
        *) return 1;;
    esac
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

kill_resolve(){
	# Get the PID of the current script
	current_pid=$$
	# Kill the "resolve" processes, excluding the current script
	pgrep -f "resolve" | grep -v "$current_pid" | xargs -r kill -9 || true
	pgrep -f "GUI Thread" | xargs -r kill -9
}

find_resolve(){
	cd ~/Downloads
	matches=($(ls DaVinci_Resolve_*_Linux.zip 2>/dev/null))

	if [ ${#matches[@]} -eq 0 ]; then
		printf "\n${red}No matching files found.${reset}"
		read -p "$(printf "\n${orange}Please put DaVinci Resolve zip in your Downloads Folder...${reset}")" < /dev/tty
		menu_loop
	fi
	printf "\n\n${orange}Found the following matches:${reset}\n"
	for i in "${!matches[@]}"; do
		printf "%s) %s\n" "$((i+1))" "${matches[$i]}"
	done
	
	while true; do
		read -p "$(printf "\nChoose an option: ")" choice < /dev/tty
		if [[ $choice =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#matches[@]}" ]; then
		    davinci_ext="${matches[$((choice-1))]}"
		    break
		else
		    printf "\n${red}Invalid choice, please try again.${reset}"
		fi
	done
}

remove_resolve(){
	sudo rm -rf /opt/resolve
	sudo rm -rf /usr/share/applications/com.blackmagicdesign.*
	sudo rm -rf /var/BlackmagicDesign
	sudo rm -rf /tmp/resolve-tumbleweed
	sudo rm -f /usr/share/icons/hicolor/128x128/apps/DV_Resolve.png
	sudo rm -f /usr/share/icons/hicolor/scalable/apps/DV_Resolve.png
	sudo rm -rf ~/.local/share/DaVinciResolve
	rm -f ~/Desktop/com.blackmagicdesign.resolve.desktop
}

install_dependencies(){
	sudo zypper install -y libapr1-0 libapr-util1-0 libopencl-clang14 libOpenCL1 libOpenCL1-32bit \
	Mesa-libOpenCL libpango-1_0-0 libpango-1_0-0-32bit libpangomm-1_4-1 libpangomm-2_48-1 libjpeg62 \
	libjpeg62-devel
}

create_launcher(){
cat << 'EOF' > $HOME/.local/share/DaVinciResolve/davinci-launcher-chillsmeit.sh
#!/bin/bash

sleep 2

pgrep -f "GUI Thread" | xargs -r kill -9
pgrep -f "resolve" | xargs -r kill -9

# Define a file to store the PID of the current instance
PIDFILE="/tmp/resolve.pid"

# Check if the PID file exists and if a process with that PID is running
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if ps -p "$OLD_PID" > /dev/null; then
        echo "Terminating previous instance with PID $OLD_PID"
        kill -9 "$OLD_PID"
    else
        echo "No process found with PID $OLD_PID"
    fi
    rm "$PIDFILE"
else
    echo "PID file does not exist"
fi

# Store the current script's PID in the PID file
echo $$ > "$PIDFILE"

sleep 2

# Launch DaVinci Resolve
/opt/resolve/bin/resolve "$@"
EOF
}

create_desktop(){
sudo bash -c 'cat << EOF > /usr/share/applications/com.blackmagicdesign.resolve.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=DaVinci Resolve
GenericName=DaVinci Resolve
Comment=Revolutionary new tools for editing, visual effects, color correction, and professional audio post production.
Exec='$HOME'/.local/share/DaVinciResolve/davinci-launcher-chillsmeit.sh
Terminal=false
MimeType=application/x-resolveproj;
Icon=DV_Resolve
StartupNotify=false
Name[en_US]=DaVinci Resolve
StartupWMClass=resolve
EOF'
}

install_resolve(){
	davinci_no_ext="${davinci_ext%.zip}"
	mkdir -p /tmp/resolve-tumbleweed
	unzip "$davinci_ext" -d /tmp/resolve-tumbleweed
	cd /tmp/resolve-tumbleweed
	sudo SKIP_PACKAGE_CHECK=1 ./"$davinci_no_ext.run" -y

	rm -f Linux_Installation_Instructions.pdf
	rm -f ~/Desktop/com.blackmagicdesign.resolve.desktop

	mkdir -p $HOME/.local/share/DaVinciResolve

	create_launcher
	chmod +x $HOME/.local/share/DaVinciResolve/davinci-launcher-chillsmeit.sh

	create_desktop
	chmod +x /usr/share/applications/com.blackmagicdesign.resolve.desktop

	sudo cp /opt/resolve/graphics/DV_Resolve.png /usr/share/icons/hicolor/128x128/apps
	sudo cp /opt/resolve/graphics/DV_Resolve.png /usr/share/icons/hicolor/scalable/apps
	sudo gtk-update-icon-cache /usr/share/icons/hicolor

	# Download fedora38 gdk-pixbuf2 package (x86_64)
	# https://koji.fedoraproject.org/koji/buildinfo?buildID=2115750
	wget https://kojipkgs.fedoraproject.org//packages/gdk-pixbuf2/2.42.10/2.fc38/x86_64/gdk-pixbuf2-2.42.10-2.fc38.x86_64.rpm
	rpm2cpio ./gdk-pixbuf2-2.42.10-2.fc38.x86_64.rpm | cpio -idmv
	cd usr/lib64/
	sudo cp -vr * /opt/resolve/libs/
	sudo cp -va /lib64/libglib-2.0.* /opt/resolve/libs/
	sudo rm -rf /tmp/resolve-chillsmeit

	read -p "$(printf "\n\n${green}Installed!${reset}\n\n")" < /dev/tty
}

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
				find_resolve
				kill_resolve
				remove_resolve
				install_dependencies
				install_resolve
				;;
			2)
				kill_resolve
				remove_resolve
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
# Set terminal to either 16 ANSI or 256 ANSI
set_term_colors

# Checks if Script is being run as root
check_root

# Main Menu loop
menu_loop
