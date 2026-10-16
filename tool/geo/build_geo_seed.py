#!/usr/bin/env python3
"""
Builds `assets/geo/kh_geo_seed_v1.json` — the bundled Cambodian administrative
gazetteer shipped with the app (docs/features/geo-location/README.md).

Two upstream sources are combined, because neither is complete on its own:

  1. The NCDD administrative hierarchy (province / district / commune / village)
     — authoritative for names and codes, but carries no postal code.
  2. Cambodia Post's commune-level postal codes — authoritative for postal
     codes, but numbered on its own district ordering, so its `code` field is
     NOT the NCDD commune id and must never be joined on.

The join is therefore by normalised name, scoped to a province, and it is
deliberately conservative: where a name is ambiguous or absent the postal code
is emitted as null rather than guessed. A missing postal code shows the rep an
"unavailable" hint they can type over; a wrong one is silently shipped to SAP.

Usage:  python3 tool/geo/build_geo_seed.py <src_dir> <out_file>
"""
import json, re, sys, unicodedata
from collections import defaultdict, Counter

# NCDD's English labels for the administrative unit are non-idiomatic
# ("Quarter" for សង្កាត់, "Section" for ខណ្ឌ). Cambodian addresses are written
# with the transliterated Khmer terms, and the UI labels the commune level
# "Commune / Sangkat", so normalise onto those.
UNIT_EN = {
    'ខេត្ត': 'Province', 'រាជធានី': 'Capital',
    'ស្រុក': 'District', 'ក្រុង': 'Municipality', 'ខណ្ឌ': 'Khan',
    'ឃុំ': 'Commune', 'សង្កាត់': 'Sangkat',
    'ភូមិ': 'Village',
}

def norm_km(s):
    s = unicodedata.normalize('NFC', s)
    s = re.sub(r'^(ឃុំ|សង្កាត់)\s*', '', s.strip())
    return re.sub(r'\s+', '', s)

def norm_en(s):
    s = s.lower()
    s = re.sub(r'\b(sangkat|commune|khum|quarter)\b', '', s)
    return re.sub(r'[^a-z0-9]', '', s)

def load(src, name):
    with open(f'{src}/{name}.json', encoding='utf-8') as f:
        return json.load(f)[name]

def build_postal_index(postal):
    """province -> {normalised name: code}, dropping any name that is ambiguous
    within its province so an ambiguous match can never resolve to a code."""
    km, en = defaultdict(dict), defaultdict(dict)
    km_dup, en_dup = defaultdict(Counter), defaultdict(Counter)
    for prov in postal:
        pid = f"{int(prov['id']):02d}"
        for d in prov['districts']:
            for c in d['codes']:
                k, e = norm_km(c['km']), norm_en(c['en'])
                km_dup[pid][k] += 1
                en_dup[pid][e] += 1
                km[pid].setdefault(k, c['code'])
                en[pid].setdefault(e, c['code'])
    for pid, cnt in km_dup.items():
        for n, c in cnt.items():
            if c > 1:
                km[pid].pop(n, None)
    for pid, cnt in en_dup.items():
        for n, c in cnt.items():
            if c > 1:
                en[pid].pop(n, None)
    return km, en

def main(src, out):
    provinces = load(src, 'province')
    districts = load(src, 'district')
    communes  = load(src, 'commune')
    villages  = load(src, 'village')
    postal    = json.load(open(f'{src}/postal.json', encoding='utf-8'))

    pk, pe = build_postal_index(postal)

    # Drop any NCDD commune name that is itself ambiguous within its province:
    # two same-named communes cannot be told apart by a name join.
    ncdd_dup = defaultdict(Counter)
    for c in communes:
        ncdd_dup[c['province_id']][norm_km(c['name_km'])] += 1

    matched = 0
    def postal_for(c):
        nonlocal matched
        pid = c['province_id']
        if ncdd_dup[pid][norm_km(c['name_km'])] > 1:
            return None
        code = pk[pid].get(norm_km(c['name_km'])) or pe[pid].get(norm_en(c['name_en']))
        if code:
            matched += 1
        return code

    def unit(x):
        return UNIT_EN.get(x['administrative_unit']['name_km'],
                           x['administrative_unit']['name_en'])

    doc = {
        'version': 1,
        'generatedFrom': 'NCDD administrative gazetteer + Cambodia Post commune postal codes',
        'counts': {},
        'provinces': [
            {'c': p['id'], 'en': p['name_en'], 'km': p['name_km'], 'u': unit(p)}
            for p in sorted(provinces, key=lambda x: x['id'])
        ],
        'districts': [
            {'c': d['id'], 'p': d['province_id'], 'en': d['name_en'],
             'km': d['name_km'], 'u': unit(d)}
            for d in sorted(districts, key=lambda x: x['id'])
        ],
        'communes': [
            {'c': c['id'], 'p': c['district_id'], 'en': c['name_en'],
             'km': c['name_km'], 'u': unit(c), 'z': postal_for(c)}
            for c in sorted(communes, key=lambda x: x['id'])
        ],
        'villages': [
            {'c': v['id'], 'p': v['commune_id'], 'en': v['name_en'], 'km': v['name_km']}
            for v in sorted(villages, key=lambda x: x['id'])
        ],
    }
    doc['counts'] = {
        'provinces': len(doc['provinces']), 'districts': len(doc['districts']),
        'communes': len(doc['communes']), 'villages': len(doc['villages']),
        'communesWithPostalCode': matched,
    }
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))
    pct = matched / len(communes) * 100
    print(f"provinces={len(doc['provinces'])} districts={len(doc['districts'])} "
          f"communes={len(doc['communes'])} villages={len(doc['villages'])}")
    print(f"postal codes resolved: {matched}/{len(communes)} ({pct:.1f}%)")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
