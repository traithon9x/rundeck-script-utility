#!/usr/bin/env bash
# Dan Wanek
# Mon Jul 25 11:43:54 CDT 2011
#
# There is a good document from Apple on how to set up Active Directory for Mac that can be found
# at http://www.seminars.apple.com/contactme/pdf/L334436B_ActiveDirect_WP.pdf

# Default settings
COMPUTER_NAME=`hostname -s | tr "[:lower:]" "[:upper:]"`
RENAME_COMPUTER=false
LEAVE_DOMAIN=false
VERBOSE=false


print_usage() {
cat <<EOF
adctl.sh -U <ad_user> [options]
  -h            This message.
  -d FQDN       The FQDN of the domain (ex. k12.nd.us)
  -o OU         The OU to add this computer to.  (ex. OU=Computers,DC=K12,DC=ND,DC=US)
  -N            Rename this host as part of the process.
  -n newname    If -n is given you can specify the new name as an option, otherwise prompts will occur.
  -v            Verbose output
  -x            Delete this host from the domain.

  EXAMPLES:

  # add to domain as-is
  adctl.sh -U myuser -d k12.nd.us -o 'OU=Computers,OU=ITD,DC=K12,DC=ND,DC=US'
  # add to domain and rename host
  adctl.sh -U myuser -d k12.nd.us -o 'OU=Computers,OU=ITD,DC=K12,DC=ND,DC=US' -Nn mynewhostname.domainname
  # delete host from domain
  adctl.sh -U myser -x
EOF
}

logit() {
  if ($VERBOSE)
  then
    echo $*
  fi
}

rename_host() {
  if [ -x NEW_COMPUTER_NAME ]
  then
    echo -n 'Enter new FQDN of the host: '
    read NEW_COMPUTER_NAME
  fi
  sudo scutil --set HostName $NEW_COMPUTER_NAME
  COMPUTER_NAME=`hostname -s | tr "[:lower:]" "[:upper:]"`
  sudo scutil --set ComputerName $COMPUTER_NAME
}

join_domain() {
  logit "Joining domain ${AD_DOMAIN}"

  sudo defaults write /Library/Preferences/DirectoryService/DirectoryService "Active Directory" Active
  reset_directory_svc

  STANDARD_OPTS="-f -a $COMPUTER_NAME -u $AD_ADMIN -domain $AD_DOMAIN -ou $COMPUTER_OU"
  sudo dsconfigad $STANDARD_OPTS

  EXTRA_OPTS="-mobile enable -mobileconfirm disable -useuncpath enable"
  # Add extra Mac OSX Server options
  dsconfigad -h | grep -qi enablesso
  if [ $? -eq 0 ]
  then
    EXTRA_OPTS="${EXTRA_OPTS} -enableSSO"
  fi
  sudo dsconfigad $EXTRA_OPTS

  sudo dsconfigad -groups "domain admins"

  # Auth
  logit "Setting up authentication paths..."
  sudo dscl /Search -create / SearchPolicy CSPSearchPath
  sudo dscl /Search -append / CSPSearchPath "/Active Directory/All Domains"
  # Contacts
  logit "Setting up contacts paths..."
  sudo dscl /Search/Contacts -create / SearchPolicy CSPSearchPath
  sudo dscl /Search/Contacts -append / CSPSearchPath "/Active Directory/All Domains"
}

leave_domain() {
  logit "Leaving domain..."
  STANDARD_OPTS="-u $AD_ADMIN -r"
  sudo dsconfigad -nogroups
  sudo dsconfigad $STANDARD_OPTS
  sudo dscl /Search -delete / CSPSearchPath "/Active Directory/All Domains"
  sudo dscl /Search/Contacts -delete / CSPSearchPath "/Active Directory/All Domains"
  sudo defaults write /Library/Preferences/DirectoryService/DirectoryService "Active Directory" Inactive
}

reset_directory_svc() {
  logit "Restarting DirectoryService"
  sudo killall DirectoryService
}

parse_options() {
  while getopts ":hd:Nn:o:U:vx" opt; do
    case $opt in
      h)
        print_usage
        exit 0
        ;;
      d)
        AD_DOMAIN=$OPTARG
        ;;
      N)
        RENAME_COMPUTER=true
        ;;
      n)
        NEW_COMPUTER_NAME=$OPTARG
        ;;
      o)
        COMPUTER_OU=$OPTARG
        ;;
      U)
        AD_ADMIN=$OPTARG
        ;;
      v)
        VERBOSE=true
        ;;
      x)
        LEAVE_DOMAIN=true
        ;;
      \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
      :)
        echo "Option -${OPTARG} requires an argument." >&2
        exit 1
        ;;
    esac
  done
}


if [ ${#@} -eq 0 ]; then print_usage; exit 1; fi

parse_options $@

if [ -x $AD_ADMIN ]; then print_usage; exit 1; fi

reset_directory_svc

if ($LEAVE_DOMAIN)
then
  leave_domain
else
  if [ -x $AD_DOMAIN ] || [ -x $COMPUTER_OU ]; then print_usage; exit 1; fi
  if ($RENAME_COMPUTER)
  then
    rename_host
  fi
  join_domain
fi

reset_directory_svc


exit 0
