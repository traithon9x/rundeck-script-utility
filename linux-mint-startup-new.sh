#!/bin/bash

################
# This scripts use to new install a workstation which using Linux-Mint.
################
#set -x
AAVNICT_TEMP_DIR='/tmp/aavn-ict.temp'
USER_ADMIN_PASS='pass#word12'

function _log_() {
    LEVEL=$1
    shift
    echo "$(date "+[%Y/%m/%d %T %z]") [$LEVEL] $*"
}
function log_i() {
    _log_ INFO "$@"
}
function log_e() {
    _log_ ERROR "$@"
}
function log_w() {
    _log_ WARNING "$@"
}

# create folder /tmp/aavn-ict.temp
mkdir -p ${AAVNICT_TEMP_DIR}



basic_installation () {
    log_i "Updating apt library"
    apt-get update > /dev/null
    log_i "  -> Done"
    log_i "Installing ssh service"
    apt-get install openssh-server -y > /dev/null
    if [ $? -ne 0 ];then
        log_e " -> Failed"
    else
        systemctl enable ssh > /dev/null && \
        systemctl restart ssh > /dev/null && \
        systemctl restart sshd > /dev/null
        if [ $? -ne 0 ];then
        log_e " -> Failed"
        else
        log_i " -> Done"
        fi
    fi

    log_i "Active AAVN DNS"

    systemctl stop avahi-daemon > /dev/null
    systemctl disable avahi-daemon > /dev/null
    apt-get purge avahi-daemon -y > /dev/null
    service systemd-resolved restart > /dev/null
    systemctl status resolvconf > /dev/null
    apt install resolvconf -y > /dev/null
    echo "nameserver 192.168.77.9" >> /etc/resolvconf/resolv.conf.d/head 
    echo "nameserver 192.168.77.10" >> /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 192.168.77.202" >> /etc/resolvconf/resolv.conf.d/head
    systemctl restart resolvconf > /dev/null
    systemctl enable resolvconf > /dev/null
    if [ $? -ne 0 ];then
        log_e " -> Failed"
        else
        log_i " -> Done"
    fi

    log_i "Creating admin user"
    useradd admin > /dev/null && \
    usermod -a -G sudo admin > /dev/null && \
    echo -e "${USER_ADMIN_PASS}\n${USER_ADMIN_PASS}" | passwd admin > /dev/null
    if [ $? -ne 0 ];then
        log_e " -> Failed"
    else
        log_i " -> Done"
    fi

    log_i "Crontab for security update"
    apt-get install unattended-upgrades -y > /dev/null && \
    grep -qxF "#Crontab for security updating last friday of month" /etc/crontab || echo "#Crontab for security updating last friday of month" >> /etc/crontab && \
    grep -qxF "0 10 25-31 1,3,5,7,8,10,12 5 unattended-upgrades -d" /etc/crontab || echo "0 10 25-31 1,3,5,7,8,10,12 5 unattended-upgrades -d" >> /etc/crontab && \
    grep -qxF "0 10 24-30 4,6,9,11        5 unattended-upgrades -d" /etc/crontab || echo "0 10 24-30 4,6,9,11        5 unattended-upgrades -d" >> /etc/crontab && \
    grep -qxF "0 10 22-28 2               5 unattended-upgrades -d" /etc/crontab || echo "0 10 22-28 2               5 unattended-upgrades -d" >> /etc/crontab && \
    systemctl restart cron
    if [ $? -ne 0 ];then
        log_e " -> Failed"
    else
        log_i " -> Done"
    fi

}


