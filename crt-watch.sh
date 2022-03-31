#!/bin/bash
#
# Copyright 2020 Juraj Ontkanin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

VERSION=0.1.5
SCRIPT_NAME="Certificate Transparency Logs Monitor v${VERSION}"

##############################################################################
## Usage
##

usage() {
cat << EOF

$SCRIPT_NAME

The script monitors Certificate Transparency Logs via crt.sh site and reports 
new certificates issued for the domain specified by the config file. It logs 
and sends alerts every time there is a change detected. It uses local sendmail 
for sending the alerts.

usage: $(basename $0) [OPTION]

OPTION:

    -c CONFIG_FILE  configuration INI file for $(basename $0)
    -h              show this help

CONFIG FILE:

    DOMAIN          name of the domain to monitor
    EMAIL_FROM      email address of a sender
    EMAIL_TO        email address of a TO recipient
    EMAIL_CC        email address of a CC recipient
    EMAIL_BCC       email address of a BCC recipient
    EMAIL_SUBJECT   subject of the email
    LOG_DIR         directory where to store log file for the domain
    REPORT_NEW      yes = report new certificates;
                    no  = do not report new certificates

EOF
}

##############################################################################
## Fatal Error
##

fatal_error() {

  echo "--- ERROR: $@" >&2
  echo
  exit 2
}

##############################################################################
## Parse INI file
##

parse_ini() {

  [[ -z $1 ]] && fatal_error "[${FUNCNAME[0]}] missing INI file parameter"
  [[ -z $2 ]] && fatal_error "[${FUNCNAME[0]}] missing INI key parameter"

  egrep -i "^\s*${2}\s*=\s*" "$1" | cut -d= -f2- | xargs
}

##############################################################################
## URL encode
##

url_encode() {

  [[ -z $1 ]] && fatal_error "[${FUNCNAME[0]}] missing parameter"

  curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" <<< "$1" | sed -E 's/..(.*).../\1/'
}

##############################################################################
## Email processing
##

send_report_email() {

  (
    # Email headers
    #
    [[ -n $EMAIL_FROM ]] && echo "FROM: ${EMAIL_FROM}"
    [[ -n $EMAIL_TO ]]   && echo "TO: ${EMAIL_TO}"
    [[ -n $EMAIL_CC ]]   && echo "CC: ${EMAIL_CC}"
    [[ -n $EMAIL_BCC ]]  && echo "BCC: ${EMAIL_BCC}"

    echo "Subject: ${EMAIL_SUBJECT}"
    echo 'MIME-Version: 1.0'
    echo 'Content-Type: text/html; charset="UTF-8"'

    echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
    echo '<html dir="ltr" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">'
    echo '<head>'
    echo '  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />'
    echo '  <meta name="description" xml:lang="en" content="Certificate Transparency Logs Monitoring" />'
    echo '  <meta name="MSSmartTagsPreventParsing" content="TRUE" />'
    echo "  <title>${EMAIL_SUBJECT}</title>"
    echo '  <style type="text/css">'
    echo '  <!--'
    echo '    @media all {'
    echo '      * { padding: 0; margin: 0; }'
    echo '      body { font: normal 90%/1.5em Arial, Helvetica, sans-serif; color: #000; background-color: #fff; padding: 2em; text-align: left; }'
    echo '      h1 { font-size: 1.7em; padding: 0.3em 0 .5em; text-align: center; }'
    echo '      h2 { font-size: 1.3em; padding: 0 0 .5em; }'
    echo '      p { padding: .5em 0; }'
    echo '      dl { padding: 1em 0; }'
    echo '      dt { font-weight: bold; }'
    echo '      dd { font-family: "Lucida Console", Monaco, monospace; }'
    echo '      li, dd { margin-left: 1.5em; padding-left: .5em; }'
    echo '      a { background-color: #fff; color: #2960a7; }'
    echo '      #wrapper { line-height: 1.8em; }'
    echo '    }'
    echo '  -->'
    echo '  </style>'
    echo '</head>'
    echo '<body xml:lang="en">'

    echo '<div id="wrapper">'
    echo "  <strong>Domain:</strong> $( tr '[:lower:]' '[:upper:]' <<< ${DOMAIN} )<br/>"
    echo "  <strong>Date:</strong> ${TIMESTAMP}"
    echo '</div>'

    echo '<p></p>'
    
    echo "<p>The following certificates have been issued since the last CRT report:</p>"

    while read SERIAL_NUMBER; do
      CRTSH_ID="$(    jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .id'          <<< "$JSON_DATA" | head -n1 )"
      ISSUER_NAME="$( jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .issuer_name' <<< "$JSON_DATA" | sort -u )"
      COMMON_NAME="$( jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .common_name' <<< "$JSON_DATA" | sort -u )"
      NAME_VALUE="$(  jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .name_value'  <<< "$JSON_DATA" | sort -u | tr '\n' ',' | sed -e 's/,/, /g' -e 's/, $//g' )"
      NOT_BEFORE="$(  jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .not_before'  <<< "$JSON_DATA" | sort -u )"
      NOT_AFTER="$(   jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .not_after'   <<< "$JSON_DATA" | sort -u )"
      # echo '<p>'
      echo '<dl>'
      echo '<dt>crt.sh ID</dt>'
      echo "<dd><a href='https://crt.sh/?id=${CRTSH_ID}&opt=x509lint,cablint,zlint,nometadata'>${CRTSH_ID}</a></dd>"
      echo '<dt>Serial Number</dt>'
      echo "<dd>${SERIAL_NUMBER}</dd>"
      echo '<dt>Not Before</dt>'
      echo "<dd>${NOT_BEFORE}</dd>"
      echo '<dt>Not After</dt>'
      echo "<dd>${NOT_AFTER}</dd>"
      echo '<dt>Common Name</dt>'
      echo "<dd>${COMMON_NAME}</dd>"
      echo '<dt>Matching Identities</dt>'
      echo "<dd>${NAME_VALUE}</dd>"
      echo '<dt>Issuer Name</dt>'
      echo "<dd>${ISSUER_NAME}</dd>"
      echo '</dl>'
    done <<< "$CRTLOG_NEW"

    echo '<p></p>'
    echo '</body>'
    echo '</html>'

  ) | /usr/sbin/sendmail -t -i

}

