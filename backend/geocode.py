"""Destination search for trips.

The phone used to ask Apple's geocoder and then keep a hit only when the
locality prefix-matched the query. That drops Tokyo (a prefecture: the name
is not a locality) and Spagna (a country). It also biases "Spagna" toward
Piazza di Spagna in Rome when the device is in Italy.

Nominatim understands the Italian names. A country is then anchored on its
capital: Spain's geographic centre is empty countryside, and a search within
5 km of that point finds no places, so generating the trip fails.
"""
import os
import re
import threading
import time
import unicodedata

import httpx
from fastapi import HTTPException

UA = 'RoamTraveller/1.0 (destination search; https://github.com/robertolibanora/roam)'
WIKIDATA_SPARQL = 'https://query.wikidata.org/sparql'
_POINT = re.compile(r'Point\(\s*([+-]?\d+(?:\.\d+)?)\s+([+-]?\d+(?:\.\d+)?)\s*\)')
_QID = re.compile(r'Q\d+')
# Settlements and natural areas a trip can be planned around. Squares, shops
# and bars are not destinations (they are how "Spagna" collapses to Rome).
_PLACE_KINDS = {
    'city', 'town', 'village', 'hamlet', 'municipality', 'borough', 'suburb',
    'neighbourhood', 'quarter', 'locality', 'island', 'islet', 'archipelago',
    'county', 'state', 'province', 'region', 'city_district',
}
_pace = threading.Lock()
_last_nominatim = 0.0


def fold(text: str) -> str:
    text = unicodedata.normalize('NFKD', (text or '').casefold())
    return ''.join(c for c in text if not unicodedata.combining(c)).strip()


def _nominatim_base() -> str:
    return os.environ.get('NOMINATIM_URL', 'https://nominatim.openstreetmap.org').rstrip('/')


def _pace_nominatim():
    """Public Nominatim allows about one request per second."""
    global _last_nominatim
    with _pace:
        wait = 1.05 - (time.monotonic() - _last_nominatim)
        if wait > 0:
            time.sleep(wait)
        _last_nominatim = time.monotonic()


def search_nominatim(query: str) -> list[dict]:
    _pace_nominatim()
    try:
        with httpx.Client(timeout=httpx.Timeout(20, connect=5), headers={'User-Agent': UA, 'Accept-Language': 'it'}) as client:
            response = client.get(_nominatim_base() + '/search', params={
                'q': query, 'format': 'jsonv2', 'addressdetails': 1, 'extratags': 1,
                'limit': 6, 'accept-language': 'it',
            })
        if response.status_code == 429 or response.status_code >= 500:
            raise HTTPException(503, 'Ricerca destinazioni temporaneamente non disponibile. Riprova tra poco.')
        response.raise_for_status()
        data = response.json()
    except HTTPException:
        raise
    except (httpx.HTTPError, ValueError, TypeError):
        raise HTTPException(503, 'Ricerca destinazioni temporaneamente non disponibile. Riprova tra poco.')
    if not isinstance(data, list):
        raise HTTPException(502, 'Risposta del geocoder non valida.')
    return [row for row in data if isinstance(row, dict)]


def is_destination(result: dict) -> bool:
    kind = (result.get('addresstype') or result.get('type') or '').lower()
    category = (result.get('class') or result.get('category') or '').lower()
    if category == 'boundary':
        return True
    if category == 'place' and kind in _PLACE_KINDS:
        return True
    return category == 'natural' and kind in {'island', 'archipelago', 'islet', 'peninsula'}


