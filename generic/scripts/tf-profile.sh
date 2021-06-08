#!/usr/bin/env bash
# Script to work with Terraform workspaces

PROGRAM=$(basename $0)
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')

declare -A profilesArray
debug=0

# PS1 parameters
TF_PS1_STATUS_PATH="${HOME}/.terraform/tr-ps1/ps1.status"
if [ ! -f ${TF_PS1_STATUS_PATH} ]; then
  mkdir -p -- "$(dirname "${TF_PS1_STATUS_PATH}")"
  echo "off" > ${TF_PS1_STATUS_PATH}
fi
# Are we in a terraform directory?
[[ $(ls -a | egrep "^.terraform$") == ".terraform" ]] && IS_TF_DIR=1 || IS_TF_DIR=0

# Cache selected profile
TF_PROFILE_PATH="${HOME}/.terraform/tr-ps1/ps1.profile"
if [ ! -f ${TF_PROFILE_PATH} ]; then
  mkdir -p -- "$(dirname "${TF_PROFILE_PATH}")"
  terraform workspace show > $TF_PROFILE_PATH
fi
currentProfile=$(cat $TF_PROFILE_PATH)

TF_PS1_STATUS=$(cat ${TF_PS1_STATUS_PATH})
COLOR_PS1_OPEN_ESC=$'\001'
COLOR_PS1_CLOSE_ESC=$'\002'
COLOR_PS1_DEFAULT_BG=$'\033[49m'
COLOR_PS1_DEFAULT_FG=$'\033[39m'

Usage()
{
  echo ""
  echo "Usage: $PROGRAM -option"
  echo ""
  echo "options:"
  echo "- ps1                  : Only used in the initial setting in the .bash_profile"
  echo "                         PS1='\$(tr-profile.sh -ps1)'$PS1"
  echo "- pson                 : Globally enable Terraform PS1 prompt"
  echo "- psoff                : Globally disable Terraform PS1 prompt"
  exit 5
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
    if [ $TF_PS1_STATUS == "on" ] && [ $IS_TF_DIR -eq 1 ]; then
      # if [[ $(find "$TF_PROFILE_PATH" -mmin +1 -print) ]]; then
        # echo "Updating Terraform Profile PS1"
        terraform workspace show > $TF_PROFILE_PATH
      # fi
      currentProfile=$(cat $TF_PROFILE_PATH)

      COLOR_PROVIDER=yellow
      COLOR_PROFILE=red
      COLOR_REGION=cyan
      PS1="🔢$(_ps1_color_fg ${COLOR_PROVIDER}) Terraform${COLOR_PS1_DEFAULT_FG}|$(_ps1_color_fg ${COLOR_PROFILE})$currentProfile${COLOR_PS1_DEFAULT_FG}"
      printf "$PS1\n\x1e"
    fi
  ;;
  -pson)
    echo "on" > ${TF_PS1_STATUS_PATH}
  ;;
  -psoff)
    echo "off" > ${TF_PS1_STATUS_PATH}
  ;;
  *)
    echo "Unknown option"
    Usage
  ;;
esac