##############################################################################
## MAIN
##############################################################################

## Make a note about the date and time the script is being run
##

TIMESTAMP="$( date +'%F %T' )"

## Check if 'curl' is installed
##

curl -h 1>/dev/null 2>/dev/null
[[ $? -ne 0 ]] && fatal_error "[main] 'curl' is not installed!"

## Check if 'jq' is installed
##

jq -h 1>/dev/null 2>/dev/null
[[ $? -gt 1 ]] && fatal_error "[main] 'jq' is not installed!"


## Collect OPTIONS and PARAMETERS
##

CONFIGFILE_DEFAULT=""

OPTIND=1

while getopts ":c:h" OPTION; do
  case "$OPTION" in
    c)
      CONFIGFILE="$OPTARG"
      ;;
    h)
      usage
      exit 1
      ;;
    *)
      usage
      fatal_error "[main] unrecognized option or missing argument: -$OPTARG"
      ;;
  esac
done

shift $(($OPTIND - 1))

ARGC=0; ARGS=()
while [[ -n "$1" ]]; do
  ARGS[(( ARGC++ ))]=$1;
  shift
done

case "$ARGC" in
  0)
    ## nothing to do here
    ;;
  *)
    usage
    fatal_error "[main] too many arguments"
    ;;
esac

: ${CONFIGFILE=$CONFIGFILE_DEFAULT}

## Load, normalize and parse INI config file
##

[[ -z "$CONFIGFILE" ]] || [[ ! -f "$CONFIGFILE" ]] && usage && exit 1

DOMAIN="$(          parse_ini "$CONFIGFILE" 'DOMAIN'          | tr '[:upper:]' '[:lower:]' )"
EMAIL_FROM="$(      parse_ini "$CONFIGFILE" 'EMAIL_FROM'      )"
EMAIL_TO="$(        parse_ini "$CONFIGFILE" 'EMAIL_TO'        )"
EMAIL_CC="$(        parse_ini "$CONFIGFILE" 'EMAIL_CC'        )"
EMAIL_BCC="$(       parse_ini "$CONFIGFILE" 'EMAIL_BCC'       )"
EMAIL_SUBJECT="$(   parse_ini "$CONFIGFILE" 'EMAIL_SUBJECT'   )"
LOG_DIR="$(         parse_ini "$CONFIGFILE" 'LOG_DIR'         | sed -e 's;/$;;g' )"
REPORT_NEW="$(      parse_ini "$CONFIGFILE" 'REPORT_NEW'      | tr '[:upper:]' '[:lower:]' )"

## Check config file settings
##

[[ -z "$DOMAIN"   ]] && fatal_error "[main] DOMAIN not specified!"