get_ldap_info () {
    local count=1
    status="false"
    while [[ ${status} == "false" ]]
    do
        case ${#count} in 1) count_prefix="00${count}";;2) count_prefix="0${count}";; *);; esac
        HOST_NAME="${PRE_HOSTNAME}-${count_prefix}"
        ldapsearch  \
        -h "${LDAP_SERVER}" -p 389 \
        -D ${LDAP_ADMIN_USER} \
        -w "${LDAP_ADMIN_PASS}" \
        -b DC=aavn,DC=local \
        -LLL "(cn=${HOST_NAME})" description | grep 'dn: CN=' > /dev/null
        if [ $? -ne 0 ];then
            status="true"
        fi
        (( count++ ))
    done
    log_i "Checking available hostname for workstation"
    log_i " -> Hostname is ${HOST_NAME}"

    LDAP_FILE_TEMP="${AAVNICT_TEMP_DIR}/${OU_WORKSTATION}_GROUPS_temp"

    log_i "Getting groups in AD"
    ldapsearch  \
    -h "${LDAP_SERVER}" -p 389 \
    -D ${LDAP_ADMIN_USER} \
    -w "${LDAP_ADMIN_PASS}" \
    -b OU=${OU_WORKSTATION},DC=aavn,DC=local \
    -LLL '(objectClass=organizationalUnit)' dn > ${LDAP_FILE_TEMP}

    # Remove first line
    # Remove Computer Free line
    # Remove 'dn: OU='
    # Remove ',OU=DN_workstations,DC=aavn,DC=local'
    # Remove empty line
    sed -i -e 1d \
    -e '/Computer Free/d' \
    -e '/Meeting Room/d' \
    -e '/Testing PC/d' \
    -e 's/dn:\ OU=//' \
    -e "s/,OU=${OU_WORKSTATION},DC=aavn,DC=local//" \
    -e '/^$/d' \
    ${LDAP_FILE_TEMP} > /dev/null

}

ldap_data() {

    echo "Please set your Ldap Admin User: "
    read LDAP_ADMIN_USER

    read -s -p "Please set your Ldap Admin User Password: " LDAP_ADMIN_PASS

    log_i "Installing ldap-utils"
    apt-get update > /dev/null > /dev/null
    apt install ldap-utils -y > /dev/null
        if [ $? -ne 0 ];then
            log_e " -> Failed"
        else
            log_i " -> Done"
        fi

    log_i "Checking LDAP User's Credentials"
    ldapwhoami -vvv  -h "${LDAP_SERVER}" -D "${LDAP_ADMIN_USER}" -x  -w "${LDAP_ADMIN_PASS}" > /dev/null
        if [ $? -ne 0 ];then
            log_e " -> Can not login with user ${LDAP_ADMIN_USER}"
            exit 1
        else
            log_i " -> Success"
        fi

    get_ldap_info &&

    echo "Please set your full name: [Exp: Hoang Tran Khanh or Duy Nguyen Van Hoang]"
    read FULL_NAME

    echo "Please set AD account of client: [tkhoang/dhhuy...]"
    read ACCOUNT_NAME

    declare -a GROUP_LIST
    while IFS= read LINE
    do
        GROUP_LIST+=("${LINE}")
    done < ${LDAP_FILE_TEMP}
    echo "Choose your team number: [1 or 2 or 3 ....] "
    for ELEMENT in ${!GROUP_LIST[@]}
    do
        NUMBER=$(( ELEMENT+1 ))
        echo "${NUMBER} - ${GROUP_LIST[${ELEMENT}]}"
    done
    read NUMBER_GROUP
    NUMBER_GROUP=$(( NUMBER_GROUP-1 ))
    GROUP="${GROUP_LIST[${NUMBER_GROUP}]}"

}

join_domain () {
echo "Choose your option: [1/2]"
echo "  1. Join domain with new name"
echo "  2. Keep current name and join domain"
read JOIN_OPTION
case ${JOIN_OPTION} in
1)
log_i "Changing hostname to ${HOST_NAME}"
hostname "${HOST_NAME}"
if [ $? -ne 0 ];then
        log_e " -> Failed"
        exit 1
    else
        log_i " -> Done"
    fi
;;
2)
HOST_NAME=$(hostname)
log_i "Deleting old entry in AD"
cat <<EOF > ${AAVNICT_TEMP_DIR}/del.ldif
dn: CN=${HOST_NAME},OU="${GROUP}",OU="${OU_WORKSTATION}",DC=aavn,DC=local
changetype: delete
EOF
ldapmodify  \
    -h "${LDAP_SERVER}" -p 389 \
    -D ${LDAP_ADMIN_USER} \
    -w "${LDAP_ADMIN_PASS}" \
    -f ${AAVNICT_TEMP_DIR}/del.ldif > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
    else
        log_i "  -> Done"
    fi
;;
*)
echo "Wrong option"
exit 1
;;
esac

