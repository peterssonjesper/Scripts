#!/bin/bash

# Written by Jesper Petersson, jesper@jpetersson.se
# This scripts plays a given movie, the movie can either be inside a .rar-archive or just a plain file
# Usage: playrar.sh movie.[rar|mkv|avi|...]

# Note: Requires rarfs (built on fuse) and mplayer

# Env. variables
export DISPLAY=:0.0
export HOME=/home/mediacenter

# Where the rar-file will be mounted
MOUNT_DIR="/tmp/rar"

# Paths to all used commands
FUSERMOUNT="/usr/bin/fusermount"
MOUNT_FUSE="/sbin/mount.fuse"
RARFS="/usr/local/bin/rarfs"
SUDO="/usr/bin/sudo"
LS="/bin/ls"
KILL="/bin/kill"
PGREP="/usr/bin/pgrep"
MPLAYER="/usr/bin/mplayer"
MKDIR="/bin/mkdir"

# File to be played
FILE=$1

if [ -a "$FILE" ]; then
	if [ `$PGREP mplayer` ]; then
		$KILL `$PGREP mplayer`
		sleep 2 # Wait for unmount
	fi
	FILETYPE=$(/usr/bin/file -ib $FILE | /usr/bin/awk '{print $1}')
	ENDING=$(/bin/echo $FILE|/usr/bin/awk -F . '{print $NF}') # TODO: Should be done in a better way, endings are for windows people!
	if [ $FILETYPE = "application/x-rar;" -a $ENDING = "rar" ]; then
		echo "Playing $FILE ..."
		if [ ! -d "$MOUNT_DIR" ]; then
			$MKDIR $MOUNT_DIR
		fi
		$SUDO $FUSERMOUNT -u $MOUNT_DIR
		echo $SUDO $MOUNT_FUSE $RARFS#$FILE $MOUNT_DIR -o allow_other
		$SUDO $MOUNT_FUSE $RARFS#$FILE $MOUNT_DIR -o allow_other
		MOUNTED_FILE=$($LS $MOUNT_DIR/*)
		$0 $MOUNTED_FILE
		$SUDO $FUSERMOUNT -u $MOUNT_DIR
		exit 0
	elif [ $ENDING = "mkv" ]; then
		$MPLAYER -fs -vo vdpau -vc ffh264vdpau -demuxer lavf -quiet $FILE
	elif [ $ENDING = "avi" -o $ENDING = "iso" -o $ENDING = "img" ]; then
		$MPLAYER -fs -vo vdpau -quiet $FILE
	else
		echo "Error: Cannot play file $FILE: Filetype $FILETYPE, ending $EXNDING..."
		exit 2
	fi
else
	echo "Error: File not found!"
	exit 1
fi
