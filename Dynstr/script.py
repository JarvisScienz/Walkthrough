#!/usr/bin/python3


import requests

from requests.auth import HTTPBasicAuth


url = 'http://dyna.htb/nic/update'


res = requests.get(url, verify=False, auth=HTTPBasicAuth('dynadns', 'sndanyd'))

print (res.text)
