#!/usr/bin/env python3

import os
import argparse
import pprint; pp = pprint.PrettyPrinter(indent=2)
import sys
import yaml
import time
import git
local_repo_root_dir = git.Repo(os.path.realpath(__file__), search_parent_directories=True).working_tree_dir

from sshtunnel import SSHTunnelForwarder
import requests

# Local modules
sys.path.append(os.path.realpath(os.path.join(os.path.dirname(__file__), local_repo_root_dir, 'modules', 'python')))
import custom_utils

parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter, allow_abbrev=False, description='''
Script to tunnel predefined connections. Connection assumes public key access to be in place.

Examples:
- %(prog)s --env enva

''', usage='use "%(prog)s --help" for more information')
option = parser.add_mutually_exclusive_group(required=True)
option.add_argument('--env',             help='Environment to setup portfowrding for. E.g. b01')
option.add_argument('--group',           help='Predefined group to setup portfowrding for. E.g. kubernetes')
parser.add_argument('--config',          help='environment to connect to', default="dev")
parser.add_argument('--remote_user',     help='User to connect to the jumphost')
parser.add_argument('--ssh_private_key', help='Private SSH key to be used to connect to the jumphost')
parser.add_argument('--remote_host',     help='Jumphost hostname')
parser.add_argument('--remote_port',     help='Jumphost port')
parser.add_argument('--local_host',      help='Localhost', default='127.0.0.1')
parser.add_argument('--local_port',      help='Local port')
parser.add_argument('--private_host',    help='Desitination hostname to tunnel to')
parser.add_argument('--private_port',    help='Desitination port to tunnel to')
parser.add_argument('--debug',           help='Enable debugging', action='store_true', default=False)
args = parser.parse_args()

# Program defaults
program_name = os.path.basename(__file__)
program_dir = os.path.dirname(os.path.abspath(os.path.realpath(__file__)))
base_name = os.path.splitext(program_name)[0]
current_dir = os.getcwd()
os.chdir(program_dir)

# Prepare object for consumption
config_flag = args.config
config_file = os.path.join(program_dir, 'ssh_portforward_config_{0}.yml'.format(config_flag))
try:
  config_object = yaml.safe_load(open(config_file, 'r'))
except:
  print(config_file + ' is not a valid JSON file')
  sys.exit(1)
if args.debug: print(yaml.dump(config_object, indent=2, sort_keys=False))

remote_user = custom_utils.get_nested_value(config_object, ['jumphost','user']) if not args.remote_user else args.remote_user
ssh_private_key = custom_utils.get_nested_value(config_object, ['jumphost','ssh_private_key']) if not args.ssh_private_key else args.ssh_private_key
remote_host = custom_utils.get_nested_value(config_object, ['jumphost','remote_host']) if not args.remote_host else args.remote_host
remote_port = custom_utils.get_nested_value(config_object, ['jumphost','remote_port']) if not args.remote_port else args.remote_port
local_host = args.local_host
remote_bind_addresses = []
local_bind_addresses = []

def tunnel_traffic(remote_bind_addresses,local_bind_addresses):
  try:
      with SSHTunnelForwarder(
          (remote_host, remote_port),
          ssh_username=remote_user,
          ssh_private_key=ssh_private_key,
          remote_bind_addresses=remote_bind_addresses,
          local_bind_addresses=local_bind_addresses
          ) as server:

          server.start()
          print('\nConnected')

          print('All tunnels are up and running.....')
          while True:
              time.sleep(1)

  except Exception as e:
      print(str(e))

def append_tunnels(remote_bind_addresses,local_bind_addresses):
  for key, value in config_object.items():
    if key != 'always': continue

    for group, group_value in value.items():
      for entry in group_value:
        remote_bind_address = (entry['private_host'], entry['private_port'])
        local_bind_address =  (local_host, entry['local_port'])
        remote_bind_addresses.append(remote_bind_address)
        local_bind_addresses.append(local_bind_address)

  print('Hosts used (to be added to /etc/hosts):')
  for entry in remote_bind_addresses:
    private_host, private_port = entry
    print('127.0.0.1       {0} # port: {1}'.format(private_host, private_port))

  tunnel_traffic(remote_bind_addresses,local_bind_addresses)

##############################################################################################################
# Main
##############################################################################################################


if args.env:
  environment_short = args.env
  print('>>>>> Environment: {0}'.format(environment_short))

  try:
    for key in config_object[environment_short].items():
      for key, value in config_object[environment_short][key].items():

        for entry in value[group]:
          remote_bind_address = (entry['private_host'], entry['private_port'])
          local_bind_address =  (local_host, entry['local_port'])
          remote_bind_addresses.append(remote_bind_address)
          local_bind_addresses.append(local_bind_address)
    
    append_tunnels(remote_bind_addresses,local_bind_addresses)
  except Exception as e:
      print(str(e))
elif args.group:
  group = args.group
  print('>>>>> Group: {0}'.format(group))

  try:
    for key, value in config_object.items():
      if custom_utils.get_nested_value(value, [group], '') == '': continue

      for entry in value[group]:
        remote_bind_address = (entry['private_host'], entry['private_port'])
        local_bind_address =  (local_host, entry['local_port'])
        remote_bind_addresses.append(remote_bind_address)
        local_bind_addresses.append(local_bind_address)
    
    append_tunnels(remote_bind_addresses,local_bind_addresses)
  except Exception as e:
      print(str(e))
else:
  # https://stackoverflow.com/questions/60090438/how-to-use-python-sshtunnle-to-forward-multiple-ports
  # Kubernetes
  print('else')
  # local_host = config_object['generic'][destination]['local_host'] if not args.local_host else args.local_host
  # local_port = config_object[environment_short][destination]['local_port'] if not args.local_port else args.local_port
  # private_host = config_object[environment_short][destination]['private_host'] if not args.private_host else args.private_host
  # private_port = config_object['generic'][destination]['private_port'] if not args.private_port else args.private_port
  # tunnel_traffic(local_host,local_port,private_host,private_port)
