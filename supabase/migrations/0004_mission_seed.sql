-- ══════════════════════════════════════════════════════════════════════
--  0004 — starter mission catalog: the escalation ladder.
--
--  Framing is deliberate and non-negotiable: every mission trains
--  CONFIDENCE and respectful connection. Nothing targets or pressures a
--  specific person — that's what keeps App Review, the brand, and the
--  movement clean. Tier = ladder level; the engine serves the lowest
--  uncompleted tier. Safe to re-run (delete + reinsert by title).
-- ══════════════════════════════════════════════════════════════════════

delete from missions where title in (
  'Eye Contact', 'The Greeting', 'Small Talk Opener', 'The Compliment',
  'Hold the Conversation', 'The Cold Start', 'Group Entry',
  'The Real Conversation', 'Ask Them Out', 'Pressure Proof'
);

insert into missions (tier, category, title, prompt, proof_type, active) values
 (1, 'presence',     'Eye Contact',
  'Today: hold friendly eye contact and smile at three strangers as you pass. No words needed. You''re training your body to stop hiding.', 'discord', true),
 (1, 'presence',     'The Greeting',
  'Say a genuine "hey, how''s it going?" to three people you''d normally walk past — barista, doorman, whoever. Voice up, chin up.', 'discord', true),
 (2, 'conversation', 'Small Talk Opener',
  'Start one real small-talk exchange with a stranger today — a comment about the moment you''re both in (the queue, the weather, the music). Keep it going for three exchanges.', 'discord', true),
 (2, 'conversation', 'The Compliment',
  'Give one genuine, specific compliment to someone today — about a choice they made (style, energy, work), not their body. Watch what it does to the interaction.', 'discord', true),
 (3, 'conversation', 'Hold the Conversation',
  'Take one conversation past small talk today. Ask a real question, listen, and share something real back. Two minutes minimum.', 'discord', true),
 (3, 'approach',     'The Cold Start',
  'Start a conversation with someone you find interesting, from zero, in a social setting. The goal is the START — however it goes, you won.', 'discord', true),
 (4, 'approach',     'Group Entry',
  'Join an ongoing group conversation naturally — at work, the gym, an event. Add one thing to the topic. Exit whenever you want. Entering is the rep.', 'discord', true),
 (4, 'conversation', 'The Real Conversation',
  'Have a conversation where you''re fully present: no phone, no rehearsing your next line, no exit plan. Just curiosity. Notice how different it feels.', 'discord', true),
 (5, 'approach',     'Ask Them Out',
  'If a conversation is genuinely flowing and the interest is mutual — ask them to continue it: coffee, a walk, their number. Respect whatever the answer is. Asking is the victory.', 'discord', true),
 (5, 'presence',     'Pressure Proof',
  'Put yourself in one situation today that scares you socially — speak up in the meeting, tell the story to the group, make the toast. Feel the fear. Do it anyway.', 'discord', true);
