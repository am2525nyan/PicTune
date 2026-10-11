#!/usr/bin/env python3
"""Inventory first; --apply adds ownership metadata and removes public download tokens.
Uses the existing Firebase CLI credential without printing it. Backs up metadata to /tmp.
No image bytes or photo documents are changed or deleted.
"""
import argparse, datetime, json, pathlib, urllib.request, urllib.parse, urllib.error

PROJECT = 'sotugyou-7ea16'
BUCKET = PROJECT + '.appspot.com'
BASE = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    config = json.loads((pathlib.Path.home() / '.config/configstore/firebase-tools.json').read_text())
    token = config['tokens']['access_token']
    def request(url, method='GET', data=None):
        headers = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
        body = None if data is None else json.dumps(data).encode()
        with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers, method=method), timeout=60) as response:
            return json.load(response)
    def string(fields, key): return fields.get(key, {}).get('stringValue', '')
    rows = request(BASE + ':runQuery', 'POST', {'structuredQuery': {'from': [{'collectionId': 'photos', 'allDescendants': True}]}})
    owners = {}
    photo_count = 0
    for row in rows:
        doc = row.get('document')
        if not doc: continue
        path = doc['name'].split('/documents/')[1].split('/')
        if len(path) != 6 or path[0] != 'users' or path[2] != 'folders' or path[4] != 'photos': continue
        photo_count += 1
        uid = path[1]; fields = doc.get('fields', {})
        file = string(fields, 'url')
        if file and '/' not in file: owners.setdefault('images/' + file, set()).add(uid)
        live = string(fields, 'livephotoUrl')
        if '/o/' in live:
            name = urllib.parse.unquote(urllib.parse.urlsplit(live).path.split('/o/', 1)[1])
            if name.startswith('livephotos/'): owners.setdefault(name, set()).add(uid)
    objects = []; page = None
    while True:
        url = f'https://storage.googleapis.com/storage/v1/b/{BUCKET}/o?maxResults=1000'
        if page: url += '&pageToken=' + urllib.parse.quote(page)
        result = request(url); objects.extend(result.get('items', [])); page = result.get('nextPageToken')
        if not page: break
    summary = {'photoDocuments': photo_count, 'storageObjects': len(objects), 'referencedObjects': sum(o['name'] in owners for o in objects), 'mode': 'apply' if args.apply else 'inventory'}
    print(json.dumps(summary))
    if not args.apply: return
    backup = pathlib.Path('/tmp/pictune-image-access-backup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.json')
    backup.write_text(json.dumps(objects)); backup.chmod(0o600)
    registered = updated = 0
    for obj in objects:
        name = obj['name']; readers = sorted(owners.get(name, []))
        metadata = dict(obj.get('metadata', {}))
        if readers:
            metadata['ownerIDs'] = ','.join(readers)
        if name.startswith('images/'):
            file = name.split('/', 1)[1]
            registry_url = BASE + '/imageOwners/' + urllib.parse.quote(file, safe='')
            try:
                existing = request(registry_url)
            except urllib.error.HTTPError as e:
                if e.code != 404: raise
                existing = None
            if existing is None:
                request(registry_url, 'PATCH', {'fields': {'ownerID': {'stringValue': readers[0] if readers else '__unclaimed__'}, 'legacyReaders': {'arrayValue': {'values': [{'stringValue': uid} for uid in readers]}}}})
                registered += 1
        # A token URL bypasses Storage rules, so remove all old capabilities, including orphan objects.
        metadata['firebaseStorageDownloadTokens'] = None
        url = f'https://storage.googleapis.com/storage/v1/b/{BUCKET}/o/' + urllib.parse.quote(name, safe='') + '?ifMetagenerationMatch=' + obj['metageneration']
        request(url, 'PATCH', {'metadata': metadata}); updated += 1
        if updated % 50 == 0: print(json.dumps({'processedObjects': updated}), flush=True)
    print(json.dumps({'registeredImages': registered, 'updatedMetadata': updated, 'backup': str(backup)}))

if __name__ == '__main__': main()
