#!/bin/bash

# Written by Jesper Petersson, jesper@jpetersson.se
# Checks if there are any new grades published on Studentportalen (for Linköpings Universitet),
# if so an email is sent
# Usage: portal.sh

USER="abcde123"
PASSWORD="abcdefgh"
EMAIL="to@this.email.com"

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

/usr/bin/mail -s "Nya betyg i studentportalen!" $EMAIL << EOF
Nya betyg har kommit in i studentportalen!
EOF

fi

mv /tmp/result.html /tmp/old_result.html
