#!/bin/bash

oc get subs -A -o json | jq -r '["NAMESPACE","NAME","VERSION","CHANNEL"], ["--------------------------------------------","--------------------------------------------","-----------","-----------"], (.items[] | [.metadata.namespace, .metadata.name, (.status | if has("currentCSV") then (.currentCSV | capture("[^.]+.(?<newkey>.*)").newkey) else "NA" end), .spec.channel]) | @tsv' | column -t
