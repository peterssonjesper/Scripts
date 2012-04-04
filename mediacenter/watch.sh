#!/bin/bash

# Written by Jesper Petersson, jesper@jpetersson.se
# This scripts watches a directory and syncs the structure with a mysql database
# First an initial scan is done to sync. database, then inotify-events are used to keep it updated
# Usage: watch.sh /path/to/directory/to/watch

# Note: Requires inotify-support and mysql

# The table in the database should look like this:
# 
# CREATE TABLE `table_in_database` (
#   `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
#   `location` varchar(4096) DEFAULT '', 
#   `filename` varchar(512) DEFAULT NULL,
#   `dir` tinyint(1) DEFAULT NULL,
#   `old` tinyint(1) DEFAULT '0',
#   `classification` int(11) DEFAULT '0',
#   PRIMARY KEY (`id`)
# ) ENGINE=MyISAM DEFAULT CHARSET=latin1;

# Database setup
DB="database_name"
TABLE="table_in_database"
MYSQL="/usr/bin/mysql"
USER="root"
PASSWORD=""

# Directory to watch
DIR=$1

# Classifies what type of file it seems to be
function classify {
	TV=$(echo "${1,,}" | egrep "(s[0-9][0-9]e[0-9][0-9]|pdtv)" | wc -l)
	TV_SEASON=$(echo "${1,,}" | egrep "s[0-9][0-9]" | wc -l)
	MOVIE=$(echo "${1,,}" | egrep "(x264|vcd|svcd|xvid|divx|bluray|dvdr)" | wc -l)
	MOVIE_PACK=$(echo "${1,,}" | egrep "(trilogy|quadriology|\.pack|septology|hexalogy)" | wc -l)
	if [ $TV -eq 1 ]; then
		return 1
	elif [ $TV_SEASON -eq 1 ]; then
		return 2
	elif [ $MOVIE -eq 1 -a $MOVIE_PACK -eq 1 ]; then
		return 4
	elif [ $MOVIE -eq 1 ]; then
		return 3
	else
		return 10
	fi
}

# Syncs a directory with database recursively
function scan_inner {
	ls "$1" | while read FILE; do
		CMD="use $DB; select (count(id) > 0) from $TABLE where location='$(echo "$1" | sed s/"'"/"\\\'"/g)/' && filename='$(echo "$FILE" | sed s/"'"/"\\\'"/g)'";
		EXISTING=$($MYSQL -u $USER -p$PASSWORD -se "$CMD")

		IS_DIR=0
		if [ $EXISTING -eq 0 ]; then # File is not in db, let's insert it
			if [ -d "$1/$FILE" ]; then
				IS_DIR=1
				classify "$FILE"
				CLASSIFICATION=$?
				echo "Found $(echo "$FILE" | sed s/"'"/"\\\'"/g) insinde $(echo "$1" | sed s/"'"/"\\\'"/g)"
				CMD="use $DB; insert into $TABLE set location='$(echo "$1" | sed s/"'"/"\\\'"/g)/', filename='$(echo "$FILE" | sed s/"'"/"\\\'"/g)', dir=1, classification=$CLASSIFICATION";
			else
				CMD="use $DB; insert into $TABLE set location='$(echo "$1" | sed s/"'"/"\\\'"/g)/', filename='$(echo "$FILE" | sed s/"'"/"\\\'"/g)', dir=0";
			fi
			$MYSQL -u $USER -p$PASSWORD -e "$CMD"
		else
			CMD="use $DB; update $TABLE set old=0 where location='$(echo "$1" | sed s/"'"/"\\\'"/g)/' && filename='$(echo "$FILE" | sed s/"'"/"\\\'"/g)'";
			$MYSQL -u $USER -p$PASSWORD -e "$CMD"
		fi
		
		if [ $IS_DIR -eq 1 ]; then # Scan recursively
			scan_inner "$1/$FILE"
		fi
	done
}

# Wrapper function to scan_inner
function scan {
	echo "Scanning $1..."
	CMD="use $DB; update $TABLE set old=1 where location like '$DIR_ESCAPED/%'";
	$MYSQL -u $USER -p$PASSWORD -e "$CMD"
	scan_inner "$1"
	CMD="use $DB; delete from $TABLE where old=1 && location like '$DIR_ESCAPED/%'";
	$MYSQL -u $USER -p$PASSWORD -e "$CMD"
}

# Handles inotify-events and updates database correspondently
function handle_event {
	LOCATION=$1
	FILE=$2
	ACTION=$3
	if [ $ACTION = "CREATE" -o  $ACTION = "MOVED_TO" ]; then # Creted file or moved file to
		CMD="use $DB; insert into $TABLE set location='$LOCATION', filename='$FILE', dir=0";
		$MYSQL -u $USER -p$PASSWORD -e "$CMD"
	elif [ $ACTION = "CREATE,ISDIR" ]; then	# Created directory
		classify "$FILE"
		CLASSIFICATION=$?
		CMD="use $DB; insert into $TABLE set location='$LOCATION', filename='$FILE', dir=1, classification=$CLASSIFICATION";
		$MYSQL -u $USER -p$PASSWORD -e "$CMD"
	elif [ $ACTION = "MOVED_FROM" -o $ACTION = "DELETE" ]; then # File moved from or file removal
		CMD="use $DB; delete from $TABLE where location='$LOCATION' && filename='$FILE'";
		$MYSQL -u $USER -p$PASSWORD -e "$CMD"
	elif [ $ACTION = "MOVED_FROM,ISDIR" -o $ACTION = "DELETE,ISDIR" ]; then # Directory moved from or directory removal
		CMD="use $DB; delete from $TABLE where location='$LOCATION' && filename='$FILE'; delete from $TABLE where location like '$LOCATION$FILE/%'";
		$MYSQL -u $USER -p$PASSWORD -e "$CMD"
	elif [ $ACTION = "MOVED_TO,ISDIR" ]; then # Moved dir to
		classify "$FILE"
		CLASSIFICATION=$?
		CMD="use $DB; insert into $TABLE set location='$LOCATION', filename='$FILE', dir=1, classification=$CLASSIFICATION";
		$MYSQL -u $USER -p$PASSWORD -e "$CMD"
		scan $LOCATION$FILE
	fi
}

# Ok, let's kick it!
if [ -d $DIR ]; then
	scan $DIR # Do initial scan
	echo "Initial scanning done"
	# Start watching directory
	inotifywait -q -m -r --format '%w#!%f#!%e' -e move -e create -e delete $DIR | while read line; do
		LOCATION=$(echo $line | awk '{split($0, a, "#!"); print a[1]}')
		FILE=$(echo $line | awk '{split($0, a, "#!"); print a[2]}')
		ACTION=$(echo $line | awk '{split($0, a, "#!"); print a[3]}')
		handle_event $LOCATION $FILE $ACTION
	done
else
	echo "Directory does not exists!"
	exit 1
fi
