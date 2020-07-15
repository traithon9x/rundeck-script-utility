#!/bin/sh
hs=`hostname`
file="/tmp/${hs}_list_update_temp"
log="/var/log/intune.log"
softwareupdate -l | grep '^   \*' | grep 'Security\|security' |sed 's/   \* //g' > ${file}
if [ -s ${file} ];then
    while read -r package; do
        logger -s "${package} will be updated" 2>> ${log}
        softwareupdate -i "${package}"
    done < ${file}

else
	logger -s "No security package to update" 2>> ${log}

fi

