<!-- docs/rfcs/2026-10-25-audio-clock-note-timing.md -->

# RFC: Drive all note timing from the Conductor's audio clock instead of per-note timers

| Field | Value |
| --- | --- |
| Author | graham |
| Date | 2026-10-25 |
| Status | Proposed |
| Decision Date | (fill when decided) |
| Deciders | (who agreed to the outcome) |
| Superseded By | (link, if applicable) |

## Problem and Context

The game is a rhythm game, so the single most important quality it has is that a note hits its target beat at the same moment the audio plays that beat. Right now we are at the point where the first playable notes exist (commit `bbd61d8`, "Implement complete note logic, with arrow key controls"), and we have to choose — once, and more or less permanently — what clock the note system trusts.

The code as it stands today has already committed to one answer: a single `Conductor` node (an `AudioStreamPlayer` in `scripts/conductor.gd`) tracks `song_position` in seconds using `get_playback_position()` + `AudioServer.get_time_since_last_mix()` − `AudioServer.get_output_latency()`, and emits `beat` and `measure` signals. Every note in `scripts/note.gd` computes its travel time from `conductor.sec_per_beat` and positions itself as a function of `_conductor.song_position`, and hit windows (`can_hit()`, `get_accuracy()`) are evaluated against the same clock.

If we keep this, changing it later means rewriting every note's movement, hit detection, and miss detection — every piece of gameplay code that says "seconds". If we don't decide now and gameplay grows further on top of whatever implicit clock exists, the eventual migration cost grows with every feature: hold notes, combo multipliers, calibration screens, and multiplayer all need to agree on what "now" means.

This decision is difficult to reverse because the clock is not a module — it is an assumption baked into every line that positions a note or judges an input. Reversing it is a rewrite of the playfield, not a refactor.

## Options

### Option A: Single audio-clock Conductor (current path)

One `Conductor` node owns time. Notes, spawners, and scoring all read `song_position` from it and derive beat indices from `bpm`. Count-in beats are handled by the Conductor (`beats_before_start`, `play_with_beat_offset`), and a wall-clock fallback exists so gameplay still works before audio is wired up.

Benefits: one source of truth; audio latency is corrected in exactly one place; beat/measure signals make spawning logic trivial (`rhythm_core.gd` `_on_beat` is a small while loop); the fallback clock keeps early development testable without audio assets.

Costs: every gameplay system is coupled to the Conductor's variable names and semantics; if the Conductor's clock is wrong (e.g., latency correction misapplied on a given device), *everything* is wrong at once and the bug shows up as a uniform "feel" problem rather than a traceable error. Changing the clock later means touching every note and every scoring path.

Right choice when: the game is fundamentally a rhythm game with a single music track per play session — which is what this project is.

### Option B: Per-note timers with independent clocks

Each `Note` starts its own timer (or tween) when spawned and measures its own lifetime. Hit windows are evaluated against the note's own elapsed time.

Benefits: notes are fully self-contained; no cross-node dependency on the Conductor; trivially easy to pause or slow a single note.

Costs: timers drift independently of the audio stream. Even a small per-frame drift (Godot's `Timer` and `Tween` are frame-based, not sample-locked) accumulates into a note that visibly arrives off-beat. Fixing sync would mean re-deriving each note's time from the audio anyway — which is Option A with extra indirection. It also duplicates the "what is now" question across every note.

Right choice when: the game's notes are decorative or loosely timed (e.g., a visualizer), not judged against millisecond-level hit windows.

### Option C: Do Nothing

Leave the clock question unanswered and let each new feature pick whatever is convenient. Today that would mean `note.gd` reading the Conductor while, say, a future combo system uses `Time.get_ticks_msec()`, and a future hold-note system uses tweens.

Cost: the codebase ends up with three clocks and no single place to fix latency. The cost arrives not at launch but at the first "the combo counter disagrees with the hit window" bug report — likely during tuning, the most schedule-critical phase, when debugging time is scarcest.

## Analysis

- **Accuracy.** The audio path in `conductor.gd` (`get_playback_position()` + time-since-last-mix − output latency) is the standard Godot pattern for rhythm-game sync and is documented as the correct way to compensate for output latency. Option B's frame-based timers cannot make this correction at all, because a frame timer has no idea where the audio buffer is. Uncertainty: latency values differ per device; the fallback wall-clock path is knowingly approximate and only suitable before audio exists. The Definition of Done already requires a manual beat-sync verification gate on real hardware, which is the check that catches this.
- **Complexity.** Option A centralizes latency correction and count-in logic in one ~100-line script. Option B spreads timing math across every note. C accumulates complexity over time in the worst way (inconsistently).
- **Maintainability.** Coupling to the Conductor is real (notes use `get_tree().get_first_node_in_group("conductor")`), but it is a single, stable dependency. The alternative — decoupling via injected time sources — is possible later *within* Option A without changing what the clock is, so A does not foreclose refactoring.
- **Performance.** Negligible difference; one `AudioStreamPlayer` read per frame vs. a handful of timers. Not a deciding factor.
- **Reversibility.** This is the crux. A→B is a playfield rewrite; A→B for a *future* feature is merely late adoption. The cost asymmetry is why we decide now.

Prior art relied on: the Godot documentation for `AudioServer.get_output_latency()` and `AudioStreamPlayer.get_playback_position()`; the in-repo Definition of Done in `CONTRIBUTING.md`, which calls beat sync risk #1 and requires two reviewer approvals for beat-clock changes — evidence the team already treats the clock as load-bearing.

## Recommendation and Verification Plan

Recommend **Option A**, which is also what the code already does — this RFC records it and makes the cost of leaving it explicit.

Verification:
- The existing manual gate: a 30-second capture of input vs. audio on the target laptop, attached to the PR, per `CONTRIBUTING.md`.
- Unit tests on the beat clock (first tests scheduled Week 4): assert that N seconds of playback yields N/beat-length beats, and that the fallback clock and audio clock agree within tolerance.
- Acceptance criterion for failure: if a playtester reports notes arriving consistently early or late by more than the hit window on the target hardware, the latency correction in the Conductor is wrong and must be fixed *there*, not per-feature — that containment is the test that the decision is working.

## Constraints

No licensing, data-use, IP, or partner-confidentiality constraints bear on this decision: the timing logic is original code, uses only engine APIs (Godot is MIT-licensed), and no third-party audio or partner assets are involved yet.

## Delegation and Validation

- **What was handed to AI tools:** the Conductor implementation and its explanatory comments (`53b9d4f`), and the initial draft of this RFC's prose.
- **What checks made that reasonable:** the timing approach matches the documented Godot pattern (checked against engine docs); the Definition of Done's two-reviewer rule for beat-clock changes means any deviation gets human review before merge; CI build and lint jobs exist from Week 3.
- **Where I stopped and validated myself:** I read `conductor.gd`, `note.gd`, and `rhythm_core.gd` end to end to confirm that every consumer of time currently reads from the Conductor (no stray timers), and I confirmed the fallback clock exists so the pre-audio phase doesn't silently change semantics. Because this decision is hard to reverse, the beat-sync hardware gate — which only a human at a real machine can perform — is deliberately left as a manual check and is not something AI tooling can substitute for.

## Decision

Proposed, until the team decides. Then accepted, rejected, or superseded, with the date and who chaired the decision. If superseded, link the RFC that replaces this one.
