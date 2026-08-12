// ═════════════════════════════════════════════════════════════════════
//  The RIZZ POINTS roller — the one place the text ladder is computed.
//
//  Two Edge Functions feed this ladder (score-chat for roleplay and
//  mission chats, battle-action for duels) and they must never disagree
//  about what a man's total is. So neither of them does the arithmetic:
//  they record an attempt, then call this.
//
//  It rolls the standing from the ATTEMPTS THEMSELVES rather than
//  incrementing a counter. That makes every write idempotent and
//  self-healing — a lost write or a double-fire can't drift the total,
//  because the total is never trusted, only recomputed.
// ═════════════════════════════════════════════════════════════════════

/// Flat bonus for taking a duel. Volume climbs the board; winning climbs
/// it faster. Kept well above a single conversation's ceiling (100) but
/// below what a genuinely active day of practice pays, so battles are
/// worth seeking out without making everything else pointless.
export const WIN_BONUS = 50;

export interface ChatStanding {
  points: number;
  best: number;
  attempts: number;
  average: number;
  battles: number;
  wins: number;
}

/// Recompute and persist one user's whole text standing.
///
/// [admin] must be a service-role client — chat_score has no client
/// write policy by design.
export async function rollChatStanding(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
  { addBattle = false, addWin = false }: {
    addBattle?: boolean;
    addWin?: boolean;
  } = {},
): Promise<ChatStanding> {
  const [{ data: rows }, { data: prev }] = await Promise.all([
    admin.from("chat_attempts").select("score").eq("user_id", userId),
    admin.from("chat_score").select("battles, wins").eq("user_id", userId)
      .maybeSingle(),
  ]);

  const scores: number[] = (rows ?? []).map((r: { score: number }) => r.score);
  const attempts = scores.length;
  const sum = scores.reduce((a, b) => a + b, 0);
  const best = attempts ? Math.max(...scores) : 0;
  const average = attempts ? Math.round(sum / attempts) : 0;

  // Battles and wins are counters rather than derived, because a duel
  // the caller lost leaves no row of its own to count. They're the only
  // incremented values here, and both only ever move forward.
  const battles = (prev?.battles ?? 0) + (addBattle ? 1 : 0);
  const wins = (prev?.wins ?? 0) + (addWin ? 1 : 0);
  const points = sum + wins * WIN_BONUS;

  await admin.from("chat_score").upsert({
    user_id: userId,
    points,
    best,
    attempts,
    average,
    battles,
    wins,
    updated_at: new Date().toISOString(),
  });

  return { points, best, attempts, average, battles, wins };
}
