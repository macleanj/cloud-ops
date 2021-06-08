#!/usr/bin/env bash
# Script to work with AWS profiles

PROGRAM=$(basename $0)
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')

profileFile="${HOME}/.aws/config"
currentProfile=$AWS_PROFILE
currentRegion=""
declare -A profileRegions
debug=0

# PS1 parameters
AWS_PS1_STATUS_PATH="${HOME}/.aws/aws-ps1/ps1.status"
if [ ! -f ${AWS_PS1_STATUS_PATH} ]; then
  mkdir -p -- "$(dirname "${AWS_PS1_STATUS_PATH}")"
  echo "off" > ${AWS_PS1_STATUS_PATH}
fi
AWS_PS1_STATUS=$(cat ${AWS_PS1_STATUS_PATH})
COLOR_PS1_OPEN_ESC=$'\001'
COLOR_PS1_CLOSE_ESC=$'\002'
COLOR_PS1_DEFAULT_BG=$'\033[49m'
COLOR_PS1_DEFAULT_FG=$'\033[39m'

Usage()
{
  echo ""
  echo "Usage: $PROGRAM -<option>"
  echo ""
  echo "options:"
  echo "- ps1                  : Only used in the initial setting in the .bash_profile"
  echo "                         PS1='\$(aws-profile.sh -ps1)'$PS1"
  echo "- pson                 : Globally enable AWS PS1 prompt"
  echo "- psoff                : Globally disable AWS PS1 prompt"
  echo "- show                 : Show all AWS profiles. Thereafter one can manually export the \$AWS_PROFILE"
  echo "                         and the PS1 will change automatically"
  echo "- select               : Select AWS profiles."
  exit 5
}

AwsProfiles()
{
  option=$1
  OLDIFS=$IFS
  IFS=$'\n'
  if [ -f ${profileFile} ]; then
    count=1
    profile=""
    region=""
    defaultAccountSuffix=""
    for entry in $(cat ${profileFile}); do
      if [[ $entry =~ default ]]; then
        profile="default"
      elif [[ $entry =~ profile ]]; then
        profile=$(echo $entry | sed -e 's/^\[profile \(.*\)\]/\1/g')
      elif [[ $entry =~ region ]]; then
        region=$(echo $entry | sed -e 's/.* = //g')
      else
        [ $debug -eq 1 ] && echo "profile = $profile"
        [ $debug -eq 1 ] && echo "region = $region"
        profileRegions[$profile]=$region
        if [ $count -lt 10 ]; then
          indent="  "
        elif [ $count -lt 100 ]; then
          indent=" "
        else
          indent=""
        fi
        if [ -z "$currentProfile" ] && [ $profile == "default" ] || [ $profile == "$currentProfile" ]; then
          indent="$indent* "
        else
          indent="$indent  "
        fi
        defaultAccountSuffix=""
        [ "$profile" == "default" ] && defaultAccountSuffix=" - DON'T USE!!!"
        [[ "$profile" =~ "preprod" ]] && defaultAccountSuffix=" - Migration account!!!"
        [ $option == "show" ] && echo "${indent}${count}. $profile (${profileRegions[$profile]})$defaultAccountSuffix"
        ((count=count+1))
      fi
    done
    IFS=$OLDIFS

    [ -z "$currentProfile" ] && currentProfile="default"
    currentRegion=${profileRegions[$currentProfile]}
    if [ $option == "show" ]; then
      echo ""
      echo -e ">>> Change? export AWS_PROFILE=<profile> \n"
    fi

  else
    echo "Missing ${profileFile}"
    echo
    exit 5
  fi
}

# _awson_usage() {
#   cat <<"EOF"
# Toggle aws-ps1 prompt on

# Usage: awson [-g | --global] [-h | --help]

# With no arguments, turn off aws-ps1 status for this shell instance (default).

#   -g --global  turn on aws-ps1 status globally
#   -h --help    print this message
# EOF
# }

