#!/bin/bash
red='\e[38;5;196m'
redbold='\e[1;38;5;196m'
orange='\e[38;5;214m'
orangebold='\e[1;38;5;214m'
green='\e[38;5;82m'
greenbold='\e[1;38;5;82m'
resetcolor='\e[0m'

if [[ $EUID -eq 0 ]]; then
	read -p "$(echo -e "${redbold}Please do not run this script as sudo!${resetcolor}")"
	exit 1
fi


kill_resolve(){
	# Get the PID of the current script
	current_pid=$$
	# Kill the "resolve" processes, excluding the current script
	pgrep -f "resolve" | grep -v "$current_pid" | xargs -r kill -9 || true
	pgrep -f "GUI Thread" | xargs -r kill -9
}
find_resolve(){
	echo -e ""
	echo -e "${orangebold}Please download DaVinci Resolve from:${resetcolor}"
	echo -e "https://www.blackmagicdesign.com/products/davinciresolve/studio"
	echo -e ""
	echo -e "${redbold}Put the zip file in the Downloads folder!${resetcolor}"
	read -p "Press Enter to continue only after doing the above..."
	echo -e ""
	echo -e ""

	cd ~/Downloads
	matches=($(ls DaVinci_Resolve_*_Linux.zip 2>/dev/null))

	if [ ${#matches[@]} -eq 0 ]; then
		echo -e "${redbold}No matching files found.${resetcolor}"
		exit 1
	fi

	echo -e "${orangebold}Looking for matches....${resetcolor}\n"
	for i in "${!matches[@]}"; do
		printf "%s) %s\n" "$((i+1))" "${matches[$i]}"
	done

	while true; do
		read -p "$(echo -e "${orangebold}\nWhich one do you want to use? ${resetcolor}")" choice
		if [[ $choice =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#matches[@]}" ]; then
		    davinci_ext="${matches[$((choice-1))]}"
		    break
		else
		    echo -e "${redbold}Invalid choice, please try again.${resetcolor}"
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
	rm -f ~/Desktop/com.blackmagicdesign.resolve.desktop
}

install_resolve(){
sudo zypper install -y libapr1-0 libapr-util1-0 libopencl-clang14 libOpenCL1 libOpenCL1-32bit Mesa-libOpenCL libpango-1_0-0 libpango-1_0-0-32bit libpangomm-1_4-1 libpangomm-2_48-1 libjpeg62 libjpeg62-devel
davinci_no_ext="${davinci_ext%.zip}"
mkdir /tmp/resolve-tumbleweed
unzip "$davinci_ext" -d /tmp/resolve-tumbleweed
rm "$davinci_ext"
cd /tmp/resolve-tumbleweed
sudo SKIP_PACKAGE_CHECK=1 ./"$davinci_no_ext.run"

rm -f Linux_Installation_Instructions.pdf
rm -f ~/Desktop/com.blackmagicdesign.resolve.desktop

cat << 'EOF' > $HOME/.local/share/DaVinciResolve/davinci-launcher-chillsmeit.sh
#!/bin/bash

sleep 2

/usr/bin/pgrep -f "GUI Thread" | /usr/bin/xargs -r /bin/kill -9
/usr/bin/pgrep -f "resolve" | /usr/bin/xargs -r /bin/kill -9

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

chmod +x $HOME/.local/share/DaVinciResolve/davinci-launcher-chillsmeit.sh

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

echo -e ""
echo -e ""
read -p "$(echo -e "${greenbold}Installed! Open DaVinci Resolve from the AppMenu")"
echo -e ""
echo -e ""
}

show_help() {
	echo -e "Usage: $0 <command>"
	echo -e "Available commands:"
	echo -e "   install       Will detect and install DaVinci_Resolve.zip in your ~/Downloads and remove any previous installations"
	echo -e "   uninstall     Will uninstall DaVinciResolve and anything related to this script"
}

case "$1" in
	install)
		find_resolve
		kill_resolve
		remove_resolve
		install_resolve
		;;
	uninstall)
		kill_resolve
		remove_resolve
		;;
	*)
		show_help
		;;
esac

# If there's still issues launch DaVinci with
# LD_PRELOAD='/usr/lib64/libglib-2.0.so.0 /usr/lib64/libgio-2.0.so.0 /usr/lib64/libgmodule-2.0.so.0' /opt/resolve/bin/resolve
