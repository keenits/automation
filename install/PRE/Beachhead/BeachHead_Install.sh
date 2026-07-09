#!/bin/bash
# BeachHead_Install.sh
# Downloads and installs BeachHead SimplySecure on macOS.
#
# Parameters:
#   $1 ACODETEXT (required) - Activation code for the BeachHead installer.
#
# Usage:
#   sudo sh ./BeachHead_Install.sh "AAAAAA-BBBB-CCCC"
#
# Notes:
#   - Downloads installer zip to /tmp/, extracts, and runs silently.
#   - Exits with the installer's exit code for Automate result handling.
#   - Designed for deployment via ConnectWise Automate with activation code supplied by EDF.
if [ -z $ACODETEXT ]; then
	if [ $# -gt 0 ]; then
		ACODETEXT="$1"
		echo "set ACODETEXT"
	else
		echo "ACODETEXT is missing."
		exit 1
	fi
fi
echo $ACODETEXT
downloadUrl="https://boldd-us.beachheadsolutions.net/Administration/DownloadInstaller.aspx?os=mac&acodetext=$ACODETEXT"
downloadUrl=${downloadUrl%$'\r'}
echo $downloadUrl
curl $downloadUrl -o /tmp/installer.zip -s
tar -xf /tmp/installer.zip -C /tmp/
/tmp/Install-BeachheadSecure.app/Contents/MacOS/Install-BeachheadSecure -s
exitCode=$?
echo $exitCode
exit $exitCode