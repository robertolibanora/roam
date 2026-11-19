import base64

from test_api import client  # first account
from test_api import local_catalog  # noqa: F401  (autouse fixture)
from test_auth import new_client

PHOTO = base64.b64encode(b'\xff\xd8\xfftrip-story').decode()


def publish(c, body):
    return c.post('/feed/posts', json={'place_id': 'rialto', 'body': body, 'rating': 5, 'photo': PHOTO}).json()


def test_trip_is_a_collection_of_own_posts():
    a, b, c = (publish(client, f'Tappa {i}') for i in range(3))
    other, session = new_client('trip-dora@example.com', name='Dora Trip')
    foreign = publish(other, 'Non mio')

    assert client.post('/feed/trips', json={'title': 'Uno solo', 'post_ids': [a['id']]}).status_code == 422
    assert client.post('/feed/trips', json={'title': 'Misto', 'post_ids': [a['id'], foreign['id']]}).status_code == 422
    assert client.post('/feed/trips', json={'title': 'Date', 'post_ids': [a['id'], b['id']], 'start_date': '2026-11-10', 'end_date': '2026-11-01'}).status_code == 422

    trip = client.post('/feed/trips', json={'title': ' Weekend a Venezia ', 'destination': 'Venezia', 'body': 'Tre giorni in laguna',
                                            'post_ids': [c['id'], a['id'], b['id']]}).json()
    assert trip['title'] == 'Weekend a Venezia' and trip['mine'] and trip['post_count'] == 3 and trip['place_count'] == 1
    assert [p['id'] for p in trip['posts']] == [a['id'], b['id'], c['id']]  # in travel order
    assert trip['start_date'] <= trip['end_date']

    mine = client.get('/feed/trips', params={'scope': 'mine'}).json()['trips']
    assert mine[0]['id'] == trip['id']
    assert trip['id'] in [t['id'] for t in client.get('/feed/trips', params={'scope': 'following'}).json()['trips']]
    assert trip['id'] not in [t['id'] for t in other.get('/feed/trips', params={'scope': 'following'}).json()['trips']]
    seen = other.get(f"/feed/trips/{trip['id']}").json()
    assert not seen['mine'] and seen['following'] is False and len(seen['posts']) == 3
    assert other.delete(f"/feed/trips/{trip['id']}").status_code == 403

    # Deleting posts shrinks the trip; with one post left it is no longer a trip.
    assert client.delete(f"/feed/posts/{a['id']}").status_code == 204
    assert client.get(f"/feed/trips/{trip['id']}").json()['post_count'] == 2
    assert client.delete(f"/feed/posts/{b['id']}").status_code == 204
    assert client.get(f"/feed/trips/{trip['id']}").status_code == 404


def test_delete_trip_keeps_posts():
    a, b = publish(client, 'Primo'), publish(client, 'Secondo')
    trip = client.post('/feed/trips', json={'title': 'Breve', 'post_ids': [a['id'], b['id']]}).json()
    assert client.delete(f"/feed/trips/{trip['id']}").status_code == 204
    assert client.get(f"/feed/trips/{trip['id']}").status_code == 404
    ids = [p['id'] for p in client.get('/feed/mine').json()['posts']]
    assert a['id'] in ids and b['id'] in ids
