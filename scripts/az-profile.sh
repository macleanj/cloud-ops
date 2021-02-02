#!/usr/bin/env bash
# Script to work with Azure profiles

programName=$(basename $0)
baseName=$(echo $(basename "$0") | sed -e 's/.sh//g')

declare -A profilesArray
debug=0

# PS1 parameters
AZ_PS1_STATUS_PATH="${HOME}/.azure/az-ps1/ps1.status"
if [ ! -f ${AZ_PS1_STATUS_PATH} ]; then
  mkdir -p -- "$(dirname "${AZ_PS1_STATUS_PATH}")"
  echo "off" > ${AZ_PS1_STATUS_PATH}
fi

# Cache selected profile
AZ_PROFILE_PATH="${HOME}/.azure/az-ps1/ps1.profile"
if [ ! -f ${AZ_PROFILE_PATH} ]; then
  mkdir -p -- "$(dirname "${AZ_PROFILE_PATH}")"
  az account show | jq -r '.name' > $AZ_PROFILE_PATH
fi
currentProfile=$(cat $AZ_PROFILE_PATH)

AZ_PS1_STATUS=$(cat ${AZ_PS1_STATUS_PATH})
COLOR_PS1_OPEN_ESC=$'\001'
COLOR_PS1_CLOSE_ESC=$'\002'
COLOR_PS1_DEFAULT_BG=$'\033[49m'
COLOR_PS1_DEFAULT_FG=$'\033[39m'

Usage()
{
  echo ""
  echo "Usage: $programName -option"
  echo ""
  echo "options:"
  echo "- ps1                  : Only used in the initial setting in the .bash_profile"
  echo "                         PS1='\$(az-profile.sh -ps1)'$PS1"
  echo "- pson                 : Globally enable Azure PS1 prompt"
  echo "- psoff                : Globally disable Azure PS1 prompt"
  echo "- show                 : Show all Azure profiles."
  echo "- select               : Select Azure profiles."
  exit 5
}

AzProfiles()
{
  option=$1
  OLDIFS=$IFS
  IFS=$'\n'
    count=1
    arrayCount=0
    profile=""
    defaultAccountSuffix=""
    accountList=$(az account list)
    # cat tessie.txt | jq -r '.[]'
    for entry in $(echo "${accountList}" | jq -r '.[] | @base64'); do
      profilesArray[$count]=${entry}

      if [ $count -lt 10 ]; then
        indent="  "
      elif [ $count -lt 100 ]; then
        indent=" "
      else
        indent=""
      fi

      if [[ $(_jq ${entry} '.name') == "$currentProfile" ]]; then
        indent="$indent* "
        arrayCount=$count
      else
        indent="$indent  "
      fi

      [[ $(_jq ${entry} '.name') =~ N/A ]] && defaultAccountSuffix=" - DON'T USE!!!" || defaultAccountSuffix=""
      [ $option == "show" ] || [ $option == "select" ] && echo "${indent}${count}. $(_jq ${entry} '.name')$defaultAccountSuffix"
      ((count=count+1))
    done
    IFS=$OLDIFS

    if [ $option == "show" ] && [ $arrayCount -ne 0 ]; then
      echo -e "Change? run $programName -select \n"

      [ $debug -eq 1 ] && echo "[debug] - profilesArray: $profilesArray"
    elif [ $option == "select" ] || [ $arrayCount -eq 0 ]; then
      PROMPT="> "
      # while read -p "${PROMPT}" selected; do
      #   echo -en "\033[1A\033[2K" # Jumps one line up, deleting the PROMPT line itslef.
      #   echo "You typed: $selected"
      # done
      read -p "${PROMPT}" selected
      _jq ${profilesArray[$selected]} '.name' > $AZ_PROFILE_PATH
      selectedAccountId=$(_jq ${profilesArray[$selected]} '.id')
      az account set --subscription="$selectedAccountId"
    else
      echo "No proper selection could be obtained. Exitting....."
      exit 5
    fi
}

_jq() {
  # $1: Row offered as base64
  # $2: Value to be selected
  echo ${1} | base64 --decode | jq -r ${2}
}

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
    if [ $AZ_PS1_STATUS == "on" ]; then
      if [[ $(find "$AZ_PROFILE_PATH" -mmin +180 -print) ]]; then
        echo "Updating Azure Profile PS1"
        az account show | jq -r '.name' > $AZ_PROFILE_PATH
      fi
      currentProfile=$(cat $AZ_PROFILE_PATH)

      COLOR_PROVIDER=yellow
      COLOR_PROFILE=red
      COLOR_REGION=cyan
      # PS1="☁️ $(_ps1_color_fg ${COLOR_PROVIDER}) Azure${COLOR_PS1_DEFAULT_FG}|$(_ps1_color_fg ${COLOR_PROFILE})$currentProfile${COLOR_PS1_DEFAULT_FG}:$(_ps1_color_fg ${COLOR_REGION})$currentRegion${COLOR_PS1_DEFAULT_FG}"
      PS1="☁️ $(_ps1_color_fg ${COLOR_PROVIDER}) Azure${COLOR_PS1_DEFAULT_FG}|$(_ps1_color_fg ${COLOR_PROFILE})$currentProfile${COLOR_PS1_DEFAULT_FG}"
      printf "$PS1\n\x1e"
    fi
  ;;
  -pson)
    echo "on" > ${AZ_PS1_STATUS_PATH}
  ;;
  -psoff)
    echo "off" > ${AZ_PS1_STATUS_PATH}
  ;;
  -show)
    echo "All Azure profiles"
    AzProfiles show
  ;;
  -select)
    echo "Select Azure profiles"
    AzProfiles select
  ;;
  *)
    echo "Unknown option"
    Usage
  ;;
esac

