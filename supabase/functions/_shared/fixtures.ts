// Shared fixtures core — weekly head-to-head between squadmates.
// The score IS the weekly league points, so every rep in the app moves
// the fixture without any extra tracking.

// deno-lint-ignore-file no-explicit-any

import { weekStart } from "./league.ts";

/// This week's league points for a user (0 when not enrolled yet).
export async function weekPoints(
  admin: any,
  uid: string,
  week: string,
): Promise<number> {
  const { data } = await admin
    .from("league_members")
    .select("points, leagues!inner(week_start)")
    .eq("user_id", uid)
    .eq("leagues.week_start", week);
  return data?.[0]?.points ?? 0;
}

/// Settle LAST week's fixture for this user if it's unsettled: compare
/// final points, stamp the winner, bump career records. Returns
/// 'won' | 'lost' | 'draw' | null.
export async function settleLastFixture(
  admin: any,
  uid: string,
): Promise<string | null> {
  const lastWeek = weekStart(new Date(Date.now() - 7 * 24 * 3600_000));
  const { data: rows } = await admin
    .from("fixtures")
    .select()
    .eq("week_start", lastWeek)
    .eq("settled", false)
    .or(`player_a.eq.${uid},player_b.eq.${uid}`);
  const f = rows?.[0];
  if (!f) return null;

  const [pa, pb] = await Promise.all([
    weekPoints(admin, f.player_a, lastWeek),
    weekPoints(admin, f.player_b, lastWeek),
  ]);
  const winner = pa === pb ? null : pa > pb ? f.player_a : f.player_b;

  await admin.from("fixtures")
    .update({ winner, settled: true }).eq("id", f.id);

  if (winner) {
    const loser = winner === f.player_a ? f.player_b : f.player_a;
    const [{ data: w }, { data: l }] = await Promise.all([
      admin.from("profiles").select("fixture_wins").eq("id", winner).single(),
      admin.from("profiles").select("fixture_losses").eq("id", loser).single(),
    ]);
    await Promise.all([
      admin.from("profiles")
        .update({ fixture_wins: (w?.fixture_wins ?? 0) + 1 }).eq("id", winner),
      admin.from("profiles")
        .update({ fixture_losses: (l?.fixture_losses ?? 0) + 1 }).eq("id", loser),
    ]);
  }
  return winner == null ? "draw" : winner === uid ? "won" : "lost";
}

/// Ensure this user has a fixture THIS week: find it, or pair the
/// squad's unpaired members deterministically (sorted ids, adjacent
/// pairs). The odd man out gets a bye (no fixture). Returns the
/// fixture row or null (no squad / bye week).
export async function ensureFixture(
  admin: any,
  uid: string,
): Promise<any | null> {
  const week = weekStart();

  // Squad?
  const { data: membership } = await admin
    .from("squad_members")
    .select("squad_id")
    .eq("user_id", uid)
    .eq("status", "active")
    .limit(1);
  const squadId = membership?.[0]?.squad_id;
  if (!squadId) return null;

  // Existing fixture this week?
  const { data: existing } = await admin
    .from("fixtures")
    .select()
    .eq("week_start", week)
    .eq("squad_id", squadId)
    .or(`player_a.eq.${uid},player_b.eq.${uid}`);
  if (existing && existing.length > 0) return existing[0];

  // Pair the unpaired.
  const [{ data: roster }, { data: paired }] = await Promise.all([
    admin.from("squad_members").select("user_id")
      .eq("squad_id", squadId).eq("status", "active"),
    admin.from("fixtures").select("player_a, player_b")
      .eq("week_start", week).eq("squad_id", squadId),
  ]);
  const taken = new Set<string>();
  for (const f of paired ?? []) {
    taken.add(f.player_a);
    taken.add(f.player_b);
  }
  const free = (roster ?? [])
    .map((r: any) => r.user_id as string)
    .filter((id: string) => !taken.has(id))
    .sort(); // deterministic
  const myIdx = free.indexOf(uid);
  if (myIdx < 0) return null;
  // Partner: the neighbour in the sorted free list.
  const partner = free[myIdx % 2 === 0 ? myIdx + 1 : myIdx - 1];
  if (!partner) return null; // odd man out — bye week

  const { data: fixture } = await admin.from("fixtures").insert({
    week_start: week,
    squad_id: squadId,
    player_a: uid < partner ? uid : partner,
    player_b: uid < partner ? partner : uid,
  }).select().single();
  return fixture;
}
