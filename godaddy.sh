#!/bin/bash
 
# GoDaddy.sh v1.3 by Nazar78 @ TeaNazaR.com
###########################################
# Simple DDNS script to update GoDaddy's DNS. Just schedule every 5mins in crontab.
# With options to run scripts/programs/commands on update failure/success.
#
# Requirements:
# - curl CLI - On Debian, apt-get install curl
#
# History:
# v1.0 - 20160513 - 1st release.
# v1.1 - 20170130 - Improved compatibility.
# v1.2 - 20180416 - GoDaddy API changes - thanks Timson from Russia for notifying.
# v1.3 - 20180419 - GoDaddy API changes - thanks Rene from Mexico for notifying.
#
# PS: Feel free to distribute but kindly retain the credits (-:
###########################################

if [ $# -lt 2 ] || [ $# -gt 5 ]
then
  echo "Usage: $0 credentials domain [sub-domain] [ttl] [record_type]"
  echo "  credentials: GoDaddy developer API in the format 'key:secret' or"
  echo "               location of file containing that value on the first line"
  echo "  domain: The domain you're setting. e.g. mydomain.com"
  echo "  sub-domain: Record name, as seen in the DNS setup page. Default: @ (apex domain)"
  echo "  ttl: Time To Live in seconds. Default: 600 (10 minutes)"
  echo "  record_type: Record type, as seen in the DNS setup page. Default: A"
  exit 1
fi

## Set and validate the variables
# Get the Production API key/secret from https://developer.godaddy.com/keys/.
# Ensure it's for "Production" as first time it's created for "Test".
if [ -z "${1}" ]
then
  echo "Error: Requires API 'Key:Secret' value. Can be a file location containing the value."
  exit 1
else
  if [ -e "${1}" ]
  then
      Credentials=$(head -n 1 ${1})
  else
      Credentials=${1}
  fi
fi
if [ -z "${Credentials}" ] # Check this again in case the file had a blank line
then
  echo "Error: Requires API 'Key:Secret' value. Can be a file location containing the value."
  exit 1
fi

# Domain to update.
if [ -z "${2}" ]
then
  echo "Error: Requires 'Domain' value."
  exit 1
else
  Domain=${2}
fi

# Advanced settings - change only if you know what you're doing :-)
# Record name, as seen in the DNS setup page, default @.
Name=${3-@}
[ -z "${Name}" ] && Name=@ # To catch any bad value passed in as an argument

# Time To Live in seconds, minimum default 600 (10mins).
# If your public IP seldom changes, set it to 3600 (1hr) or more for DNS servers cache performance.
TTL=${4-600}
[ -z "${TTL}" ] && TTL=600
[ "${TTL}" -lt 600 ] && TTL=600 # 600 is the minimum

# Record type, as seen in the DNS setup page, default A.
Type=${5-A}
[ -z "${Type}" ] && Type=A

# Writable path to last known Public IP record cached. Best to place in tmpfs.
CacheFilename=${Domain}_${Type}_${Name}
# This cleans up any illegal characters e.g. When setting the * record
CachedIP=/tmp/${CacheFilename//[*\/]/_}
echo -n>>${CachedIP} 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Error: Can't write to ${CachedIP}."
  exit 1
fi

# External URL to check for current Public IP, must contain only a single plain text IP.
# Default http://api.ipify.org.
CheckURL=http://api.ipify.org

# Optional scripts/programs/commands to execute on successful update. Leave blank to disable.
# This variable will be evaluated at runtime but will not be parsed for errors nor execution guaranteed.
# Take note of the single quotes. If it's a script, ensure it's executable i.e. chmod 755 ./script.
# Example: SuccessExec='/bin/echo "$(date): My public IP changed to ${PublicIP}!">>/var/log/GoDaddy.sh.log'
SuccessExec=''

# Optional scripts/programs/commands to execute on update failure. Leave blank to disable.
# This variable will be evaluated at runtime but will not be parsed for errors nor execution guaranteed.
# Take note of the single quotes. If it's a script, ensure it's executable i.e. chmod 755 ./script.
# Example: FailedExec='/some/path/something-went-wrong.sh ${Update} && /some/path/email-script.sh ${PublicIP}'
FailedExec=''
# End settings

# Find the locally installed curl to use
Curl=$(/usr/bin/which curl 2>/dev/null)
if [ "${Curl}" = "" ]
then
  echo "Error: Unable to find 'curl CLI'."
  exit 1
fi


## Get the current public IP
echo -n "Checking current 'Public IP' from '${CheckURL}'..."
# Get current public IP
PublicIP=$(${Curl} -kLs ${CheckURL})
if [ $? -eq 0 ] && [[ "${PublicIP}" =~ [0-9]{1,3}\.[0-9]{1,3} ]]
then
  echo "${PublicIP}"
else
  echo "Fail! ${PublicIP}"
  eval ${FailedExec}
  exit 1
fi


## Compare the current public IP to the cached IP from the last run
if [ "$(cat ${CachedIP} 2>/dev/null)" = "${PublicIP}" ]
then
  echo "Current 'Public IP' matches 'Cached IP' recorded. No update required!"
  exit 0
fi


## Get the currently set IP from the GoDaddy record
echo -n "Checking '${Domain}' IP records from 'GoDaddy'..."

Check=$(${Curl} -kLs \
-H "Authorization: sso-key ${Credentials}" \
-H "Content-type: application/json" \
https://api.godaddy.com/v1/domains/${Domain}/records/${Type}/${Name} \
2>/dev/null | grep -Eo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' 2>/dev/null)


## Compare the current public IP to the GoDaddy record
if [ $? -eq 0 ] && [ "${Check}" = "${PublicIP}" ]
then
  echo -n "${Check}" > ${CachedIP} # Record the current public IP in the cache file
  echo "unchanged"
  echo "Current 'Public IP' matches 'GoDaddy' records. No update required."
  exit 0
fi


## Update the GoDaddy record with the current IP
echo "changed"
echo -n "Updating '${Domain}'..."

Update=$(${Curl} -kLs \
-X PUT \
-H "Authorization: sso-key ${Credentials}" \
-H "Content-type: application/json" \
-w "%{http_code}" \
-o /dev/null \
https://api.godaddy.com/v1/domains/${Domain}/records/${Type}/${Name} \
-d "[{\"data\":\"${PublicIP}\",\"ttl\":${TTL}}]" 2>/dev/null)

if [ $? -eq 0 ] && [ "${Update}" -eq 200 ]
then
  echo -n "${PublicIP}" > ${CachedIP} # Record the current public IP in the cache file
  echo "Success"
  eval ${SuccessExec}
  exit 0
else
  echo "Fail! HTTP_ERROR:${Update}"
  eval ${FailedExec}
  exit 1
fi