log_i "Installing pbis"
curl -s -L -o ${AAVNICT_TEMP_DIR}/pbis.deb.sh \
http://192.168.77.156/files/Linux-Store/apps/pbis-9.0.2.deb.sh > /dev/null || \
curl -s -L -o ${AAVNICT_TEMP_DIR}/pbis.deb.sh \
https://github.com/BeyondTrust/pbis-open/releases/download/9.0.2/pbis-open-9.0.2.534.linux.x86_64.deb.sh > /dev/null
chmod +x ${AAVNICT_TEMP_DIR}/pbis.deb.sh > /dev/null && \
bash ${AAVNICT_TEMP_DIR}/pbis.deb.sh > /dev/null
    if [ $? -ne 0 ];then
        log_e " -> Failed"
        exit 1
    else
        log_i " -> Done"
    fi
log_i "Join this workstation to AAVN domain"
cd /opt/pbis/bin/
domainjoin-cli leave ${LDAP_ADMIN_USER} ${LDAP_ADMIN_PASS} > /dev/null
domainjoin-cli join aavn.local ${LDAP_ADMIN_USER} ${LDAP_ADMIN_PASS} > /dev/null && \
/opt/pbis/bin/config UserDomainPrefix aavn.local > /dev/null  && \
/opt/pbis/bin/config AssumeDefaultDomain true > /dev/null && \
/opt/pbis/bin/config LoginShellTemplate /bin/bash > /dev/null && \
/opt/pbis/bin/config HomeDirTemplate %H/%U > /dev/null && \
usermod -a -G sudo "AAVN\\${ACCOUNT_NAME}" > /dev/null
    if [ $? -ne 0 ];then
        log_e " -> Failed"
        exit 1
    else
        log_i " -> Done"
    fi
log_i "Configure theme for Linux Mint"
if [[ -f /etc/mdm/mdm.conf ]];then
    if grep 'GraphicalTheme=' /etc/mdm/mdm.conf;then
        sed -i 's/GraphicalTheme=.*/GraphicalTheme=Leaf/' /etc/mdm/mdm.conf > /dev/null
    else
        sed -i '/^\[greeter\]/a GraphicalTheme=Leaf' /etc/mdm/mdm.conf > /dev/null
    fi
        if [ $? -ne 0 ];then
            log_e " -> Failed"
            exit 1
        else
            log_i " -> Done"
        fi
fi

/etc/init.d/mdm restart > /dev/null
cd

log_i "Changing AD Information"
CURRENT_DN=$(ldapsearch  \
            -h "${LDAP_SERVER}" -p 389 \
            -D ${LDAP_ADMIN_USER} \
            -w "${LDAP_ADMIN_PASS}" \
            -b DC=aavn,DC=local \
            -LLL "(cn=${HOST_NAME})" dn \
            | sed -n 1p | sed 's/dn: //')

log_i " -> Chaning description"
cat <<EOF > ${AAVNICT_TEMP_DIR}/desc.ldif
dn: ${CURRENT_DN}
changetype: modify
replace: description
description: ${FULL_NAME}
EOF
ldapmodify  \
    -h "${LDAP_SERVER}" -p 389 \
    -D ${LDAP_ADMIN_USER} \
    -w "${LDAP_ADMIN_PASS}" \
    -f ${AAVNICT_TEMP_DIR}/desc.ldif > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
        exit 1
    else
        log_i "  -> Done"
    fi

cat <<EOF > ${AAVNICT_TEMP_DIR}/new-ou.ldif
dn: ${CURRENT_DN}
changetype: modrdn
newrdn: CN=${HOST_NAME}
deleteoldrdn: 1
newsuperior: OU=${GROUP},OU=${OU_WORKSTATION},DC=aavn,DC=local
EOF
log_i " -> Changing workstation group"
ldapmodify  \
    -h "${LDAP_SERVER}" -p 389 \
    -D ${LDAP_ADMIN_USER} \
    -w "${LDAP_ADMIN_PASS}" \
    -f ${AAVNICT_TEMP_DIR}/new-ou.ldif > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
        exit 1
    else
        log_i "  -> Done"
    fi
}

