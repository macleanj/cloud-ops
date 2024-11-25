#!/usr/bin/env python3
import stat
import sys
import os
import argparse
import subprocess
import pprint
import inquirer
from inquirer.themes import GreenPassion
import yaml
import git
pp = pprint.PrettyPrinter(indent=2)
local_repo_root_dir = git.Repo(os.path.realpath(
    __file__), search_parent_directories=True).working_tree_dir

parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter, allow_abbrev=False, description='''
This is a script to quickly verify the upgrade or rollout of new OCP and/or operators.

''', usage='use "%(prog)s --help" for more information')
parser.add_argument('--input',           help='Select an alternative config file',
                    default='')
parser.add_argument('--debug',           help='Enable debugging',
                    action='store_true', default=False)
args = parser.parse_args()

# Program defaults
program_name = os.path.basename(__file__)
program_dir = os.path.dirname(os.path.abspath(os.path.realpath(__file__)))
base_name = os.path.splitext(program_name)[0]
current_dir = os.getcwd()
os.chdir(program_dir)

def get_config_object(config_file):
    # Prepare object for consumption
    # config_file = os.path.join(current_dir, args.input) if args.input != '' else os.path.join(
    #     program_dir, f'{base_name}.config.yml')
    try:
        with open(config_file, 'r', encoding="UTF-8") as stream:
            config_object = yaml.safe_load(stream)
    except:
        print(config_file + ' is not a valid YAML file')
        sys.exit(1)
    if args.debug:
        print(yaml.dump(config_object, indent=2, sort_keys=False))
    return config_object

config_object = get_config_object(os.path.join(current_dir, args.input) if args.input != '' else os.path.join(program_dir, f'{base_name}.config.yml'))

def current_cluster_name():
    return subprocess.run('oc cluster-info | grep "Kubernetes control plane" | sed -e "s|.*api.\\([^.]*\\)..*|\\1|"', shell=True, capture_output=True).stdout.decode("utf-8").strip()

def current_cluster_type():
    # acm only present on MGT cluster
    mgt = subprocess.run('oc get sub -A | grep advanced-cluster-management | wc -l', shell=True, capture_output=True).stdout.decode("utf-8").strip()
    # evt only present on CS cluster
    cs = subprocess.run('oc get sub -A | grep ibm-eventstreams-subscription | wc -l', shell=True, capture_output=True).stdout.decode("utf-8").strip()
    nui = 0 # TBD
    if int(mgt):
        return 'mgt'
    elif int(cs):
        return 'cs'
    elif int(nui):
        return 'nui'
    else:
        return 'unknown'

questions = [
    inquirer.List(
        'choice',
        message='Make your choice?',
        choices=list(config_object['operator'].keys()) + ['all'] + ['help']
    )
]
choice = inquirer.prompt(questions, theme=GreenPassion())['choice']

if choice == 'help':
    with subprocess.Popen(f'{os.path.realpath(__file__)} --help', shell=True) as proc:
        sys.exit(0)

operators = list(
    config_object['operator'].keys()) if choice == 'all' else [choice]

command_path = os.path.join(program_dir, config_object['general']['command_dir'])
for operator in operators:
    current_cluster_name = current_cluster_name()
    current_cluster_type = current_cluster_type()
    cluster_types_deployed_on = config_object['operator'][operator]['cluster_types_deployed_on']
    if current_cluster_type in cluster_types_deployed_on:
        name = config_object['operator'][operator]['name']
        name_short = config_object['operator'][operator]['name_short']
        namespace = config_object['operator'][operator]['namespace']
        pod_namespaces = config_object['operator'][operator]['pod_namespaces']
        print('\n--------------------------------------------------------------------------------------------')
        print(f'Verifying operator: {operator}')
        print('--------------------------------------------------------------------------------------------')
        # General
        for command in config_object['general']['commands']:
            command = os.path.join(command_path, command)

            result = subprocess.run(f'{command} {name} {namespace} "{pod_namespaces}"', shell=True, capture_output=True)
            print(result.stdout.decode("utf-8").strip())
            if result.returncode != 0: exit(result.returncode)

        # Specific
        if name_short == 'acm': 
            config_object_operator = get_config_object(os.path.join(command_path, f'{base_name}-operator-{name_short}.config.{current_cluster_name}.yml'))
            managed_clusters = config_object_operator['managed_clusters']
            for command in config_object['operator'][operator]['commands']:
                command = os.path.join(command_path, command)

                result = subprocess.run(f'{command} {name} "{managed_clusters}"', shell=True, capture_output=True)
                print(result.stdout.decode("utf-8").strip())
                if result.returncode != 0: exit(result.returncode)
        print('--------------------------------------------------------------------------------------------\n')