if [[ -n "$LOG_DIR" ]]; then
  [[ -e "$LOG_DIR" ]] && [[ ! -d "$LOG_DIR" ]] && fatal_error "[main] LOG_DIR not a directory!"
else
  LOG_DIR='.'
fi

## Get list of serial numbers from CRT.SH
##

DOMAIN_ENC="$( url_encode "$DOMAIN" )"

CRT_NEW="${LOG_DIR}/${DOMAIN_ENC}.serial.new"
CRT_OLD="${LOG_DIR}/${DOMAIN_ENC}.serial"

CRTSH_URL="https://crt.sh/?identity=${DOMAIN_ENC}&exclude=expired&dir=^&sort=1&group=none&output=json"

OUT="$( curl -qSfsw '\n%{http_code}' "$CRTSH_URL" 2>/dev/null )"
RET=$?

HTTP_CODE=$(  tail -n1 <<< "$OUT" )
JSON_DATA="$( head -n1 <<< "$OUT" )"
CRT_BUFFER=""

if [[ $RET -eq 0 ]]; then
  SERIAL_NUMBERS="$( jq -r .[].serial_number <<< "$JSON_DATA" )"
  RET=$?
  if [[ $RET -eq 0 ]]; then
    CRT_BUFFER="$( egrep '^[A-Fa-f0-9]' <<< "$SERIAL_NUMBERS" | sort -u )"
  else
    fatal_error "[main] error when processing JSON data!"
  fi
  [[ -z "$SERIAL_NUMBERS" ]] && fatal_error "[main] missing data!"
else
  fatal_error "[main] curl(${RET})/http(${HTTP_CODE}) when contacting '${CRTSH_URL}'!"
fi

## There's no CRT_OLD in the first run, so there'll be nothing to report
##

if [[ -f "$CRT_OLD" ]]; then

  ## Write down collected serial numbers
  echo "$CRT_BUFFER" > "$CRT_NEW"

  ## Compare old and new serial numbers
  CRTLOG_NEW="$( diff --changed-group-format='%<' --unchanged-group-format='' "$CRT_NEW" "$CRT_OLD" | sort )"

  ## Log new certificates into changelog, and send mail report if needed
  ##

  CHANGELOG="${LOG_DIR}/${DOMAIN_ENC}.log"
  SEND_NEW='no'

  if [[ $( wc -w <<< "$CRTLOG_NEW" ) -gt 0 ]]; then
    while read SERIAL_NUMBER; do
      CRTSH_ID="$(    jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .id'          <<< "$JSON_DATA" | head -n1 )"
      ISSUER_NAME="$( jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .issuer_name' <<< "$JSON_DATA" | sort -u )"
      COMMON_NAME="$( jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .common_name' <<< "$JSON_DATA" | sort -u )"
      NAME_VALUE="$(  jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .name_value'  <<< "$JSON_DATA" | sort -u | tr '\n' ',' | sed -e 's/,/, /g' -e 's/, $//g' )"
      NOT_BEFORE="$(  jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .not_before'  <<< "$JSON_DATA" | sort -u )"
      NOT_AFTER="$(   jq -r --arg SERIAL_NUMBER "$SERIAL_NUMBER" '.[] | select(.serial_number == $SERIAL_NUMBER) | .not_after'   <<< "$JSON_DATA" | sort -u )"
      echo "${TIMESTAMP} domain=\"${DOMAIN}\" crtsh_id=\"${CRTSH_ID}\" serial_number=\"${SERIAL_NUMBER}\" not_before=\"${NOT_BEFORE}\" not_after=\"${NOT_AFTER}\" common_name=\"${COMMON_NAME}\" name_value=\"${NAME_VALUE}\" issuer_name=\"${ISSUER_NAME}\"" >> "$CHANGELOG"
    done <<< "$CRTLOG_NEW"
    [[ $REPORT_NEW == 'yes' ]] && SEND_NEW='yes'
    mv "$CRT_NEW" "$CRT_OLD"
  else
    rm -f "$CRT_NEW"
  fi

  if [[ $SEND_NEW == 'yes' ]]; then
    [[ -z "$EMAIL_FROM"    ]] && EMAIL_FROM='root'
    [[ -z "$EMAIL_TO"      ]] && [[ -z "$EMAIL_CC" ]] && [[ -z "$EMAIL_BCC" ]] && EMAIL_TO='root'
    [[ -z "$EMAIL_SUBJECT" ]] && EMAIL_SUBJECT="CRT report for $( tr '[:lower:]' '[:upper:]' <<< ${DOMAIN} )"
    send_report_email
  fi
fi

