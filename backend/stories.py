"""Trips in the feed: a complete holiday told as a collection of the author's posts.

Not to be confused with /trips (the private travel planner): these are public, like an album.
A trip is only shown while at least one of its posts is visible (its place is in the catalog).
"""
from datetime import datetime, timezone
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

import auth
import personalization
import social
from database import db

router = APIRouter()
User = Annotated[dict, Depends(auth.current_user)]
PAGE = 10
PREVIEW = 4  # posts sent with each card in the list; the detail has them all

VISIBLE = ('EXISTS(SELECT 1 FROM trip_story_posts JOIN social_posts ON social_posts.id=trip_story_posts.post_id '
           'JOIN place_catalog ON place_catalog.id=social_posts.place_id WHERE trip_story_posts.story_id=trip_stories.id)')
FOLLOWED = ("(trip_stories.user_id=:me OR (trip_stories.user_id IS NOT NULL AND 'u:' || trip_stories.user_id IN (SELECT target FROM follows WHERE follower_id=:me)) "
            "OR (trip_stories.user_id IS NULL AND 'n:' || trip_stories.author IN (SELECT target FROM follows WHERE follower_id=:me)))")


class TripStoryInput(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    destination: str = Field(default='', max_length=120)
    start_date: str | None = Field(default=None, max_length=10)
    end_date: str | None = Field(default=None, max_length=10)
    body: str = Field(default='', max_length=3000)
    post_ids: list[str] = Field(min_length=2, max_length=60)


def _posts(c, story_id: str, me: int, limit: int | None = None) -> list[dict]:
    from main import POST_SELECT, social_post_result  # lazy: main imports this module
    sql = (f'{POST_SELECT} JOIN trip_story_posts ON trip_story_posts.post_id=social_posts.id '
           'WHERE trip_story_posts.story_id=:story ORDER BY social_posts.created_at, social_posts.id')
    if limit:
        sql += f' LIMIT {int(limit)}'
    return [social_post_result(c, r, me) for r in c.execute(sql, {'story': story_id, 'me': me}).fetchall()]


def _author_photo(c, row) -> str | None:
    if row['user_id'] is not None:
        found = c.execute('SELECT photo FROM profile WHERE id=?', (row['user_id'],)).fetchone()
        if found and found['photo']:
            return found['photo']
    found = c.execute('SELECT photo FROM author_profiles WHERE name=?', (row['author'],)).fetchone()
    return found['photo'] if found else None


def story_result(c, row, me: int, full: bool = False) -> dict:
    key = social.post_author_key(row['user_id'], row['author'])
    counts = c.execute('SELECT COUNT(*) AS posts, COUNT(DISTINCT social_posts.place_id) AS places FROM trip_story_posts '
                       'JOIN social_posts ON social_posts.id=trip_story_posts.post_id JOIN place_catalog ON place_catalog.id=social_posts.place_id '
                       'WHERE trip_story_posts.story_id=?', (row['id'],)).fetchone()
    mine = row['user_id'] == me
    author = c.execute('SELECT name FROM profile WHERE id=?', (me,)).fetchone()['name'] if mine else row['author']
    return dict(
        id=row['id'], title=row['title'], destination=row['destination'], start_date=row['start_date'], end_date=row['end_date'],
        body=row['body'], author=author, author_key=key, author_photo=_author_photo(c, row), mine=mine, created_at=row['created_at'],
        following=bool(c.execute('SELECT 1 FROM follows WHERE follower_id=? AND target=?', (me, key)).fetchone()),
        is_demo=row['id'].startswith('seed-'), post_count=counts['posts'], place_count=counts['places'],
        posts=_posts(c, row['id'], me, None if full else PREVIEW))


def _story(c, story_id: str):
    row = c.execute(f'SELECT * FROM trip_stories WHERE id=? AND {VISIBLE}', (story_id,)).fetchone()
    if not row:
        raise HTTPException(404, 'Viaggio non trovato')
    return row


@router.get('/feed/trips')
def list_stories(user: User, scope: Literal['all', 'following', 'mine'] = 'all', key: str = '', offset: int = 0):
    if not 0 <= offset <= 10000:
        raise HTTPException(422, 'Offset non valido')
    me = user['id']
    with db() as c:
        where, params = VISIBLE, {'me': me}
        if key:  # one traveller's trips, for their profile
            key = social.check_key(c, key)
            if key.startswith('u:'):
                where += ' AND trip_stories.user_id=:uid'; params['uid'] = int(key[2:])
            else:
                where += ' AND trip_stories.user_id IS NULL AND trip_stories.author=:author'; params['author'] = key[2:]
        elif scope == 'mine':
            where += ' AND trip_stories.user_id=:me'
        elif scope == 'following':
            where += ' AND ' + FOLLOWED
        rows = c.execute(f'SELECT * FROM trip_stories WHERE {where} ORDER BY created_at DESC, id DESC LIMIT :limit OFFSET :offset',
                         {**params, 'limit': PAGE + 1, 'offset': offset}).fetchall()
        return {'trips': [story_result(c, r, me) for r in rows[:PAGE]], 'has_more': len(rows) > PAGE}


@router.get('/feed/trips/{story_id}')
def get_story(story_id: str, user: User):
    with db() as c:
        return story_result(c, _story(c, story_id), user['id'], full=True)


def _date(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d')
    except ValueError:
        raise HTTPException(422, 'Usa date YYYY-MM-DD')


@router.post('/feed/trips', status_code=201)
def publish_story(value: TripStoryInput, user: User):
    me = user['id']
    title = value.title.strip()
    if not title:
        raise HTTPException(422, 'Dai un titolo al viaggio')
    ids = list(dict.fromkeys(value.post_ids))
    if len(ids) < 2:
        raise HTTPException(422, 'Scegli almeno due post')
    start, end = _date(value.start_date), _date(value.end_date)
    with db() as c:
        marks = ','.join('?' * len(ids))
        rows = c.execute(f'SELECT social_posts.id, social_posts.created_at FROM social_posts JOIN place_catalog ON place_catalog.id=social_posts.place_id '
                         f'WHERE social_posts.user_id=? AND social_posts.id IN ({marks})', (me, *ids)).fetchall()
        if len(rows) != len(ids):
            raise HTTPException(422, 'Puoi raccogliere solo i tuoi post')
        # Without dates, the trip spans the days its posts were published.
        days = sorted(r['created_at'][:10] for r in rows)
        start_date = start.strftime('%Y-%m-%d') if start else days[0]
        end_date = end.strftime('%Y-%m-%d') if end else max(days[-1], start_date)
        if end_date < start_date:
            raise HTTPException(422, 'Il ritorno non può precedere la partenza')
        author = c.execute('SELECT name FROM profile WHERE id=?', (me,)).fetchone()['name']
        sid = str(uuid4())
        c.execute('INSERT INTO trip_stories(id,user_id,author,title,destination,start_date,end_date,body,created_at) VALUES(?,?,?,?,?,?,?,?,?)',
                  (sid, me, author, title, value.destination.strip(), start_date, end_date, value.body.strip(), datetime.now(timezone.utc).isoformat()))
        c.executemany('INSERT INTO trip_story_posts(story_id,post_id) VALUES(?,?)', [(sid, pid) for pid in ids])
        result = story_result(c, _story(c, sid), me, full=True)
    if value.destination.strip():
        personalization.track('add_trip', me, destination=value.destination.strip())
    return result


@router.delete('/feed/trips/{story_id}', status_code=204)
def delete_story(story_id: str, user: User):
    """Removes the collection only: its posts stay in the feed and on the profile."""
    with db() as c:
        row = c.execute('SELECT user_id FROM trip_stories WHERE id=?', (story_id,)).fetchone()
        if not row:
            raise HTTPException(404, 'Viaggio non trovato')
        if row['user_id'] != user['id']:
            raise HTTPException(403, 'Puoi eliminare solo i tuoi viaggi')
        c.execute('DELETE FROM trip_story_posts WHERE story_id=?', (story_id,))
        c.execute('DELETE FROM trip_stories WHERE id=?', (story_id,))


def forget_post(c, post_id: str) -> None:
    """A deleted post leaves its trips; a trip left with fewer than two posts is removed."""
    stories = [r[0] for r in c.execute('SELECT story_id FROM trip_story_posts WHERE post_id=?', (post_id,))]
    c.execute('DELETE FROM trip_story_posts WHERE post_id=?', (post_id,))
    for sid in stories:
        if c.execute('SELECT COUNT(*) FROM trip_story_posts WHERE story_id=?', (sid,)).fetchone()[0] < 2:
            c.execute('DELETE FROM trip_story_posts WHERE story_id=?', (sid,))
            c.execute('DELETE FROM trip_stories WHERE id=?', (sid,))
