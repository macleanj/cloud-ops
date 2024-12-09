#!/bin/bash

# https://docs.ansible.com/ansible-tower/latest/html/towercli/reference.html

AAP_ORGANIZATION_NAME="euLISA-EES"
AAP_DEFAULT_ENVIRNOMENT_NAME="ansible-ee-ubi9-009"
AAP_GIT_URL="https://github.eulisa.local/EES/OCP_INSTALL.git"
# AAP_GIT_BRANCH="4.12fix"
AAP_GIT_BRANCH="feature/99999/jerome-test"
# AAP_GIT_BRANCH_CONFIG="ocp_inventories"
AAP_GIT_BRANCH_CONFIG="feature/99999/jerome-test"
AAP_INVENTORY_FILE="inventories/4.12/DEVTEST/asset-inventory"
AAP_CREDENTIALS_NAME_GIT="github_credentials"
AAP_CREDENTIALS_NAME_SSH="ansible_cees_rhel8_ssh_key"
AAP_CREDENTIALS_NAME_SECRET_STORE="xDev Thycotic Server"
AAP_PLAYBOOK="plays/post_check.yaml"

PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')

Usage()
{
  echo ""
  echo "Usage: $PROGRAM [option] name"
  echo ""
  echo "options:"
  echo "- create       : Create Ansible Automation Platform (AAP) testing environment"
  echo "- delete       : Delete Ansible Automation Platform (AAP) testing environment"
  echo ""
  echo "Resources will be created or deleted with the folling naming convention: <name> Testing"
  exit 5
}

[ -z $2 ] && echo "Missing argument" && Usage
AAP_PROJECT_NAME="$2 Testing"


case "$1" in
  create)
    echo "Creating AAP environment $AAP_PROJECT_NAME"
    option=$1
  ;;
  delete)
    echo "Deleting AAP environment $AAP_PROJECT_NAME"
    option=$1
  ;;
  *)
    echo "Option given not valid"
    Usage
    exit 1
  ;;
esac

AAP_ORGANIZATION_ID=$(awx -k organizations get "$AAP_ORGANIZATION_NAME" | jq -r '.id')
AAP_DEFAULT_ENVIRNOMENT_ID=$(awx -k execution_environments get "$AAP_DEFAULT_ENVIRNOMENT_NAME" | jq -r '.id')

