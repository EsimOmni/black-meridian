# Unreal reboot planning package — **this is the authoring home**

The sixteen documents here are authored and versioned in **this** repository
(`D:\black-meridian`, the Godot oracle). They are **mirrored** to
`D:\black-meridian-ue\Docs\plan\` for convenience while working in the Unreal repo.

| | |
|---|---|
| **Authoring home (edit HERE)** | `D:\black-meridian\docs\unreal-reboot\` |
| **Mirror (read-only copy)** | `D:\black-meridian-ue\Docs\plan\` |
| **Gate evidence** | `D:\black-meridian-ue\Docs\gates\S<n>.md` |

⚠️ **Edit here, then re-mirror.** A fix made only in the Unreal copy is lost the next time anyone
re-mirrors, and — worse — a document corrected in only one of the two trees leaves the other standing as
authority. That is not hypothetical: S4 found `UBMSaveGame` prescribed in **two** documents in **two
different shapes**, and correcting only the one you happen to open is exactly how that survives.

```sh
# from D:\black-meridian
for f in docs/unreal-reboot/*.md; do cp "$f" "/d/black-meridian-ue/Docs/plan/$(basename $f)"; done
# then verify — all 16 must be byte-identical
for f in docs/unreal-reboot/*.md; do b=$(basename $f); cmp -s "$f" "/d/black-meridian-ue/Docs/plan/$b" \
    || echo "DIFF $b"; done
```

Update the commit pinned in the mirror's own `README.md` when you do.

## Reading order

`00_EXECUTIVE_DECISION.md` → `MASTER_PLAN.md` → whichever document the task needs.

**Read `MASTER_PLAN` §1b first, before trusting any `[P]` in the package.** It is the plan-vs-reality
record after five shipped slices (**27 corrections folded in**), and it carries the pattern that predicts
which claims break:

> **Structural judgments were right. Empirical claims about the existing Godot build were wrong roughly
> whenever they were not marked `[V]`.**

## How corrections are recorded

Three places, deliberately:

1. **In place, at the source**, struck through rather than deleted, with a pointer to the gate doc that
   found it. A reader who arrives at the wrong claim must see that it was wrong.
2. **`MASTER_PLAN` §1b** — the package-wide claim/reality table and the lessons.
3. **`Docs/gates/S<n>.md` → "Corrections owed to the planning package"** — the authoritative per-slice
   list, in the Unreal repo, where the evidence lives.

There is no separate `CORRECTIONS.md`; the gate docs are the log.

**Fold corrections in before starting the next slice.** S3's five sat unfolded until S4 shipped, which
meant S4 read them as authoritative — the backlog was two slices deep before anyone noticed.
