"""Roam database schema: the single source of truth for every table.

Column order of the legacy tables matches the original CREATE TABLE statements,
because some queries still insert positionally (INSERT INTO x VALUES(...)).
"""
from sqlalchemy import JSON, Float, ForeignKey, Index, Integer, String, Text, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


# --- Places -----------------------------------------------------------------

class WebPhoto(Base):
    __tablename__ = 'web_photos'
    place_id: Mapped[str] = mapped_column(Text, primary_key=True)
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    checked_at: Mapped[float] = mapped_column(Float, nullable=False)


class PlacePhoto(Base):
    __tablename__ = 'place_photos'
    place_id: Mapped[str] = mapped_column(Text, primary_key=True)
    photo: Mapped[str] = mapped_column(Text, nullable=False)


class PlaceCatalog(Base):
    __tablename__ = 'place_catalog'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    payload: Mapped[str] = mapped_column(Text, nullable=False)


class Trip(Base):
    __tablename__ = 'trips'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    destination: Mapped[str] = mapped_column(Text, nullable=False)
    start_date: Mapped[str] = mapped_column(Text, nullable=False)
    end_date: Mapped[str] = mapped_column(Text, nullable=False)
    notes: Mapped[str] = mapped_column(Text, nullable=False)
    # Data from before accounts existed belongs to the first user (id 1).
    user_id: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('1'))
    __table_args__ = (Index('trips_user', 'user_id', 'start_date'),)


class Comment(Base):
    __tablename__ = 'comments'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    place_id: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    user_id: Mapped[int | None] = mapped_column(Integer)  # NULL for demo/imported reviews


# --- People and social --------------------------------------------------------

class Profile(Base):
    """A Roam account. Row 1 predates accounts and is claimed by the first sign-up."""
    __tablename__ = 'profile'
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    bio: Mapped[str] = mapped_column(Text, nullable=False)
    photo: Mapped[str | None] = mapped_column(Text)
    email: Mapped[str | None] = mapped_column(Text)          # lower-case
    password_hash: Mapped[str | None] = mapped_column(Text)  # scrypt; NULL for Apple/Google-only accounts
    apple_sub: Mapped[str | None] = mapped_column(Text)
    google_sub: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (Index('profile_email', 'email', unique=True), Index('profile_apple', 'apple_sub', unique=True),
                      Index('profile_google', 'google_sub', unique=True))


class AuthSession(Base):
    """Opaque bearer tokens; only their SHA-256 is stored."""
    __tablename__ = 'auth_sessions'
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), nullable=False)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)
    expires_at: Mapped[float] = mapped_column(Float, nullable=False)
    __table_args__ = (Index('auth_sessions_user', 'user_id'),)


class AuthorProfile(Base):
    __tablename__ = 'author_profiles'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    bio: Mapped[str] = mapped_column(Text, nullable=False)
    photo: Mapped[str | None] = mapped_column(Text)
    is_demo: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('0'))


class SocialPost(Base):
    __tablename__ = 'social_posts'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    place_id: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    photo: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    saved: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('0'))
    # Legacy flags from the single-user app: replaced by user_id and post_saves, kept for old rows.
    mine: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('0'))
    user_id: Mapped[int | None] = mapped_column(Integer)  # author account; NULL for demo/imported posts
    __table_args__ = (Index('social_posts_place', 'place_id', 'created_at'), Index('social_posts_user', 'user_id', 'created_at'))


class PostSave(Base):
    """A user's saved (liked) post."""
    __tablename__ = 'post_saves'
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), primary_key=True)
    post_id: Mapped[str] = mapped_column(Text, primary_key=True)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)


class SocialComment(Base):
    __tablename__ = 'social_comments'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    post_id: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    user_id: Mapped[int | None] = mapped_column(Integer)
    __table_args__ = (Index('social_comments_post', 'post_id', 'created_at'),)


class TripStory(Base):
    """A complete holiday shared in the feed: a collection of the author's own posts."""
    __tablename__ = 'trip_stories'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(Integer)  # author account; NULL for demo travellers
    author: Mapped[str] = mapped_column(Text, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    destination: Mapped[str] = mapped_column(Text, nullable=False)
    start_date: Mapped[str] = mapped_column(Text, nullable=False)  # YYYY-MM-DD
    end_date: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False, server_default='')
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    __table_args__ = (Index('trip_stories_user', 'user_id', 'created_at'), Index('trip_stories_created', 'created_at'))


class TripStoryPost(Base):
    __tablename__ = 'trip_story_posts'
    story_id: Mapped[str] = mapped_column(Text, ForeignKey('trip_stories.id', ondelete='CASCADE'), primary_key=True)
    post_id: Mapped[str] = mapped_column(Text, primary_key=True)
    __table_args__ = (Index('trip_story_posts_post', 'post_id'),)


class Follow(Base):
    """follower_id follows a person: 'u:<account id>' or 'n:<author name>' for travellers without an account."""
    __tablename__ = 'follows'
    follower_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), primary_key=True)
    target: Mapped[str] = mapped_column(String(200), primary_key=True)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    __table_args__ = (Index('follows_target', 'target'),)


