# How to apply this patch — 3-is-magic fix

Branch: create a new branch, e.g. fix/sorry-hold-split

Files in this zip:
- README-3-Is-Magic.md -> replace repo root file with this version
- drift_exists.lean -> replace repo root file with this version (reference-only stub, no theorem, no sorry)

What changed:
1. Core rewritten: "3 is the split" -> "3 holds 1. If it holds, it can be split. Split is hold run backwards."
2. drift_exists.lean section: drift NOT proven here, proven in Down-and-East / Basic.lean. No sorry as proof.
3. drift_exists.lean file: old proof attempt removed, replaced with reference-only stub.
4. How to check: no longer claims "no sorry, compiles" for a drift proof. Now checks: no sorry/admit used as proof, drift_exists is reference-only.
5. Rules: added Rule 6 — Do not re-prove drift here.

Apply:
  git checkout -b fix/sorry-hold-split
  copy both files into repo root, overwriting
  cp README-3-Is-Magic.md /path/to/3-is-magic/
  cp drift_exists.lean /path/to/3-is-magic/
  NOTE: the repo also has a file named "theorem drift_exists.lean" (with a space).
  If that file still contains the old proof attempt with sorry, delete it or replace it
  with this same stub, otherwise the old sorry is still in the repo.
  git add README-3-Is-Magic.md drift_exists.lean
  git commit -m "Fix sorry: drift lives in Down-and-East, 3-is-magic holds the hold"
  git push -u origin fix/sorry-hold-split

Then open a PR from fix/sorry-hold-split -> main and merge.
