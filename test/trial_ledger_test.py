#!/usr/bin/env python3
# THE TRIAL LEDGER, in the same arithmetic the Dart runs.
#
# There is no Flutter SDK here, so this mirrors TrialService.spend and
# LocalStoreService.addVoiceMs/voiceMsRemaining and asserts the four
# things that cost real money if they are wrong:
#   1. a trial user never reaches the PAID weekly allowance
#   2. the trial minute is a lifetime budget, so a weekly rollover
#      mid-trial cannot re-grant it
#   3. minutes he actually BOUGHT still work during the trial
#   4. converting to paid gives the full 14 with nothing carried over
#
# The first of these already failed once: the leftover past the trial
# minute fell through to the weekly allowance, handing every trial user
# a free week of voice.
#
#   python3 test/trial_ledger_test.py     (from the repo root)

# Port of TrialService + LocalStoreService.addVoiceMs/voiceMsRemaining.
MIN=60_000
TRIAL_MS   = 1*MIN          # TrialService.trialVoiceMinutes
WEEKLY_MS  = 14*MIN         # kVoiceMinutesPerWeek

class S:
    def __init__(s, trial): s.trial=trial; s.used=0; s.week=0; s.bank=0; s.bucket=0
def remaining(s):
    if s.trial: return max(0, TRIAL_MS - s.used) + s.bank
    return max(0, WEEKLY_MS - s.week) + s.bank
def add(s, d):
    if s.trial:
        left = max(0, min(TRIAL_MS - s.used, TRIAL_MS))
        take = min(d, left); s.used += take; d -= take
        # leftover draws ONLY on bought minutes, never the weekly allowance
        if d > 0: s.bank = max(0, s.bank - d)
        return
    wl = max(0, WEEKLY_MS - s.week)
    fw = min(d, wl); s.week += fw
    fb = d - fw
    if fb > 0: s.bank = max(0, s.bank - fb)
def roll_week(s): s.week = 0        # the rolling 7-day reset

ok=True
def check(c,label):
    global ok
    print(('  pass ' if c else '  FAIL ')+label)
    if not c: ok=False

print('TRIAL — 1 minute, unlimited chat (chat is uncapped for Pro already)')
s=S(trial=True)
check(remaining(s)==1*MIN, 'starts with exactly 1 minute')
add(s, 40_000); check(remaining(s)==20_000, 'spends down to 20s')
add(s, 30_000); check(remaining(s)==0, 'hits zero and stops')
check(s.week==0, 'NEVER touched the paid weekly allowance')

print()
print('THE RESET EXPLOIT — a trial spanning a weekly rollover')
s=S(trial=True); add(s, 1*MIN)
roll_week(s)
check(remaining(s)==0, 'still zero after the week rolls (lifetime counter)')

print()
print('BOUGHT MINUTES DURING TRIAL — he paid, he must be able to speak')
s=S(trial=True); s.bank=10*MIN
check(remaining(s)==11*MIN, 'trial minute + the pack he bought')
add(s, 3*MIN)
check(s.used==1*MIN, 'trial budget drained first')
check(s.bank==8*MIN, 'then the pack, 2 min of it')
check(s.week==0, 'weekly allowance never touched')

print()
print('CONVERSION — trial becomes paid')
s=S(trial=True); add(s, 1*MIN)
s.trial=False                       # periodType flips trial -> normal
check(remaining(s)==14*MIN, 'full weekly allowance, nothing carried over')
add(s, 5*MIN); check(remaining(s)==9*MIN, 'and it spends normally')

print()
print('PAID USER IS UNCHANGED (regression guard)')
s=S(trial=False)
check(remaining(s)==14*MIN, 'still 14 minutes')
add(s, 14*MIN); check(remaining(s)==0, 'still caps at 14')
roll_week(s); check(remaining(s)==14*MIN, 'still resets weekly')

print()
print('COST OF A TRIAL THAT NEVER CONVERTS')
print(f'  1 voice minute @ $0.03      = ${0.03:.2f}')
print(f'  ~40 chat turns @ ~$0.004    = ${40*0.004:.2f}')
print(f'  worst case per free-rider   = ${0.03+40*0.004:.2f}')
print()
print('ALL PASS' if ok else 'FAILURES')
import sys; sys.exit(0 if ok else 1)
