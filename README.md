# The Underworld Tour

The Underworld Tour is a rhythm-roguelike game following [a bands]'s journey into the Underworld to rescue their vocalist.

## Installation

1. Install Godot 4.7+
2. Clone the repo into a local folder
3. Open the `project.godot` in Godot
4. Click the run game project in the upper right

## Note charts

Store each track's chart in its own JSON file in `charts/` and select it in the RhythmCore node's **Chart Path** field. Each note is `[beat, lane, length]` using whole numbers. Lanes are `0` up, `1` right, `2` down, and `3` left. Length is measured in beats: `1` is a tap and longer notes are holds.

When creating a Godot export preset, add `charts/*.json` to the filter for exporting non-resource files.

### Generating charts from MIDI

`tools/midi_to_chart.py` converts a Standard MIDI File into a chart using only the Python standard library. It writes to `charts/<song>.json` unless you pass `-o`.

```sh
python3 tools/midi_to_chart.py assets/audio/song.mid --list-tracks
python3 tools/midi_to_chart.py assets/audio/song.mid --bpm 195
python3 tools/midi_to_chart.py assets/audio/song.mid \
    --lane-map "36-47:down,48-59:left,60-71:right,72-127:up"
```

Because charts use whole beats, every note onset is snapped to the nearest beat (change the step with `--grid`). Notes that start at the same time are pushed to free lanes, and overlapping holds are kept apart. Drum channel 10 is excluded by default; pass `--include-drums` to keep it. Other useful flags are `--min-pitch`, `--max-pitch`, `--min-velocity`, `--tracks`, `--channels`, `--offset` (beats added to the whole chart), and `--info`.

The audio's real tempo must match the RhythmCore scene's Conductor BPM; `--bpm` prints a warning when the MIDI tempo differs. If the audio has an intro of silence that the MIDI does not, use `--offset` to shift the whole chart to match the audio.

Run the tool's tests with `python3 -m unittest discover -s tools/tests`.

## Contributing

All changes must be done through pull request, as the main is protected. Changes require compilation success, PR bot approval, and another contributor's approval before being able to be merged into the main branch.

## License

N/A