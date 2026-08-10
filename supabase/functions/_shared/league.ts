// Shared league core — enrolment, points, lazy week-end settlement.
// Used by daily-game (the main door) and score-voice (casual roleplay
// sessions passively feed the league — Duolingo's auto-enrol trick, so
// normal-mode players appear in the game without opting in).

// deno-lint-ignore-file no-explicit-any

export const DIVISIONS = [
  "ROOKIE LEAGUE",
  "PLAYER LEAGUE",
  "SAVAGE LEAGUE",
  "ELITE LEAGUE",
  "HIM LEAGUE",
];
export const MAX_DIVISION = DIVISIONS.length;
export const LEAGUE_SIZE = 30;
export const PROMOTE_TOP = 10;
export const RELEGATE_BOTTOM = 5;

/// Monday (UTC) of the week containing `now`, as YYYY-MM-DD.
export function weekStart(now = new Date()): string {
  const d = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  ));
  const dow = (d.getUTCDay() + 6) % 7; // Mon=0..Sun=6
  d.setUTCDate(d.getUTCDate() - dow);
  return d.toISOString().slice(0, 10);
}

/// Sunday 21:00 UTC of the given week — when the league locks.
export function lockTime(week: string): string {
  const d = new Date(`${week}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 6);
  d.setUTCHours(21, 0, 0, 0);
  return d.toISOString();
}

/// Settle LAST week for this user if unsettled (lazy — no cron needed):
/// top 10 of their old league promote, bottom 5 relegate. Returns the
/// ceremony ('promoted' | 'relegated' | 'held') or null when nothing to
/// settle.
export async function settleLastWeek(
  admin: any,
  uid: string,
): Promise<string | null> {
  const lastWeek = weekStart(
    new Date(Date.now() - 7 * 24 * 3600_000),
  );
  const { data: memberships } = await admin
    .from("league_members")
    .select("league_id, points, settled, leagues!inner(week_start, division)")
    .eq("user_id", uid)
    .eq("settled", false)
    .eq("leagues.week_start", lastWeek);
  const m = memberships?.[0];
  if (!m) return null;

  const { data: standings } = await admin
    .from("league_members")
    .select("user_id, points")
    .eq("league_id", m.league_id)
    .order("points", { ascending: false });
  const rank =
    (standings ?? []).findIndex((r: any) => r.user_id === uid) + 1;
  const division = m.leagues.division as number;

  let ceremony = "held";
  let newDivision = division;
  if (rank > 0 && rank <= PROMOTE_TOP && division < MAX_DIVISION) {
    newDivision = division + 1;
    ceremony = "promoted";
  } else if (
    rank > (standings?.length ?? 0) - RELEGATE_BOTTOM &&
    division > 1
  ) {
    newDivision = division - 1;
    ceremony = "relegated";
  }

  await admin.from("profiles").update({ division: newDivision })
    .eq("id", uid);
  await admin.from("league_members").update({ settled: true })
    .eq("league_id", m.league_id).eq("user_id", uid);
  return ceremony;
}

/// Ensure the user is in a league THIS week (auto-enrol, Duolingo
/// style): join the emptiest open league in their division or found a
/// new one. Returns the league id.
export async function ensureLeague(
  admin: any,
  uid: string,
): Promise<string> {
  const week = weekStart();
  // Already in?
  const { data: mine } = await admin
    .from("league_members")
    .select("league_id, leagues!inner(week_start)")
    .eq("user_id", uid)
    .eq("leagues.week_start", week);
  if (mine && mine.length > 0) return mine[0].league_id as string;

  const { data: prof } = await admin.from("profiles")
    .select("division").eq("id", uid).single();
  const division = prof?.division ?? 1;

  // Emptiest league in this division/week with room.
  const { data: leagues } = await admin
    .from("leagues")
    .select("id, league_members(count)")
    .eq("week_start", week)
    .eq("division", division);
  let target = (leagues ?? [])
    .map((l: any) => ({
      id: l.id as string,
      count: l.league_members?.[0]?.count ?? 0,
    }))
    .filter((l: any) => l.count < LEAGUE_SIZE)
    .sort((a: any, b: any) => a.count - b.count)[0]?.id;

  if (!target) {
    const { data: created } = await admin.from("leagues")
      .insert({ week_start: week, division }).select().single();
    target = created!.id as string;
  }
  await admin.from("league_members")
    .upsert({ league_id: target, user_id: uid });
  return target;
}

/// Add points to this week's league row (auto-enrolling first).
export async function addLeaguePoints(
  admin: any,
  uid: string,
  points: number,
): Promise<void> {
  const leagueId = await ensureLeague(admin, uid);
  const { data: row } = await admin.from("league_members")
    .select("points").eq("league_id", leagueId).eq("user_id", uid)
    .single();
  await admin.from("league_members")
    .update({ points: (row?.points ?? 0) + points })
    .eq("league_id", leagueId).eq("user_id", uid);
}
