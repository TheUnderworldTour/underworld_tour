# Contributing

## Definition of Done

A change is "done" when it passes **all** of the gates below. "It works on my machine" is not done. Each check names the mechanism that enforces it — if there's no enforcing mechanism yet, the check is aspirational, not done.

| Check | Enforced by | Status | Owner |
|---|---|---|---|
| Build succeeds on a clean clone | `make build` run by the **CI build job** (GitHub Actions) | lands **Week 3** with the project skeleton | Programmer |
| Tests pass | test suite (engine unit tests for beat clock, input windows, combat math) run by the **CI test job** | first meaningful tests land **Week 4** (beat clock); suite grows with each feature | Programmer |
| No compiler warnings / lints clean | engine linter config + `lint` CI job | lands **Week 3** | Programmer |
| Beat-sync verified on real hardware | **manual gate**: time a 30-second clip of input vs. audio on the target laptop; attach the capture to the PR | exists from **Week 3** (risk #1 says test in weeks 1–2, not week 5) | Designer reviews, Programmer records |
| Timing windows tuned, no regressions to feel | **playtest checklist** in the PR template ("tapped 32 beats: X perfect, Y good, Z miss") | starts **Week 5** | Designer |
| Audio/SFX files named, BPM-labeled, loop cleanly | naming check in review + asset import script that **fails the build** on wrong sample rate/length | asset script lands **Week 9**; before that, manual review | Composer |
| Reviewer approval | required PR review (1 approval; 2 for beat-clock or timing-window changes, since everything sits on them) | from the first PR in **Week 3** | everyone |
| Docs updated | PR template checkbox: "README / design doc updated if behavior changed"; reviewer enforces | from **Week 3** | PR author |
| Demo-level changes keep the loop winnable/losable | after **Week 6**, every combat change requires one recorded win and one loss attached to the PR | starts **Week 6** | Designer |

### Style Guidelines
Style Guidelines for this Godot can be found [here](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). The review agent will check these guidelines in all PRs.