# _awsoff_usage() {
#   cat <<"EOF"
# Toggle aws-ps1 prompt off

# Usage: awsoff [-g | --global] [-h | --help]

# With no arguments, turn off aws-ps1 status for this shell instance (default).

#   -g --global turn off aws-ps1 status globally
#   -h --help   print this message
# EOF
# }

# awson() {
#   if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
#     _awson_usage
#   elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
#     rm -f -- "${AWS_PS1_DISABLE_PATH}"
#   elif [[ "$#" -ne 0 ]]; then
#     echo -e "error: unrecognized flag ${1}\\n"
#     _awson_usage
#     return
#   fi

#   AWS_PS1_ENABLED=on
# }

# awsoff() {
#   if [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
#     _awsoff_usage
#   elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
#     mkdir -p -- "$(dirname "${AWS_PS1_DISABLE_PATH}")"
#     touch -- "${AWS_PS1_DISABLE_PATH}"
#   elif [[ $# -ne 0 ]]; then
#     echo "error: unrecognized flag ${1}" >&2
#     _awsoff_usage
#     return
#   fi

#   AWS_PS1_ENABLED=off
# }

_ps1_color_fg() {
  local PS1_FG_CODE
  case "${1}" in
    black) PS1_FG_CODE=0;;
    red) PS1_FG_CODE=1;;
    green) PS1_FG_CODE=2;;
    yellow) PS1_FG_CODE=3;;
    blue) PS1_FG_CODE=4;;
    magenta) PS1_FG_CODE=5;;
    cyan) PS1_FG_CODE=6;;
    white) PS1_FG_CODE=7;;
    # 256
    [0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-6]) PS1_FG_CODE="${1}";;
    *) PS1_FG_CODE=default
  esac

  if [[ "${PS1_FG_CODE}" == "default" ]]; then
    PS1_FG_CODE="${_PS1_DEFAULT_FG}"
  else
    if tput setaf 1 &> /dev/null; then
      PS1_FG_CODE="$(tput setaf ${PS1_FG_CODE})"
    elif [[ $PS1_FG_CODE -ge 0 ]] && [[ $PS1_FG_CODE -le 256 ]]; then
      PS1_FG_CODE="\033[38;5;${PS1_FG_CODE}m"
    else
      PS1_FG_CODE="${_PS1_DEFAULT_FG}"
    fi
  fi
  echo ${_PS1_OPEN_ESC}${PS1_FG_CODE}${_PS1_CLOSE_ESC}
}

case "$1" in
  -ps1)
    # Used in PS1 COMMAND_PROMPT in shell environment!!
    if [ $AWS_PS1_STATUS == "on" ]; then
      AwsProfiles current
      COLOR_PROVIDER=yellow
      COLOR_PROFILE=red
      COLOR_REGION=cyan
      PS1="☁️ $(_ps1_color_fg ${COLOR_PROVIDER}) AWS${COLOR_PS1_DEFAULT_FG}|$(_ps1_color_fg ${COLOR_PROFILE})$currentProfile${COLOR_PS1_DEFAULT_FG}:$(_ps1_color_fg ${COLOR_REGION})$currentRegion${COLOR_PS1_DEFAULT_FG}"
      printf "$PS1\n\x1e"
    fi
  ;;
  -pson)
    echo "on" > ${AWS_PS1_STATUS_PATH}
  ;;
  -psoff)
    echo "off" > ${AWS_PS1_STATUS_PATH}
  ;;
  -show)
    echo "All AWS profiles"
    AwsProfiles show
    # for x in "${!profileRegions[@]}"; do printf "[%s]=%s\n" "$x" "${profileRegions[$x]}" ; done
  ;;
  # select will be realized via export
  # -select)
  #   echo "Select AWS profiles"
  #   AwsProfiles select
  # ;;
  *)
    echo "Unknown option"
    Usage
  ;;
esac

