# NOT FINISHED. REF ONLY.
# from kubernetes import client, config
import math
import math

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning) # Ignore unsecure certificate warning

config.load_kube_config()
k8s_api = client.CoreV1Api()
k8s_api_custom = client.CustomObjectsApi()

def convert_size_to_bytes(size_str):
    multipliers = {
        'kilobyte':  1024,
        'megabyte':  1024 ** 2,
        'gigabyte':  1024 ** 3,
        'terabyte':  1024 ** 4,
        'petabyte':  1024 ** 5,
        'exabyte':   1024 ** 6,
        'zetabyte':  1024 ** 7,
        'yottabyte': 1024 ** 8,
        'kb': 1024,
        'mb': 1024 ** 2,
        'gb': 1024 ** 3,
        'tb': 1024 ** 4,
        'pb': 1024 ** 5,
        'eb': 1024 ** 6,
        'zb': 1024 ** 7,
        'yb': 1024 ** 8,
        # Kubernetes memory
        'ki': 1024,
        'mi': 1024 ** 2,
        'gi': 1024 ** 3,
        'ti': 1024 ** 4,
        'pi': 1024 ** 5,
        'ei': 1024 ** 6,
        'zi': 1024 ** 7,
        'yi': 1024 ** 8,
        # Kubernetes cpu
        'm':  1/1000, # mili
    }

    for suffix in multipliers:
        size_str = size_str.lower().strip().strip('s')
        # if size_str.lower().endswith('m'):
        #     print(suffix)
        #     print(size_str[0:-len(suffix)])
        #     return size_str[0:-len(suffix)] * multipliers[suffix]
        if size_str.lower().endswith(suffix):
            if suffix == 'm':
                return int(size_str[0:-len(suffix)]) * multipliers[suffix]
            else:
                return int(float(size_str[0:-len(suffix)]) * multipliers[suffix])
        else:
            if size_str.endswith('b'):
                return int(size_str[0:-1])
            elif size_str.endswith('byte'):
                return int(size_str[0:-4])

    return size_str


def convert_memory_size(memory_size_bytes_string):
   memory_size_bytes = int(convert_size_to_bytes(memory_size_bytes_string))
   memory_size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
   i = int(math.floor(math.log(memory_size_bytes, 1024)))
   p = math.pow(1024, i)
   s = round(memory_size_bytes / p, 2)
   return "%s%s" % (s, memory_size_name[i])

def convert_cpu_size(cpu_size_string):
   cpu_size = int(convert_size_to_bytes(cpu_size_string) * 1000)
   cpu_size_name = ("m", "")
   i = int(math.floor(math.log(cpu_size, 1000)))
   p = math.pow(1000, i)
   s = round(cpu_size / p, 2)
   return "%s%s" % (s, cpu_size_name[i])


# v1 = client.CoreV1Api()

# pods = v1.list_pod_for_all_namespaces().items
# # Get the CPU and memory limits for each pod
# for pod in pods:
#     print(f'Pod name: {pod.metadata.name}')
#     for container in pod.spec.containers:
#         print(f'\tContainer name: {container.name}')
#         if container.resources.limits:
#             if 'cpu' in container.resources.limits:
#                 print(f'\tCPU limit: {container.resources.limits["cpu"]}')
#             else:
#                 print("\tNo cpu resource limits defined")
#             if 'memory' in container.resources.limits:
#                 print(f'\tMemory limit: {container.resources.limits["memory"]}')
#             else:
#                 print("\tNo memory resource limits defined")
#         else:
#            print("\tNo resource limits defined")


print("Getting k8s nodes...")
k8s_nodes = {}
k8s_nodes_allocatable = k8s_api.list_node()
for node in k8s_nodes_allocatable.items:
    node_name = node.metadata.name
    k8s_nodes[node_name] = {}
    k8s_nodes[node_name]['allocatable'] = {}
    k8s_nodes[node_name]['allocatable']['cpu'] = convert_size_to_bytes(node.status.allocatable['cpu'])
    k8s_nodes[node_name]['allocatable']['cpu_string'] = convert_cpu_size(node.status.allocatable['cpu'])
    k8s_nodes[node_name]['allocatable']['memory'] = convert_size_to_bytes(node.status.allocatable['memory'])
    k8s_nodes[node_name]['allocatable']['memory_string'] = convert_memory_size(node.status.allocatable['memory'])

# k8s_nodes = dict(sorted(k8s_nodes.items(), key=lambda item: item[1]['allocatable']["memory"], reverse=True))

# for key, value in k8s_nodes.items():
#     print("%s\t\tCPU: %s\tMemory: %s" % (key, value['allocatable']['cpu_string'], value['allocatable']['memory_string']))



# k8s_nodes = {} #
k8s_nodes_usage = k8s_api_custom.list_cluster_custom_object("metrics.k8s.io", "v1beta1", "nodes")
for node in k8s_nodes_usage['items']:
    node_name = node['metadata']['name']
    # k8s_nodes[node_name] = {} #
    k8s_nodes[node_name]['usage'] = {}
    k8s_nodes[node_name]['usage']['cpu'] = convert_size_to_bytes(node['usage']['cpu'])
    k8s_nodes[node_name]['usage']['cpu_string'] = convert_cpu_size(node['usage']['cpu'])
    k8s_nodes[node_name]['usage']['cpu_percentage'] = int(k8s_nodes[node_name]['usage']['cpu'] / k8s_nodes[node_name]['allocatable']['cpu'] * 100)
    k8s_nodes[node_name]['usage']['memory'] = convert_size_to_bytes(node['usage']['memory'])
    k8s_nodes[node_name]['usage']['memory_string'] = convert_memory_size(node['usage']['memory'])
    k8s_nodes[node_name]['usage']['memory_percentage'] = int(k8s_nodes[node_name]['usage']['memory'] / k8s_nodes[node_name]['allocatable']['memory'] * 100)

k8s_nodes = dict(sorted(k8s_nodes.items(), key=lambda item: item[1]['usage']["cpu"], reverse=True))

blank=''
# print("Name\t\t\tCPU %\tCPU(u/a)\t\tMemory %\tMemory (u/a)")
print(f'Name{blank:<25}CPU %{blank:<10}CPU(u/a){blank:<10}Memory %{blank:<10}Memory (u/a)')
for key, value in k8s_nodes.items():    
    # print('%s{: >20}%s%%\t%s/%s\t%s%%\t%s/%s' % (key, value['usage']['cpu_percentage'], value['usage']['cpu_string'], value['allocatable']['cpu_string'], value['usage']['memory_percentage'], value['usage']['memory_string'], value['allocatable']['memory_string']))
    # print('{0:>20.2f}'.format(key, value['usage']['cpu_percentage'], value['usage']['cpu_string'], value['allocatable']['cpu_string'], value['usage']['memory_percentage'], value['usage']['memory_string'], value['allocatable']['memory_string']))
    print(f'{key:<25} {value['usage']['cpu_percentage']}%{blank:<10} {value['usage']['cpu_string']}/{value['allocatable']['cpu_string']:<10} {value['usage']['memory_percentage']:<10} {value['usage']['memory_string']}/{value['allocatable']['memory_string']:<10}')
    # print(f'{key :<50} {key :<10} {key :<10}')
