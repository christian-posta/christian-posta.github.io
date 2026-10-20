# Repository Instructions

## Christian Posta Blog Voice

When writing or editing posts in `_posts/`, or any prose meant to be published under Christian's name, use the `posta-voice` skill (user-level, from `~/dev/code/skills/posta-voice/`; not stored in this repo). It holds the full voice guide, verbatim exemplars from the blog and from *Istio in Action*, before/after rewrites, the list of AI and marketing tells to avoid, and a linter (`scripts/lint_voice.py`) whose thresholds come from the published corpus. Read the skill instead of relying on the summary below.

The short version, for agents that cannot load skills:

- Open from a concrete trigger (a spec change, a customer question, someone's post you name) and land the verdict by paragraph two. No abstract thesis openings.
- First person, direct, opinionated, pragmatic. Say where an approach works first, then where it breaks in a large enterprise, and be specific about the break.
- Multi-sentence paragraphs (median ~50 words). One-sentence paragraphs are punchlines or transitions, never a rhythm.
- Move the argument with rhetorical questions and stage the reader's objection in italics before answering it.
- Anchor everything in real config, protocols, RFCs, and named products and people, with links. Draw "who holds what" boundaries.
- No em-dashes, no "not X, it's Y" constructions, no "here's the thing", no press-release phrasing. Conclusions recommend; they do not summarize.
- Long, comma-joined sentences with parentheticals, not runs of short punchy ones. Lists use slashes, "e.g.", "ie,", "such as", and trail off with "etc".
- Match the stance in the notes. Concede what works ("you can, but it only solves half the problem") without upgrading it to a recommendation he would not make.
- Say plainly when a standard or pattern is early. Preserve informality and typos-in-spirit; do not sand the prose smooth.

Run `python3 ~/dev/code/skills/posta-voice/scripts/lint_voice.py _posts/<draft>.md` before handing a draft back.
