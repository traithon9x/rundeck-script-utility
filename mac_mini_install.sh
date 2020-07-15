#!/bin/bash

minion_id=$1
minion_id=$(echo "${minion_id}" | tr "A-Z" "a-z" | sed -e "s/.aavn//g" -e "s/.local//g") # lower text and cut .aavn.local
master_server="ict-salt-master.aavn.local"
source_url="http://192.168.77.156/files/MacOS-App-Store/OS/salt-2018.3.3-py2.pkg"
file_dest="/tmp/mac_salt_201833.pkg"

if [ -z ${minion_id} ];then
    echo "WARNING: Arg minion_id was not inputed, please  input"
    exit 1
fi

echo "======= Clean Old salt-minion==========="

launchctl stop com.saltstack.salt.minion

pkgutil --pkgs | grep salt

pkgutil --pkg-info com.saltstack.salt

pkgutil --files com.saltstack.salt

sudo launchctl unload -w /Library/LaunchDaemons/com.saltstack.salt.minion.plist

cd /

pkgutil --only-files --files com.saltstack.salt | grep -v opt

pkgutil --only-files --files com.saltstack.salt | grep -v opt | tr '\n' '\0' | xargs -0 sudo rm -f

pkgutil --only-dirs --files com.saltstack.salt | grep -v opt

sudo rm -fr etc/salt

sudo rm -fr opt/salt

sudo rm -rf /var/log/salt

sudo pkgutil --forget com.saltstack.salt

ps -ef | grep -i salt | awk {'print $2'} | xargs kill -9

echo "======= Installing salt-minion ==========="


curl -L -o /tmp/mac_salt_201833.pkg \
${source_url}

installer -allowUntrusted -verboseR -pkg "/tmp/mac_salt_201833.pkg" -target /

sh /opt/salt/bin/salt-config.sh -i ${minion_id} -m ${master_server}

#rm -rf /etc/salt/minion.d/*
#cp /etc/salt/minion /etc/salt/minion_bk
#echo "master: ${master_server}" > /etc/salt/minion
#echo "id: ${minion_id}" >> /etc/salt/minion

echo 'verify_env: False' > /etc/salt/minion.d/config.cof

sudo launchctl stop com.saltstack.salt.minion
sudo launchctl start com.saltstack.salt.minion

ps -ef | grep salt
ps aux | grep salt

rm -rf ${file_dest}

echo "=====================Installing Success================"

