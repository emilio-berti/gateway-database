import pandas as pd
import re
import requests
from itertools import compress

"""
Harmonize GATEWAy taxonomy against GBIF

This script works only if the first species in the list is found.
This is the case here and I didn't program exceptions to this.
"""

def error(err = ""):
   print("\033[0;39;31m " + err + "\033[0;49;39m")

def warning(warn = ""):
    print("\033[0;32;33m " + warn + "\033[0;49;39m")

def message(mssg = None):
    print("\033[0;32;34m " + mssg + "\033[0;49;39m")

def not_found(x):
  ans = pd.DataFrame({
          'original': x,
          'gbif': None, 
          'rank': None,
          'key': None,
          'status': None,
          'match': None
        }, index = [sp.index(x)])
  return ans

def parse(x):
  try:
    r = requests.get(api_parser.format(x))
  except:
    r = None
  if r is None or r.status_code != 200:
    error('        Request error')
    ans = None
  else:
    ans = r.json()[0]
  if 'canonicalName' in ans.keys():
    ans = ans['canonicalName']
  else:
    ans = None
  return ans

def match(x):
  try:
    r = requests.get(api_matcher.format(x))
  except:
    r = None
  if r is None or r.status_code != 200:
    ans = None
  else:
    ans = r.json()
  if ans is None or 'canonicalName' not in ans.keys():
    ans = None
  return ans

def fuzzy(x):
  try:
    r = requests.get(api_fuzzy.format(x))
  except:
    r = None
  if r is None or r.status_code != 200:
    ans = None
  else:
    ans = r.json()
    if isinstance(ans, list):
      ans = ans[0]
  if ans is None or 'canonicalName' not in ans.keys():
    ans = None
  return ans

def status_key(x):
  if 'status' in x.keys() and x['status'] == 'ACCEPTED':
    if x['rank'] == 'SPECIES':
      key = x['speciesKey']
    elif x['rank'] == 'GENUS':
      key = x['genusKey']
    elif x['rank'] == 'FAMILY':
      key = x['familyKey']
    elif x['rank'] == 'ORDER':
      key = x['orderKey']
    elif x['rank'] == 'phylum':
      key = x['phylumKey']
    else:
      key = None
    return key

data_dir = 'data/'
d = pd.read_csv(data_dir + 'checklist.csv')
sp = [x for x in d.species]
sp = set(sp)
original = [x for x in sp] # to merge taxonomies later on
sp = [x.replace('Order ', '') for x in sp]
sp = [x.replace('Family ', '') for x in sp]
sp = [x.replace('Order ', '') for x in sp]
# remove taxonomic rank names
for i in range(len(sp)):
  x = sp[i]
  regex = re.match('class |order |family |genus ', x, re.IGNORECASE)
  if regex is None:
    continue
  else:
    sp[i] = re.sub('class |order |family |genus ', '', x, flags = re.IGNORECASE)

sp = [x.capitalize() for x in sp]

api_parser = 'https://api.gbif.org/v1/parser/name?name={}'
api_matcher = 'https://api.gbif.org/v1/species/match?name={}&strict=true'
api_fuzzy = 'https://api.gbif.org/v1/species/match?name={}&strict=false'

j = 0
message('   - parsing GBIF...')
for x in sp:
  j += 1
  if j % 500 == 0:
    message('        species {} of {}'.format(j, len(sp)))
  # parse it to get canonical names (binomial)
  parsed = parse(x)
  if parsed is None:
    error('        Parsing error')
    add = not_found(x)
    res = pd.concat([res, add])
    continue
  # exact match
  matched = match(x)
  if matched is not None:
    key = status_key(matched)
    add = pd.DataFrame({
      'original': original[sp.index(x)],
      'gbif': matched['canonicalName'], 
      'rank': matched['rank'].lower(),
      'key': key,
      'status': matched['status'].lower(),
      'match': 'exact'
    }, index = [sp.index(x)])
    if sp.index(x) == 0:
      res = add
    else:
      res = pd.concat([res, add])
    continue
  # fuzzy match
  matched = fuzzy(x)
  if matched is None:
    add = not_found(x)
    res = pd.concat([res, add])
  else:
    key = status_key(matched)
    add = pd.DataFrame({
      'original': original[sp.index(x)],
      'gbif': matched['canonicalName'], 
      'rank': matched['rank'].lower(),
      'key': key,
      'status': matched['status'].lower(),
      'match': 'fuzzy'
    }, index = [sp.index(x)])
    if sp.index(x) == 0:
      res = add
    else:
      res = pd.concat([res, add])

res.to_csv(data_dir + 'taxonomy.csv')