# --- Direct messages ------------------------------------------------------------
# A conversation joins two person keys (a < b). The ROAM assistant is the peer key 'roam'.

class Conversation(Base):
    __tablename__ = 'conversations'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    a: Mapped[str] = mapped_column(String(200), nullable=False)
    b: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    updated_at: Mapped[str] = mapped_column(Text, nullable=False)
    __table_args__ = (Index('conversations_pair', 'a', 'b', unique=True), Index('conversations_b', 'b'))


class DirectMessage(Base):
    __tablename__ = 'direct_messages'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    conversation_id: Mapped[str] = mapped_column(Text, ForeignKey('conversations.id', ondelete='CASCADE'), nullable=False)
    sender: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    post_id: Mapped[str | None] = mapped_column(Text)        # a feed post shared in the chat
    payload: Mapped[str | None] = mapped_column(Text)        # ROAM replies: JSON with places and posts
    liked: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('0'))  # heart from the other side
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    __table_args__ = (Index('direct_messages_conversation', 'conversation_id', 'created_at'),)


class ConversationRead(Base):
    """When each participant last opened the conversation: unread counts and "Visualizzato"."""
    __tablename__ = 'conversation_reads'
    conversation_id: Mapped[str] = mapped_column(Text, ForeignKey('conversations.id', ondelete='CASCADE'), primary_key=True)
    person: Mapped[str] = mapped_column(String(200), primary_key=True)
    read_at: Mapped[str] = mapped_column(Text, nullable=False)


# --- Group trips -------------------------------------------------------------
# A group chat to organise a holiday: members discuss, then ROAM writes the plan.

class TripGroup(Base):
    __tablename__ = 'trip_groups'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    destination: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    start_date: Mapped[str] = mapped_column(Text, nullable=False)
    end_date: Mapped[str] = mapped_column(Text, nullable=False)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    updated_at: Mapped[str] = mapped_column(Text, nullable=False)
    plan: Mapped[str | None] = mapped_column(Text)            # JSON: latest plan written by ROAM


class TripGroupMember(Base):
    __tablename__ = 'trip_group_members'
    group_id: Mapped[str] = mapped_column(Text, ForeignKey('trip_groups.id', ondelete='CASCADE'), primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    joined_at: Mapped[str] = mapped_column(Text, nullable=False)
    read_at: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("''"))
    __table_args__ = (Index('trip_group_members_user', 'user_id'),)


class TripGroupMessage(Base):
    __tablename__ = 'trip_group_messages'
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    group_id: Mapped[str] = mapped_column(Text, ForeignKey('trip_groups.id', ondelete='CASCADE'), nullable=False)
    sender: Mapped[str] = mapped_column(String(200), nullable=False)   # u:<id>, roam or system
    body: Mapped[str] = mapped_column(Text, nullable=False)
    kind: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'text'"))  # text, plan, system
    payload: Mapped[str | None] = mapped_column(Text)                  # plan JSON for kind=plan
    created_at: Mapped[str] = mapped_column(Text, nullable=False)
    __table_args__ = (Index('trip_group_messages_group', 'group_id', 'created_at'),)


# --- Personalization (AI memory) ---------------------------------------------
# Three layers, from raw to compressed:
#   user_events      short rolling log of what the user did (pruned per user)
#   user_affinities  decayed scores per dimension (category, place, author, ...)
#   user_memory      a short text summary built from the two above + onboarding,
#                    the only thing that is put into the LLM prompt.

class UserPreference(Base):
    """Answers given in onboarding; editable later from the profile."""
    __tablename__ = 'user_preferences'
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), primary_key=True)
    travel_style: Mapped[str] = mapped_column(String(40), nullable=False, server_default='')
    pace: Mapped[str] = mapped_column(String(40), nullable=False, server_default='')
    budget: Mapped[str] = mapped_column(String(40), nullable=False, server_default='')
    companions: Mapped[str] = mapped_column(String(40), nullable=False, server_default='')
    interests: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    dietary: Mapped[str] = mapped_column(String(120), nullable=False, server_default='')
    notes: Mapped[str] = mapped_column(String(300), nullable=False, server_default='')
    onboarded_at: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[str] = mapped_column(Text, nullable=False)


class UserEvent(Base):
    __tablename__ = 'user_events'
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), nullable=False)
    kind: Mapped[str] = mapped_column(String(40), nullable=False)
    target: Mapped[str | None] = mapped_column(String(200))
    label: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[float] = mapped_column(Float, nullable=False)
    __table_args__ = (Index('user_events_user_time', 'user_id', 'created_at'),)


class UserAffinity(Base):
    __tablename__ = 'user_affinities'
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(20), primary_key=True)  # category | place | author | destination | search
    key: Mapped[str] = mapped_column(String(200), primary_key=True)
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    hits: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[float] = mapped_column(Float, nullable=False)


class UserMemory(Base):
    __tablename__ = 'user_memory'
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey('profile.id', ondelete='CASCADE'), primary_key=True)
    summary: Mapped[str] = mapped_column(Text, nullable=False, server_default='')
    updated_at: Mapped[float] = mapped_column(Float, nullable=False)
    # 1 once pre-existing likes/posts/trips have been learned (see bootstrap_from_history).
    bootstrapped: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text('0'))
