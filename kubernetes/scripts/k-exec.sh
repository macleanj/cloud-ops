#!/bin/bash

Usage()
{
  echo "Executes interactively a shell command inside the pod that matches the regex."
  echo ""
  echo "Usage: $PROGRAM name [-c container] -- command"
  echo ""
  echo "name      : regex to catch the pod name (head -1)"
  echo "command   : Command to execute. Should always be at the end."
  echo ""
  echo "options:"
  echo "-c        : Optional: name of container"
  echo ""
  echo "Example:"
  echo "k-exec.sh fluentd -c reloader -- ls"
  exit 5
}

# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
    case "${1}" in
      -c)
        [[ ${2} =~ "^-" || -z ${2} ]] && echo ">>>>> No value given for ${1}" && Usage || container="${2}"
        shift 2
      ;;
      --)
        shift 1
        command="$@"
        break
      ;;
		# *)
		# 	echo ">>>>> Wrong argument given: ${1}"; Usage
		# 	;;
		*)
			shift 1
			;;
		esac
 	done

# Obligated fields

# Defaults
[ -z $command ] && command="bash"
}

##########################
# Main script
##########################
ReadParams "$@"


# Script to exec into pod.
POD_NAME=$(echo ${1} | sed -e 's/.*pod\///g')
FIRST_POD_MATCH=$(kubectl get all | grep pod/${POD_NAME} | grep -v Terminating | head -1 | sed -e 's/ .*//g')
# [ -z "${2}" ] && CMD="bash" || CMD="${2}"
# [ -z "${3}" ] && CONTAINER="" || CONTAINER="${3}"

[ ! -z $container ] && kubectl exec -it $FIRST_POD_MATCH -c $container -- "${command}" || kubectl exec -it $FIRST_POD_MATCH -- "${command}"