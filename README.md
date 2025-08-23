# Script that fixes DaVinci Resolve in OpenSUSE Tumbleweed

### As of 23rd Agust 2025 this still works
- For future issues regarding dependencies mismatch, please submit a PR as I don't use OpenSUSE TW anymore

#### Features:
- Fixes DaVinci Resolve not working in OpenSUSE Tumbleweed
- Fixes Icons for OpenSUSE Tumbleweed, uses default icon for the default theme and will use your theme icon if it exists
- Fixes DaVinci Resolve not closing the "resolve" and "GUI Thread" process when you close the application which makes it not launch again
#### NOTE:
Though the script warns you about this, the script itself won't download resolve for you.<br>
You need to download DaVinciResolve zip file yourself and put it inside your downloads folder
#### Run with:
```
curl -s https://raw.githubusercontent.com/Chillsmeit/resolve-tumbleweed/main/resolve-tumbleweed.sh | bash
```
