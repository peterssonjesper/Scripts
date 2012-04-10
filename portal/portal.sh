#!/bin/bash

# Written by Jesper Petersson, jesper@jpetersson.se
# Checks if there are any new grades published on Studentportalen (for Linköpings Universitet),
# if so a push is sent using prowl.
# Usage: portal.sh

USER="abcde123"
PASSWORD="abcdefgh"
PROWL_KEY="2f6dc48ad81c1a48960ba083a98efbd4c238208e"

DATE=`date "+%H"`

if [ $DATE -lt 06 ]; then
	exit 1;
fi

curl -s https://www3.student.liu.se/portal > /tmp/portal.html

TOKEN=$(cat /tmp/portal.html|grep "login_para"|awk -F "'" '{print $6}')
TIME=$(cat /tmp/portal.html|grep "time"|awk -F "'" '{print $6}')

curl -s https://www3.student.liu.se/portal/login -d "user=$USER&pass=$PASSWORD&login_para=$TOKEN&time=$TIME&redirect=1&redirect_url=/portal/studieresultat"|sed -e :a -e '$d;N;2,41ba' -e 'P;D' > /tmp/result.html

diff /tmp/result.html /tmp/old_result.html > /dev/null
NEW_GRADES=$?
if [ ! $NEW_GRADES -eq 0 ]; then
	MSG="apikey=$PROWL_KEY&application=Studentportalen&event=Nya%20betyg!&description=Nya%20betyg%20har%20kommit%20in%20i%20studentportalen!"
	curl -s -d $MSG https://prowl.weks.net/publicapi/add > /dev/null
fi

mv /tmp/result.html /tmp/old_result.html
