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

## Contributing

All changes must be done through pull request, as the main is protected. Changes require compilation success, PR bot approval, and another contributor's approval before being able to be merged into the main branch.

## License

N/A