def choose(results: list[dict], query: str) -> dict | None:
    """Prefer the place Nominatim actually meant, not a namesake POI."""
    wanted = fold(query)
    ranked = []
    for result in results:
        if not is_destination(result):
            continue
        address = result.get('address') or {}
        name = fold(result.get('name') or '')
        kind = (result.get('addresstype') or result.get('type') or '').lower()
        exact = wanted in {name, fold(address.get('country') or ''), fold(address.get('city') or ''), fold(address.get('town') or ''), fold(address.get('state') or '')}
        score = float(result.get('importance') or 0)
        if exact:
            score += 3
        if kind == 'country' and exact:
            score += 2
        if kind in {'city', 'town', 'municipality'} and name == wanted:
            score += 1
        ranked.append((score, result))
    if not ranked:
        return None
    score, result = max(ranked, key=lambda item: item[0])
    name = fold(result.get('name') or '')
    # An obscure boundary that does not even contain the query is not a match.
    # "Tokio" still matches Tokyo: Nominatim returns it with high importance.
    if score < 0.4 and wanted != name and wanted not in name.split():
        return None
    return result


def capital_from_bindings(bindings) -> dict | None:
    if not isinstance(bindings, list):
        return None
    for row in bindings:
        if not isinstance(row, dict):
            continue
        label = (row.get('itemLabel') or {}).get('value')
        match = _POINT.search((row.get('coord') or {}).get('value') or '')
        if not label or label.startswith('Q') or not match:
            continue
        longitude, latitude = float(match.group(1)), float(match.group(2))
        if -90 <= latitude <= 90 and -180 <= longitude <= 180:
            return {'name': label, 'latitude': latitude, 'longitude': longitude}
    return None


def capital_of(wikidata_id: str) -> dict | None:
    if not _QID.fullmatch(wikidata_id or ''):
        return None
    sparql = (
        'SELECT ?itemLabel ?coord WHERE { '
        f'wd:{wikidata_id} wdt:P36 ?item . ?item wdt:P625 ?coord . '
        'SERVICE wikibase:label { bd:serviceParam wikibase:language "it,en". } }'
    )
    try:
        with httpx.Client(timeout=httpx.Timeout(20, connect=5), headers={'User-Agent': UA, 'Accept': 'application/sparql-results+json'}) as client:
            response = client.get(WIKIDATA_SPARQL, params={'query': sparql, 'format': 'json'})
        if response.status_code != 200:
            return None
        bindings = response.json().get('results', {}).get('bindings', [])
    except (httpx.HTTPError, ValueError, TypeError, AttributeError):
        return None
    return capital_from_bindings(bindings)


def _text(value) -> str | None:
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def present(result: dict, capital: dict | None) -> dict:
    address = result.get('address') or {}
    kind = (result.get('addresstype') or result.get('type') or 'place').lower()
    name = _text(result.get('name')) or _text(address.get('country')) or _text(address.get('city'))
    if not name:
        raise HTTPException(502, 'Risposta del geocoder non valida.')
    try:
        latitude, longitude = float(result['lat']), float(result['lon'])
    except (KeyError, TypeError, ValueError):
        raise HTTPException(502, 'Risposta del geocoder non valida.')
    region = _text(address.get('state')) or _text(address.get('region')) or _text(address.get('county'))
    country = _text(address.get('country'))
    if kind == 'country':
        if not capital:
            # Do not plan a trip around empty countryside at the country's centroid.
            raise HTTPException(503, f'Non riesco a trovare una città da cui partire per {name}. Riprova tra poco.')
        latitude, longitude = capital['latitude'], capital['longitude']
        region = capital['name']
        country = name
    if region and fold(region) == fold(name):
        region = None
    return {'name': name, 'region': region, 'country': country, 'latitude': latitude, 'longitude': longitude, 'kind': kind}


def resolve(query: str) -> dict:
    query = ' '.join((query or '').split())
    if not 2 <= len(query) <= 120:
        raise HTTPException(422, 'Scrivi almeno due lettere della destinazione')
    chosen = choose(search_nominatim(query), query)
    if not chosen:
        raise HTTPException(404, f'Nessuna destinazione trovata per “{query}”.')
    kind = (chosen.get('addresstype') or chosen.get('type') or '').lower()
    capital = None
    if kind == 'country':
        capital = capital_of((chosen.get('extratags') or {}).get('wikidata') or '')
    return present(chosen, capital)
