#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

export LC_ALL=C

host="sunfire.comp.nus.edu.sg"
default_printqueue="psc008-dx"

usage() {
  cat <<EOF
Bash script to print stuff in NUS SoC.

Requirements: bash, a sunfire account, and connection to SoC wifi.

Usage (copy-pastable one-liner):
  curl -s https://raw.githubusercontent.com/dlqs/SOCprint/master/socprint.sh | bash /dev/stdin -u <username> -f <filename> -p <printqueue>

Usage (to download and run from any directory):
  sudo curl https://raw.githubusercontent.com/dlqs/SOCprint/master/socprint.sh -o /usr/local/bin/socprint.sh
  sudo chmod 755 /usr/local/bin/socprint.sh
  socprint.sh -u <username> -f <filename> -p <printqueue>
  
Parameters:
 -u, --username         (required) Sunfire username (without the @sunfire.comp.nus.edu.sg part).
 -i, --identity-file    (optional) Identity file to pass into ssh. If set, avoids interactive password.
 -f, --filename         (required to print) File to print. Tested with PDF/plain text files. Undefined behaviour for anything else.
 -p, --printqueue       (optional to print) Printqueue to send job to. Defaults to psc008-dx.
 -l, --list-printqueues (required to list printqueues) List printqueues i.e. valid arguments for -p.

Print command example:
  ./socprint.sh -u d-lee -f ~/Downloads/cs3210_tutorial8.pdf -p psc008-dx

List printqueue command example:
  ./socprint.sh -u d-lee -l

Roughly speaking, this script will:
  1. Login to sunfire using ssh. You will be prompted for your password (unless you use the -i option). This script does not save/record your password.
  2. Copy your file into your home directory in sunfire.comp.nus.edu.sg to a temporary, random name.
  3. Submit your job to the printqueue.
  4. List the printqueue. You *should* see your job here. If not, something has gone wrong.
  5. Remove the temporary file.

Printqueues:
  - (you're probably looking for these locations)
  - COM1 basement:                   psc008 psc008-dx psc008-sx psc011 psc011-dx psc011-sx
  - COM1 L1, in front of tech svsc:  psts psts-dx psts-sx pstsb pstsb-dx pstsb-sx
  - Most other printers have user restrictions. See https://dochub.comp.nus.edu.sg/cf/guides/printing/print-queues

The suffixes mean:
  - (no suffix) or -dx: double sided
  - -sx: single sided

Source: https://github.com/dlqs/SOCprint

EOF
  exit
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  identity_file=''
  printqueue=''
  list_printqueues=false

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -l | --list-printqueues) 
      list_printqueues=true
      ;;
    -i | --identity-file) 
      identity_file="${2-}" 
      shift
      ;;
    -p | --printqueue) 
      printqueue="${2-}" 
      shift
      ;;
    -f | --filename) 
      filename="${2-}" 
      shift
      ;;
    -u | --username)
      username="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  return 0
}

parse_params "$@"

[[ -z "${username-}" ]] && die "Missing required parameter: -u/--username"
sshcmd="${username}@${host}"
if [[ ! -z ${identity_file} ]]; then
  # Use the ssh identity_file if provided
  sshcmd="${sshcmd} -i ${identity_file}"
fi

msg "Using ${username}@${host} ..."
if [[ $list_printqueues == true ]]; then
  # Thanks @pengnam for the regex
  ssh $sshcmd "cat /etc/printcap | grep '^p' | sed 's/^\([^:]*\).*$/\1/'"
  exit 0
fi

[[ -z "${filename-}" ]] && die "Missing required parameter: -f/--filename"
[[ ! -f "${filename-}" ]] && die "Error: No such file"

filetype=$(file -i $filename | cut -f 2 -d ' ')
[[ $filetype != "application/pdf;" && $filetype != text* ]] && msg "Warning: File is not PDF or text. Print behaviour is undefined."

# Generate a random 8 character alphanumeric string *without* tr
tempname=$(perl -e '@c=("A".."Z","a".."z",0..9);$p.=$c[rand(scalar @c)] for 1..8; print "$p\n"')
tempname="SOCPrint_${tempname}"

[[ -z "${printqueue-}" ]] && msg "Using default printqueue: ${default_printqueue}" && msg "Hint: To set a different one, use the -p option. To list all, use the -l option."
printqueue=$default_printqueue

ssh $sshcmd "cat - > ${tempname}; lpr -P ${printqueue} ${tempname}; lpq -P ${printqueue}; rm ${tempname};" < "${filename}"

exit 0