salt_stack () {
    OS_VERSION=$(cat /etc/os-release | grep 'VERSION=')
    if [[ "${OS_VERSION}" == *"16"* ]];then
        REPO_KEY="https://repo.saltstack.com/py3/ubuntu/16.04/amd64/3001/SALTSTACK-GPG-KEY.pub"
        REPO_URL="deb http://repo.saltstack.com/py3/ubuntu/16.04/amd64/3001 xenial main"
        log_i "Installing salt-minion"
        wget -O - ${REPO_KEY} | sudo apt-key add - > /dev/null && \
        echo "${REPO_URL}" > /etc/apt/sources.list.d/saltstack.list && \
        apt-get update -y > /dev/null && \
        apt-get install salt-minion -y > /dev/null 
    elif [[ "${OS_VERSION}" == *"18"* ]];then
        REPO_KEY="https://repo.saltstack.com/py3/ubuntu/18.04/amd64/3001/SALTSTACK-GPG-KEY.pub"
        REPO_URL="deb http://repo.saltstack.com/py3/ubuntu/18.04/amd64/3001 bionic main"
        log_i "Installing salt-minion"
        wget -O - ${REPO_KEY} | sudo apt-key add - > /dev/null && \
        echo "${REPO_URL}" > /etc/apt/sources.list.d/saltstack.list && \
        apt-get update -y > /dev/null && \
        apt-get install salt-minion -y > /dev/null 
    elif [[ "${OS_VERSION}" == *"20"* || "${OS_VERSION}" == *"19"* ]];then
        REPO_KEY="https://repo.saltstack.com/py3/ubuntu/20.04/amd64/3001/SALTSTACK-GPG-KEY.pub"
        REPO_URL="deb http://repo.saltstack.com/py3/ubuntu/20.04/amd64/3001 focal main"
        log_i "Installing salt-minion"
        wget -O - ${REPO_KEY} | sudo apt-key add - > /dev/null && \
        echo "${REPO_URL}" > /etc/apt/sources.list.d/saltstack.list && \
        apt-get update -y > /dev/null && \
        apt-get install salt-minion -y > /dev/null 
    else
        curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh && \
        sh /tmp/install_salt.sh -P 
    fi

    # curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh && \
    # sh /tmp/install_salt.sh -P && \
    # wget -O - https://repo.saltstack.com/py3/ubuntu/20.04/amd64/3001/SALTSTACK-GPG-KEY.pub | sudo apt-key add - && \
    # echo "deb http://repo.saltstack.com/py3/ubuntu/20.04/amd64/3001 focal main" > /etc/apt/sources.list.d/saltstack.list && \
    # apt-get update -y > /dev/null && \
    # apt-get install salt-minion -y > /dev/null && \
    grep -qxF "master: 192.168.77.101" /etc/salt/minion || echo "master: 192.168.77.101" >> /etc/salt/minion && \
    grep -qxF "id: $(hostname)" /etc/salt/minion || echo "id: $(hostname)" > /etc/salt/minion && \
    systemctl enable salt-minion > /dev/null && \
    systemctl restart salt-minion > /dev/null && \
    # rm -f /tmp/install_salt.sh
        if [ $? -ne 0 ];then
            log_e "  -> Failed"
            exit 1
        else
            log_i "  -> Done"
        fi
}