if [[ "$option" == "create" ]]; then
    #######################################
    # Create project for inventory
    #######################################
    output="$(awx -k projects get "$AAP_PROJECT_NAME Inventory" 2> /dev/null)"
    if [[ $? -eq 0 ]] ; then
        echo "Project '$AAP_PROJECT_NAME Inventory' already created. Skipping....."
    else
            AAP_CREDENTIALS_ID_GIT=$(awx -k credentials get "$AAP_CREDENTIALS_NAME_GIT" | jq -r '.id')
        awx -k projects create --wait \
            --name="$AAP_PROJECT_NAME Inventory" \
            --scm_type git --scm_url "$AAP_GIT_URL" --scm_branch "$AAP_GIT_BRANCH_CONFIG" \
            --credential "$AAP_CREDENTIALS_ID_GIT" \
            --organization "$AAP_ORGANIZATION_ID" --default_environment "$AAP_DEFAULT_ENVIRNOMENT_ID" \
            -f human
    fi

    output="$(awx -k inventory get "$AAP_PROJECT_NAME Inventory" 2> /dev/null)"
    if [[ $? -eq 0 ]] ; then
        echo "Inventory '$AAP_PROJECT_NAME Inventory' already created. Skipping....."
    else
        # Create
        awx -k inventory create \
            --name="$AAP_PROJECT_NAME Inventory" \
            --organization "$AAP_ORGANIZATION_ID" \
            -f human
    fi

    output="$(awx -k inventory_sources get "$AAP_PROJECT_NAME Inventory Source" 2> /dev/null)"
    if [[ $? -eq 0 ]] ; then
        echo "Inventory Source '$AAP_PROJECT_NAME Inventory Source' already created. Skipping....."
    else
        AAP_PROJECT_ID=$(awx -k project get "$AAP_PROJECT_NAME Inventory" | jq -r '.id')
        AAP_INVENTORY_ID=$(awx -k inventory get "$AAP_PROJECT_NAME Inventory" | jq -r '.id')
        awx -k inventory_sources create \
            --name="$AAP_PROJECT_NAME Inventory Source" --inventory "$AAP_INVENTORY_ID" \
            --organization "$AAP_ORGANIZATION_ID" --execution_environment "$AAP_DEFAULT_ENVIRNOMENT_NAME" \
            --source_project "$AAP_PROJECT_ID" --source scm --source_path "$AAP_INVENTORY_FILE" \
            --overwrite True --overwrite_vars True --update_on_launch True \
            -f human
    fi

    #######################################
    # Create project for executions
    #######################################
    output="$(awx -k projects get "$AAP_PROJECT_NAME" 2> /dev/null)"
    if [[ $? -eq 0 ]] ; then
        echo "Project '$AAP_PROJECT_NAME' already created. Skipping....."
    else
        AAP_CREDENTIALS_ID_GIT=$(awx -k credentials get "$AAP_CREDENTIALS_NAME_GIT" | jq -r '.id')
        awx -k projects create --wait \
            --name="$AAP_PROJECT_NAME" \
            --scm_type git --scm_url "$AAP_GIT_URL" --scm_branch "$AAP_GIT_BRANCH" \
            --credential "$AAP_CREDENTIALS_ID_GIT" \
            --organization "$AAP_ORGANIZATION_ID" --default_environment "$AAP_DEFAULT_ENVIRNOMENT_ID" \
            -f human
    fi

    output="$(awx -k job_templates get "$AAP_PROJECT_NAME Template" 2> /dev/null)"
    if [[ $? -eq 0 ]] ; then
        echo "Project '$AAP_PROJECT_NAME Template' already created. Skipping....."
    else
        AAP_PROJECT_ID=$(awx -k project get "$AAP_PROJECT_NAME" | jq -r '.id')
        awx -k job_templates create \
            --name="$AAP_PROJECT_NAME Template" --project "$AAP_PROJECT_ID" \
            --execution_environment "$AAP_DEFAULT_ENVIRNOMENT_ID" \
            --playbook "$AAP_PLAYBOOK" --inventory "$AAP_PROJECT_NAME Inventory" \
            --become_enabled True --allow_simultaneous True \
            -f human
        # Associate credentials
        awx -k job_templates associate \
            --credential "$AAP_CREDENTIALS_NAME_SSH" \
            "$AAP_PROJECT_NAME Template" \
            -f human
        awx -k job_templates associate \
            --credential "$AAP_CREDENTIALS_NAME_SECRET_STORE" \
            "$AAP_PROJECT_NAME Template" \
            -f human
    fi


elif [[ "$option" == "delete" ]]; then
    # # First the jobs need to be deleted
    awx -k jobs list --name "$AAP_PROJECT_NAME Template" | jq -r '.results[].id' | while read -r job
    do
        echo "HERE: $job"
        awx -k jobs delete "$job"
    done
    IFS=$OLDIFS

    echo "Deleting Job Template '$AAP_PROJECT_NAME Template'"
    awx -k job_templates delete "$AAP_PROJECT_NAME Template"

    echo "Deleting Project '$AAP_PROJECT_NAME'"
    awx -k project delete "$AAP_PROJECT_NAME"

    echo "Deleting Inventory Source '$AAP_PROJECT_NAME Inventory Source'"
    awx -k inventory_sources delete "$AAP_PROJECT_NAME Inventory Source"

    echo "Deleting Inventory '$AAP_PROJECT_NAME Inventory'"
    awx -k inventory delete "$AAP_PROJECT_NAME Inventory"

    echo "Deleting Project '$AAP_PROJECT_NAME Inventory'"
    awx -k project delete "$AAP_PROJECT_NAME Inventory"

    # https://access.redhat.com/solutions/7024486
    echo "Known issue: The inventory jobs do not cleanup nicely. Use a new name for next test of cleanup as follows:"
    echo "awx-manage shell_plus"
    echo ">>> Inventory.objects.filter(pending_deletion=True).update(pending_deletion=False)"
    echo ">>> Inventory.objects.filter(id=<inventoryId>).delete()"
else
    echo "Nothing to do"
    exit
fi

