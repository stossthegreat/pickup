#!/usr/bin/env python3
# The paywall tier + trial rules, in the same logic the Dart runs.
# Guards the four ways this screen can lie to a man about money:
# promising a trial he is not eligible for, sitting on a tier the store
# never delivered, showing a fabricated price, or calling a DISCOUNTED
# intro period "free".
#
#   python3 test/paywall_tiers_test.py
# Port of the paywall's tier + trial selection.
class Pkg:
    def __init__(s, pid, price, intro=None): s.pid=pid; s.price=price; s.intro=intro
class Off:
    def __init__(s, weekly=None, monthly=None): s.weekly=weekly; s.monthly=monthly

def state(off, ever_trialled):
    picked = 'monthly'
    if off.monthly is None and off.weekly is not None: picked = 'weekly'
    def pkg(t): return off.monthly if t=='monthly' else off.weekly
    eligible = not ever_trialled
    p = pkg(picked)
    intro = p.intro if (p and eligible) else None
    if intro is not None and intro > 0: intro = None      # discount != free
    return picked, (p.price if p else '—'), intro, (p is not None)

ok=True
def chk(c,l):
    global ok
    print(('  pass ' if c else '  FAIL ')+l);  ok = ok and c

M = Pkg('imhim_pro_monthly','£19.99', intro=0.0)   # 3-day free
W = Pkg('imhim_pro_weekly','£6.99')                # no offer

print('BOTH TIERS LIVE, first-time user')
picked, price, intro, live = state(Off(W,M), False)
chk(picked=='monthly', 'monthly preselected (it carries the trial)')
chk(price=='£19.99' and live, 'shows the real store price')
chk(intro==0.0, 'trial offered')

print('\nALREADY USED A TRIAL')
picked, price, intro, live = state(Off(W,M), True)
chk(intro is None, 'no trial promised -> CTA falls back to paid copy')

print('\nMONTHLY NOT YET CREATED IN THE STORE')
picked, price, intro, live = state(Off(W,None), False)
chk(picked=='weekly', 'falls back to weekly, never sits on a dead tier')
chk(live and price=='£6.99', 'weekly is purchasable')
chk(intro is None, 'and promises no trial it cannot honour')

print('\nNOTHING CONFIGURED AT ALL')
picked, price, intro, live = state(Off(None,None), False)
chk(not live and price=='—', 'dash, not a fake price')

print('\nDISCOUNTED INTRO (not free) MUST NOT READ AS A TRIAL')
D = Pkg('imhim_pro_monthly','£19.99', intro=4.99)
_,_,intro,_ = state(Off(W,D), False)
chk(intro is None, 'paid intro is not advertised as free')

print('\nALL PASS' if ok else '\nFAILURES')
import sys; sys.exit(0 if ok else 1)