kas () {
apt-get install unzip -y > /dev/null
log_i "Cleanup old KAS"
dpkg -r kesl > /dev/nul
dpkg -r klnagent > /dev/null
dpkg -r klnagent64 > /dev/null
rm -rf /opt/kaspersky > /dev/null
log_i "Reparing to install KAS"
curl -s -L -o ${AAVNICT_TEMP_DIR}/kesl_11.1.0-3013_amd64.deb \
http://192.168.77.156/files/Linux-Store/apps/kesl_11.1.0-3013_amd64.deb > /dev/null && \
curl -s -L -o ${AAVNICT_TEMP_DIR}/klnagent64_11.0.0-38_amd64.deb \
http://192.168.77.156/files/Linux-Store/apps/klnagent64_11.0.0-38_amd64.deb > /dev/null && \
# unzip ${AAVNICT_TEMP_DIR}/KAS.zip -d ${AAVNICT_TEMP_DIR}/KAS && \
dpkg -i ${AAVNICT_TEMP_DIR}/klnagent* > /dev/null && \
dpkg -i ${AAVNICT_TEMP_DIR}/kesl* > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
        exit 0
    else
        log_i "  -> Done"
    fi
log_i "Installing KAS"
cat <<EOF > /opt/kaspersky/klnagent64/lib/bin/setup/autoanswers.conf
KLNAGENT_SERVER=${KAS_SERVER}
KLNAGENT_PORT=14000
KLNAGENT_SSLPORT=13000
KLNAGENT_USESSL=N
KLNAGENT_GW_MODE=1
EOF
log_i " -> Installing Agent"
cd /opt/kaspersky/klnagent64/lib/bin/setup && \
/usr/bin/perl ./postinstall.pl > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
        exit 0
    else
        systemctl enable klnagent64 > /dev/null
        systemctl restart klnagent64 > /dev/null
        log_i "  -> Done"

    fi
cd
cat <<EOF > /opt/kaspersky/kesl/bin/autoanswers.conf
EULA_AGREED=yes
PRIVACY_POLICY_AGREED=yes
USE_KSN=yes
UPDATE_EXECUTE=no
KERNEL_SRCS_INSTALL=yes
USE_GUI=yes
IMPORT_SETTINGS=yes
EOF
log_i " -> Installing KES"
cd /opt/kaspersky/kesl/bin && \
/usr/bin/perl ./kesl-setup.pl --autoinstall=./autoanswers.conf > /dev/null
    if [ $? -ne 0 ];then
        log_e "  -> Failed"
        exit 0
    else
        systemctl enable kesl-supervisor > /dev/null
        systemctl restart kesl-supervisor > /dev/null
        log_i "  -> Done"
    fi
}











echo "**************************************AAVN-ICT******************************************"
echo "The script to automatic setup the new workstation which using Linux-Mint OS"
echo "Latest updated at 04-09-2019 by AAVN-ICT Team"
echo "Process in your workstation:"
echo "  - Install some basic configuration and auto update apt"
echo "  - Change hostname and join to aavn domain AD. Modify workstation information in AD"
echo "  - Active AAVN DNS in your workstation"
echo "  - Install Salt-Stack"
echo "  - Install KAS"
echo "  - Install AAVN locally certificate"
echo "Any change or request please contact AAVN-ICT Team to get a support"
echo "****************************************************************************************"
echo "Please to set the requirments for installing"



echo "Please set your location: [hcm/dn/ct/ygn]"
read LDAP_LOCATION
case ${LDAP_LOCATION} in
dn|hcm|ct|ygn);;
*)
echo "Location is wrong. Values are hcm/dn/ct/ygn"
exit 1
;;
esac
if [[ "${LDAP_LOCATION}" == "dn" ]];then
    PRE_HOSTNAME="dn-aavn-ws"
    OU_WORKSTATION="DN_workstations"
    KAS_SERVER="192.168.77.246"
    LDAP_SERVER="192.168.77.9"
elif [[ "${LDAP_LOCATION}" == "ct" ]];then
    PRE_HOSTNAME="ct-aavn-ws"
    OU_WORKSTATION="CT_workstations"
    KAS_SERVER="192.168.84.203"
    LDAP_SERVER="192.168.84.202"
elif [[ "${LDAP_LOCATION}" == "ygn" ]];then
    PRE_HOSTNAME="aamm-ws"
    OU_WORKSTATION="YGN_workstations"
    LDAP_SERVER="192.168.70.202"
else
    PRE_HOSTNAME="aavn-ws"
    OU_WORKSTATION="HCM_workstations"
    KAS_SERVER="192.168.70.39"
    LDAP_SERVER="192.168.70.202"
fi

echo "Do you want to join workstation to AAVN AD ? : [y/n] - Default is yes"
read ASK_DOMAIN

echo "Do you want to install Salt Minion ? : [y/n] - Default is yes"
read ASK_SALT

echo "Do you want to install KAS ? : [y/n] - Default is yes"
read ASK_KAS


case ${ASK_DOMAIN} in
n|N)
shift
;;
*)
basic_installation &&
ldap_data &&
join_domain
shift
;;
esac

case ${ASK_SALT} in
n|N)
shift
;;
*)
salt_stack
shift
;;
esac

case ${ASK_KAS} in
n|N)
shift
;;
*)
kas
shift
;;
esac

rm -rf ${AAVNICT_TEMP_DIR}
