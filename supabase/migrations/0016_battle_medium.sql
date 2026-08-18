-- ══════════════════════════════════════════════════════════════════════
--  0016 — VOICE DUELS. A battle knows whether it's spoken or typed.
--
--  Every duel so far has been text, silently. The screen said "same
--  woman, both blind" and then always opened a chat, which quietly threw
--  away the better half of the product: the voice roleplay is the thing
--  people come for, and it was the one mode you couldn't fight in.
--
--  ── WHY THE QUEUE NEEDS THE COLUMN TOO ──────────────────────────────
--
--  A man queueing for a voice duel and a man queueing for a text duel
--  are not opponents. Pairing them means one of them opens the wrong
--  screen, and there is no sane way to score a spoken attempt against a
--  typed one — different rubrics, different lengths, different skill.
--
--  So the medium is part of the matchmaking key, not a detail on the
--  battle. Two separate lines, paired independently. That is also why
--  it is NOT NULL with a default: an old queue row from before this
--  migration reads as 'chat', which is what it actually was.
--
--  Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

alter table battles
  add column if not exists medium text not null default 'chat';

alter table battle_queue
  add column if not exists medium text not null default 'chat';

-- The pairing query is "oldest waiting stranger IN MY MEDIUM", so the
-- index has to lead with the thing it filters on and then order.
drop index if exists battle_queue_medium_idx;
create index if not exists battle_queue_medium_idx
  on battle_queue (medium, enqueued_at);

-- battle_queue's primary key is user_id, so a man can only hold ONE
-- place in line. That is deliberate and stays: queueing for voice
-- replaces a text queue rather than adding to it, and a single upsert
-- keeps that true without any cleanup.

comment on column battles.medium is
  'chat | voice — which room this duel is fought in.';
comment on column battle_queue.medium is
  'chat | voice — part of the matchmaking key, never paired across.';
