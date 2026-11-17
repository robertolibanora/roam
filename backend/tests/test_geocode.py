"""Destination search: Tokyo is a prefecture, Spagna is a country.

The country's own coordinate is countryside. Planning a trip there finds no
places, so a country is anchored on its capital instead.
"""
from test_api import client
import geocode

TOKYO = dict(name='Tokyo', **{'class': 'boundary'}, type='administrative', addresstype='province',
             lat='35.6768601', lon='139.7638947', importance=0.8337626616070368,
             address=dict(country='Giappone', country_code='jp'), extratags=dict(wikidata='Q1490'))
SPAIN = dict(name='Spagna', **{'class': 'boundary'}, type='administrative', addresstype='country',
             lat='39.3260685', lon='-4.8379791', importance=0.9295913704622313,
             address=dict(country='Spagna', country_code='es'), extratags=dict(wikidata='Q29'))
PIAZZA = dict(name='Piazza di Spagna', **{'class': 'place'}, type='square', addresstype='square',
              lat='41.9057', lon='12.4823', importance=0.55,
              address=dict(country='Italia', city='Roma', country_code='it'))
MADRID = dict(name='Madrid', latitude=40.416944444, longitude=-3.703333333)


def test_spain_is_not_a_roman_square_and_not_the_empty_centroid(monkeypatch):
    monkeypatch.setattr(geocode, 'search_nominatim', lambda query: [PIAZZA, SPAIN])
    monkeypatch.setattr(geocode, 'capital_of', lambda qid: MADRID if qid == 'Q29' else None)
    response = client.get('/geocode', params={'q': 'Spagna'})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body['name'] == 'Spagna' and body['country'] == 'Spagna' and body['region'] == 'Madrid'
    assert body['kind'] == 'country'
    assert abs(body['latitude'] - MADRID['latitude']) < 1e-6
    assert abs(body['longitude'] - MADRID['longitude']) < 1e-6
    # The geographic centre of Spain (returned by the geocoder) has no places nearby.
    assert abs(body['latitude'] - 39.3260685) > 0.5


def test_tokyo_keeps_the_city_centre_and_accepts_the_italian_spelling(monkeypatch):
    def no_capital(qid):
        raise AssertionError('Tokyo is not a country; its coordinate is already downtown')
    monkeypatch.setattr(geocode, 'search_nominatim', lambda query: [TOKYO])
    monkeypatch.setattr(geocode, 'capital_of', no_capital)
    for query in ('Tokyo', 'tokio', 'Tōkyō'):
        response = client.get('/geocode', params={'q': query})
        assert response.status_code == 200, response.text
        body = response.json()
        assert body['name'] == 'Tokyo' and body['country'] == 'Giappone' and body['kind'] == 'province'
        assert abs(body['latitude'] - 35.6768601) < 1e-6
        assert abs(body['longitude'] - 139.7638947) < 1e-6


def test_country_without_a_capital_is_not_planned_from_the_countryside(monkeypatch):
    monkeypatch.setattr(geocode, 'search_nominatim', lambda query: [SPAIN])
    monkeypatch.setattr(geocode, 'capital_of', lambda qid: None)
    response = client.get('/geocode', params={'q': 'Spagna'})
    assert response.status_code == 503
    assert 'lat' not in response.text


def test_unknown_place_and_validation(monkeypatch):
    monkeypatch.setattr(geocode, 'search_nominatim', lambda query: [])
    assert client.get('/geocode', params={'q': 'zzzzqqqq'}).status_code == 404
    assert client.get('/geocode', params={'q': 'a'}).status_code == 422


def test_geocoder_outage_is_reported(monkeypatch):
    def down(query):
        from fastapi import HTTPException
        raise HTTPException(503, 'Ricerca destinazioni temporaneamente non disponibile. Riprova tra poco.')
    monkeypatch.setattr(geocode, 'search_nominatim', down)
    response = client.get('/geocode', params={'q': 'Tokyo'})
    assert response.status_code == 503
    assert 'non disponibile' in response.json()['detail']


def test_capital_coordinate_parsing():
    assert geocode.capital_from_bindings([{
        'coord': {'value': 'Point(-3.703333333 40.416944444)'},
        'itemLabel': {'value': 'Madrid'},
    }]) == MADRID
    assert geocode.capital_from_bindings([{'itemLabel': {'value': 'Q2807'}, 'coord': {'value': 'Point(0 0)'}}]) is None
    assert geocode.choose([PIAZZA], 'Spagna') is None
    assert geocode.choose([PIAZZA, SPAIN], 'Spagna')['name'] == 'Spagna'
