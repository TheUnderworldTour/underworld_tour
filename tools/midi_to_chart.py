#!/usr/bin/env python3
"""Convert a MIDI file into an Underworld Tour note chart.

Charts are JSON arrays of ``[beat, lane, length]`` integer rows. Lanes are
0 up, 1 right, 2 down, 3 left. Length is in beats, where 1 is a tap and
anything larger is a hold. Because the game reads whole beats, this tool
snaps every note onset to a whole-beat grid (see ``--grid``).

Usage:
    python3 tools/midi_to_chart.py song.mid
    python3 tools/midi_to_chart.py song.mid -o charts/song.json
    python3 tools/midi_to_chart.py song.mid --lane-map "36-47:down,48-59:left,60-71:right,72-127:up"
    python3 tools/midi_to_chart.py song.mid --list-tracks

No third-party packages are required.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

LANE_NAMES = ("up", "right", "down", "left")
AUTO_LANE_ORDER = (2, 3, 1, 0)
DRUM_CHANNEL = 9
DEFAULT_LEAD_IN = 4


class MidiError(Exception):
    """Raised when a file is not a supported Standard MIDI File."""


@dataclass
class NoteSpan:
    start_tick: int
    end_tick: int
    pitch: int
    velocity: int
    channel: int
    track: int


@dataclass
class ParsedTrack:
    index: int
    name: str = ""
    note_count: int = 0


@dataclass
class MidiFile:
    ppq: int
    format: int
    tracks: list[ParsedTrack] = field(default_factory=list)
    notes: list[NoteSpan] = field(default_factory=list)
    tempos: list[tuple[int, float]] = field(default_factory=list)
    time_signatures: list[tuple[int, int, int]] = field(default_factory=list)
    last_tick: int = 0


@dataclass
class ChartOptions:
    grid: int = 1
    offset: int = 0
    lane_map: list[tuple[int, int, int]] | None = None
    min_pitch: int | None = None
    max_pitch: int | None = None
    min_velocity: int = 1
    channels: set[int] | None = None
    tracks: set[int] | None = None
    include_drums: bool = False


def parse_lane(value: str) -> int:
    text = value.strip().lower()
    if text in LANE_NAMES:
        return LANE_NAMES.index(text)
    lane = int(text)
    if not 0 <= lane < len(LANE_NAMES):
        raise ValueError(f"lane {lane} is outside 0-3")
    return lane


def parse_lane_map(spec: str) -> list[tuple[int, int, int]]:
    ranges: list[tuple[int, int, int]] = []
    for entry in spec.split(","):
        entry = entry.strip()
        if not entry:
            continue
        try:
            pitch_part, lane_part = entry.rsplit(":", 1)
        except ValueError as error:
            raise ValueError(f"invalid lane map entry '{entry}'") from error
        pitch_part = pitch_part.strip()
        if "-" in pitch_part:
            low_text, high_text = pitch_part.split("-", 1)
            low, high = int(low_text), int(high_text)
        else:
            low = high = int(pitch_part)
        if low > high:
            low, high = high, low
        ranges.append((low, high, parse_lane(lane_part)))
    if not ranges:
        raise ValueError("lane map is empty")
    ranges.sort(key=lambda item: item[0])
    return ranges


def parse_int_set(spec: str | None) -> set[int] | None:
    if spec is None:
        return None
    values = {int(part) for part in spec.split(",") if part.strip()}
    if not values:
        return None
    if min(values) < 1:
        raise ValueError("track and channel numbers start at 1")
    return values


def resolve_lane(ranges: list[tuple[int, int, int]], pitch: int) -> int:
    for low, high, lane in ranges:
        if low <= pitch <= high:
            return lane
    if pitch < ranges[0][0]:
        return ranges[0][2]
    return ranges[-1][2]


def build_default_lane_map(pitches: set[int]) -> list[tuple[int, int, int]]:
    ordered = sorted(pitches)
    if not ordered:
        return []
    lane_for: dict[int, int] = {}
    if len(ordered) <= len(AUTO_LANE_ORDER):
        for index, pitch in enumerate(ordered):
            lane_for[pitch] = AUTO_LANE_ORDER[index]
    else:
        for index, pitch in enumerate(ordered):
            group = min(len(AUTO_LANE_ORDER) - 1, index * len(AUTO_LANE_ORDER) // len(ordered))
            lane_for[pitch] = AUTO_LANE_ORDER[group]
    ranges: list[tuple[int, int, int]] = []
    for pitch in ordered:
        lane = lane_for[pitch]
        if ranges and ranges[-1][2] == lane and ranges[-1][1] == pitch - 1:
            ranges[-1] = (ranges[-1][0], pitch, lane)
        else:
            ranges.append((pitch, pitch, lane))
    return ranges


def read_vlq(data: bytes, position: int) -> tuple[int, int]:
    value = 0
    while True:
        if position >= len(data):
            raise MidiError("truncated variable-length quantity")
        byte = data[position]
        position += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, position


def parse_track(data: bytes, track_index: int, midi: MidiFile) -> None:
    track = ParsedTrack(index=track_index)
    midi.tracks.append(track)
    position = 0
    tick = 0
    running_status: int | None = None
    open_notes: dict[tuple[int, int], list[NoteSpan]] = {}

    def close_open(channel: int, pitch: int, end_tick: int) -> None:
        stack = open_notes.get((channel, pitch))
        if not stack:
            return
        note = stack.pop(0)
        note.end_tick = max(note.start_tick, end_tick)
        midi.notes.append(note)
        track.note_count += 1

    def close_stack(stack: list[NoteSpan], end_tick: int) -> None:
        for note in stack:
            note.end_tick = max(note.start_tick, end_tick)
            midi.notes.append(note)
            track.note_count += 1

    while position < len(data):
        delta, position = read_vlq(data, position)
        tick += delta
        if position >= len(data):
            break
        byte = data[position]
        if byte & 0x80:
            status = byte
            position += 1
            if status < 0xF0:
                running_status = status
        else:
            if running_status is None:
                raise MidiError(f"track {track_index + 1} starts with data but no status byte")
            status = running_status

        if status == 0xFF:
            if position >= len(data):
                break
            meta_type = data[position]
            position += 1
            length, position = read_vlq(data, position)
            body = data[position:position + length]
            position += length
            if meta_type == 0x03 and body:
                track.name = body.decode("latin-1", errors="replace").strip()
            elif meta_type == 0x51 and len(body) >= 3:
                microseconds = int.from_bytes(body[:3], "big")
                if microseconds > 0:
                    midi.tempos.append((tick, 60_000_000.0 / microseconds))
            elif meta_type == 0x58 and len(body) >= 2:
                midi.time_signatures.append((body[0], 2 ** body[1], tick))
            elif meta_type == 0x2F:
                break
            running_status = None
            continue

        if status in (0xF0, 0xF7):
            length, position = read_vlq(data, position)
            position += length
            running_status = None
            continue

        if status >= 0xF0:
            extra = {0xF1: 1, 0xF2: 2, 0xF3: 1}.get(status, 0)
            position += extra
            running_status = None
            continue

        event_type = status & 0xF0
        channel = status & 0x0F
        first = data[position] if position < len(data) else 0
        second = data[position + 1] if position + 1 < len(data) else 0

        if event_type in (0x80, 0x90):
            position += 2
            pitch = first & 0x7F
            velocity = second & 0x7F
            if event_type == 0x90 and velocity > 0:
                stack = open_notes.setdefault((channel, pitch), [])
                while stack:
                    close_open(channel, pitch, tick)
                stack.append(NoteSpan(tick, tick, pitch, velocity, channel, track_index))
            else:
                close_open(channel, pitch, tick)
        elif event_type in (0xA0, 0xB0, 0xE0):
            position += 2
        elif event_type in (0xC0, 0xD0):
            position += 1
        else:
            raise MidiError(f"unsupported status byte 0x{status:02X} in track {track_index + 1}")
    midi.last_tick = max(midi.last_tick, tick)
    for stack in open_notes.values():
        close_stack(stack, tick)


def parse_midi(data: bytes) -> MidiFile:
    if len(data) < 14 or data[:4] != b"MThd":
        raise MidiError("not a Standard MIDI File (missing MThd header)")
    header_length = struct.unpack(">I", data[4:8])[0]
    if header_length < 6:
        raise MidiError("invalid MIDI header length")
    file_format, track_count, division = struct.unpack(">HHH", data[8:14])
    if division & 0x8000:
        raise MidiError("SMPTE time division is not supported; use ticks per quarter note")
    if division == 0:
        raise MidiError("MIDI file has zero ticks per quarter note")
    midi = MidiFile(ppq=division, format=file_format)
    position = 8 + header_length
    parsed = 0
    while position + 8 <= len(data):
        chunk_type = data[position:position + 4]
        chunk_length = struct.unpack(">I", data[position + 4:position + 8])[0]
        body_start = position + 8
        body_end = body_start + chunk_length
        if body_end > len(data):
            raise MidiError("truncated MIDI chunk")
        if chunk_type == b"MTrk":
            parse_track(data[body_start:body_end], parsed, midi)
            parsed += 1
        position = body_end
    if parsed == 0:
        raise MidiError("MIDI file contains no tracks")
    if track_count and parsed != track_count:
        print(
            f"warning: header declares {track_count} tracks but {parsed} were found",
            file=sys.stderr,
        )
    return midi


def snap_beats(ticks: int, ppq: int, grid: int) -> int:
    return int(math.floor(ticks / ppq / grid + 0.5)) * grid


def build_chart(
    midi: MidiFile, options: ChartOptions
) -> tuple[list[list[int]], dict[str, object]]:
    selected: list[NoteSpan] = []
    for note in midi.notes:
        if options.tracks is not None and note.track + 1 not in options.tracks:
            continue
        if options.channels is not None and note.channel + 1 not in options.channels:
            continue
        if note.channel == DRUM_CHANNEL and not options.include_drums:
            continue
        if note.velocity < options.min_velocity:
            continue
        if options.min_pitch is not None and note.pitch < options.min_pitch:
            continue
        if options.max_pitch is not None and note.pitch > options.max_pitch:
            continue
        selected.append(note)

    if not selected:
        raise MidiError("no notes matched the selected tracks, channels, and filters")

    pitches = {note.pitch for note in selected}
    ranges = options.lane_map if options.lane_map is not None else build_default_lane_map(pitches)

    events: list[tuple[int, int, int]] = []
    for note in selected:
        start = snap_beats(note.start_tick, midi.ppq, options.grid)
        end = snap_beats(note.end_tick, midi.ppq, options.grid)
        length = max(1, end - start)
        events.append((start, note.pitch, length))
    events.sort(key=lambda item: (item[0], item[1]))

    free_beat = [0, 0, 0, 0]
    placed: list[list[int]] = []
    dropped = 0
    for start, pitch, length in events:
        ideal = resolve_lane(ranges, pitch)
        chosen: int | None = None
        for step in range(len(LANE_NAMES)):
            candidate = (ideal + step) % len(LANE_NAMES)
            if start >= free_beat[candidate]:
                chosen = candidate
                break
        if chosen is None:
            dropped += 1
            continue
        free_beat[chosen] = start + length
        beat = max(0, start + options.offset)
        placed.append([beat, chosen, length])

    placed.sort(key=lambda row: (row[0], row[1]))
    lane_counts = [0, 0, 0, 0]
    for row in placed:
        lane_counts[row[1]] += 1
    stats: dict[str, object] = {
        "candidate_notes": len(selected),
        "placed_notes": len(placed),
        "dropped_notes": dropped,
        "lane_counts": lane_counts,
        "first_beat": placed[0][0] if placed else 0,
        "last_beat": placed[-1][0] + placed[-1][2] if placed else 0,
        "pitch_range": (min(pitches), max(pitches)),
    }
    return placed, stats


def format_chart(rows: list[list[int]]) -> str:
    if not rows:
        return "[]\n"
    body = ",\n".join(f"  [{beat}, {lane}, {length}]" for beat, lane, length in rows)
    return "[\n" + body + "\n]\n"


def tempo_summary(midi: MidiFile) -> tuple[float | None, float | None, bool]:
    if not midi.tempos:
        return None, None, False
    values = [bpm for _, bpm in midi.tempos]
    distinct = {round(bpm, 3) for bpm in values}
    return min(values), max(values), len(distinct) > 1


def track_rows(midi: MidiFile) -> list[tuple[int, str, int]]:
    rows = []
    for track in midi.tracks:
        rows.append((track.index + 1, track.name or "(unnamed)", track.note_count))
    return rows


def write_chart(path: Path, rows: list[list[int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(format_chart(rows), encoding="utf-8")


def project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def default_output(midi_path: Path) -> Path:
    charts = project_root() / "charts"
    if charts.is_dir():
        return charts / f"{midi_path.stem}.json"
    return midi_path.with_suffix(".json")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert a MIDI file into an Underworld Tour chart JSON.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Lane maps accept pitch ranges and either lane numbers or names, e.g.\n"
            '  "36-47:down,48-59:left,60-71:right,72-127:up"\n'
            "When no lane map is given, pitches are split into four groups by pitch\n"
            "order and mapped low to high as down, left, right, up."
        ),
    )
    parser.add_argument("midi", type=Path, help="input .mid or .midi file")
    parser.add_argument("-o", "--output", type=Path, help="output chart path")
    parser.add_argument(
        "--grid",
        type=int,
        default=1,
        help="whole-beat quantization grid (default: 1)",
    )
    parser.add_argument(
        "--offset",
        type=int,
        default=0,
        help="beats to add to every note after quantization (default: 0)",
    )
    parser.add_argument("--lane-map", help="pitch range to lane map")
    parser.add_argument("--min-pitch", type=int, help="lowest MIDI pitch to include")
    parser.add_argument("--max-pitch", type=int, help="highest MIDI pitch to include")
    parser.add_argument(
        "--min-velocity",
        type=int,
        default=1,
        help="drop notes quieter than this MIDI velocity (default: 1)",
    )
    parser.add_argument(
        "--tracks",
        help="comma separated 1-based track numbers to include (default: all)",
    )
    parser.add_argument(
        "--channels",
        help="comma separated 1-based MIDI channels to include (default: all)",
    )
    parser.add_argument(
        "--include-drums",
        action="store_true",
        help="include MIDI channel 10 percussion",
    )
    parser.add_argument(
        "--bpm",
        type=float,
        help="expected song BPM, used to warn about mismatched MIDI tempo",
    )
    parser.add_argument(
        "--list-tracks",
        action="store_true",
        help="print MIDI track numbers and note counts, then exit",
    )
    parser.add_argument(
        "--info",
        action="store_true",
        help="print tempo, time signature, and track information",
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="suppress the summary")
    return parser


def validate_args(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    if args.grid < 1:
        parser.error("--grid must be a whole number of beats, at least 1")
    if args.min_velocity < 1:
        parser.error("--min-velocity must be at least 1")
    try:
        args.track_set = parse_int_set(args.tracks)
        args.channel_set = parse_int_set(args.channels)
        args.lane_ranges = parse_lane_map(args.lane_map) if args.lane_map else None
    except ValueError as error:
        parser.error(str(error))
    if args.channel_set is not None and max(args.channel_set) > 16:
        parser.error("MIDI channels are numbered 1 through 16")


def print_info(midi: MidiFile) -> None:
    print(f"ticks per quarter note: {midi.ppq}")
    low, high, changes = tempo_summary(midi)
    if low is None:
        print("tempo: not specified in the MIDI file")
    elif changes:
        print(f"tempo: starts at {midi.tempos[0][1]:.2f} BPM, changes over the song")
    else:
        print(f"tempo: {low:.2f} BPM")
    if midi.time_signatures:
        numerator, denominator, _ = midi.time_signatures[0]
        print(f"time signature: {numerator}/{denominator}")
    print("tracks:")
    for index, name, count in track_rows(midi):
        print(f"  {index}: {name} ({count} notes)")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    validate_args(parser, args)

    midi_path: Path = args.midi
    if not midi_path.is_file():
        parser.error(f"MIDI file not found: {midi_path}")
    try:
        midi = parse_midi(midi_path.read_bytes())
    except (MidiError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if args.list_tracks:
        for index, name, count in track_rows(midi):
            print(f"{index}: {name} ({count} notes)")
        return 0
    if args.info:
        print_info(midi)

    options = ChartOptions(
        grid=args.grid,
        offset=args.offset,
        lane_map=args.lane_ranges,
        min_pitch=args.min_pitch,
        max_pitch=args.max_pitch,
        min_velocity=args.min_velocity,
        channels=args.channel_set,
        tracks=args.track_set,
        include_drums=args.include_drums,
    )
    try:
        rows, stats = build_chart(midi, options)
    except MidiError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    output = args.output or default_output(midi_path)
    write_chart(output, rows)

    low, high, changes = tempo_summary(midi)
    warnings: list[str] = []
    if changes:
        warnings.append(
            "MIDI tempo changes over the song; the chart assumes a constant tempo"
        )
    if args.bpm is not None and low is not None:
        if changes or abs(low - args.bpm) > 0.5:
            warnings.append(
                f"MIDI tempo is {low:.2f} BPM but --bpm expects {args.bpm:.2f}; "
                "ensure the Conductor BPM matches the audio"
            )
    first_beat = stats["first_beat"]
    if isinstance(first_beat, int) and first_beat < DEFAULT_LEAD_IN:
        warnings.append(
            f"first note lands on beat {first_beat}; the chart may feel abrupt. "
            f"Use --offset {DEFAULT_LEAD_IN} if the audio has a {DEFAULT_LEAD_IN}-beat lead-in."
        )
    if stats["dropped_notes"]:
        warnings.append(
            f"dropped {stats['dropped_notes']} notes that collided with an occupied lane"
        )

    if not args.quiet:
        lane_counts = stats["lane_counts"]
        print(f"wrote {output}")
        print(
            f"notes: {stats['placed_notes']} of {stats['candidate_notes']} "
            f"(lanes up={lane_counts[0]} right={lane_counts[1]} "
            f"down={lane_counts[2]} left={lane_counts[3]})"
        )
        print(f"beats: {stats['first_beat']} to {stats['last_beat']}")
        for message in warnings:
            print(f"warning: {message}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
