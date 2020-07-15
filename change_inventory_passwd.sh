#!/bin/sh

password="pass@word12"
log="/var/log/intune.log"


/usr/bin/dscl . passwd /Users/inventory "$password"

status=$?



if [ $status == 0 ]; then

logger -s  "Password was changed successfully." 2>> ${log}

elif [ $status != 0 ]; then

logger -s "An error was encountered while attempting to change the password. /usr/bin/dscl exited $status." 2>> ${log}

fi



exit $status
