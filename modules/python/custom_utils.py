import yaml
from datetime import timedelta

def get_dict_from_yaml(file):
  with open(file) as stream:
    return yaml.safe_load(stream)

def get_nested_value(d, keys, default=''):
  try:
    for k in keys:
      d = d[k]
  except KeyError:
    return default
  else:
    return d

def get_expire_times(args, now):
  # start_of_month is valid for 2 months, however the configuration will updated after 1 month when the platform is deployed. This gives an overlap of 1 month.
  start_of_month    = now.replace(second=0,minute=0,hour=0,day=1)
  start_of_month_8w = start_of_month + timedelta(weeks=8)
  start_of_month_2m = start_of_month.replace(month=start_of_month.month + 2)

  # start_of_year is valid for 2 years, however the configuration will updated after 1 year when the platform is deployed. This gives an overlap of 1 year.
  start_of_year     = now.replace(second=0,minute=0,hour=0,day=1,month=1)
  start_of_year_2y  = start_of_year.replace(year=start_of_year.year + 2)

  # prepare in Terraform expected format
  expire_times = {}
  expire_times['start_of_month']    = start_of_month.strftime('%Y-%m-%dT%H:%M:%SZ')
  expire_times['start_of_month_8w'] = start_of_month_8w.strftime('%Y-%m-%dT%H:%M:%SZ')
  expire_times['start_of_month_2m'] = start_of_month_2m.strftime('%Y-%m-%dT%H:%M:%SZ')
  expire_times['start_of_year']     = start_of_year.strftime('%Y-%m-%dT%H:%M:%SZ')
  expire_times['start_of_year_2y']  = start_of_year_2y.strftime('%Y-%m-%dT%H:%M:%SZ')

  return expire_times
