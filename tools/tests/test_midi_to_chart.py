from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import midi_to_chart as tool


def vlq(value: int) -> bytes:
    out = bytearray([value & 0x7F])
    value >>= 7
    while value:
        out.insert(0, 0x80 | (value & 0x7F))
        value >>= 7
    return bytes(out)


def make_track(events: list[tuple[int, bytes]]) -> bytes:
    body = b"".join(vlq(delta) + payload for delta, payload in events)
    return b"MTrk" + struct.pack(">I", len(body)) + body


def make_midi(tracks: list[bytes], ppq: int = 480, file_format: int = 1) -> bytes:
    header = b"MThd" + struct.pack(">IHHH", 6, file_format, len(tracks), ppq)
    return header + b"".join(tracks)


def note_track(notes: list[tuple[int, int, int]], channel: int = 0) -> bytes:
    events: list[tuple[int, bytes]] = []
    current = 0
    absolute: list[tuple[int, int, int, bool, int]] = []
    for start, pitch, duration in notes:
        absolute.append((start, pitch, 0, True, 100))
        absolute.append((start + duration, pitch, 0, False, 0))
    absolute.sort(key=lambda item: (item[0], item[3]))
    for tick, pitch, _velocity, is_on, velocity in absolute:
        status = 0x90 if is_on else 0x80
        events.append((tick - current, bytes([status | channel, pitch, velocity])))
        current = tick
    events.append((0, b"\xff\x2f\x00"))
    return make_track(events)


class ParseTests(unittest.TestCase):
    def test_reads_notes_and_timing(self) -> None:
        midi = tool.parse_midi(make_midi([note_track([(0, 60, 480), (480, 64, 960)])]))
        self.assertEqual(midi.ppq, 480)
        self.assertEqual(len(midi.notes), 2)
        first, second = sorted(midi.notes, key=lambda note: note.start_tick)
        self.assertEqual((first.start_tick, first.end_tick, first.pitch), (0, 480, 60))
        self.assertEqual((second.start_tick, second.end_tick, second.pitch), (480, 1440, 64))

    def test_running_status(self) -> None:
        track = make_track(
            [
                (0, bytes([0x90, 60, 100])),
                (0, bytes([64, 100])),
                (480, bytes([64, 0])),
                (0, bytes([60, 0])),
                (0, b"\xff\x2f\x00"),
            ]
        )
        midi = tool.parse_midi(make_midi([track], file_format=0))
        self.assertEqual(sorted(note.pitch for note in midi.notes), [60, 64])
        for note in midi.notes:
            self.assertEqual((note.start_tick, note.end_tick), (0, 480))

    def test_tempo_and_track_name(self) -> None:
        track = make_track(
            [
                (0, b"\xff\x03\x04lead"),
                (0, b"\xff\x51\x03" + (500000).to_bytes(3, "big")),
                (0, b"\xff\x2f\x00"),
            ]
        )
        midi = tool.parse_midi(make_midi([track]))
        self.assertEqual(midi.tracks[0].name, "lead")
        self.assertAlmostEqual(midi.tempos[0][1], 120.0)


class ConversionTests(unittest.TestCase):
    def convert(self, notes: list[tuple[int, int, int]], **kwargs) -> list[list[int]]:
        midi = tool.parse_midi(make_midi([note_track(notes)]))
        options = tool.ChartOptions(**kwargs)
        rows, _stats = tool.build_chart(midi, options)
        return rows

    def test_taps_and_holds(self) -> None:
        rows = self.convert([(0, 60, 480), (480, 62, 1440)], lane_map=[(0, 127, 2)])
        self.assertEqual(rows, [[0, 2, 1], [1, 2, 3]])

    def test_quantizes_to_whole_beats(self) -> None:
        rows = self.convert([(300, 60, 300)], lane_map=[(0, 127, 0)])
        self.assertEqual(rows, [[1, 0, 1]])

    def test_snaps_holds_and_enforces_minimum_length(self) -> None:
        rows = self.convert([(0, 60, 120), (960, 62, 1000)], lane_map=[(0, 127, 1)])
        self.assertEqual(rows, [[0, 1, 1], [2, 1, 2]])

    def test_collisions_fall_through_to_free_lanes(self) -> None:
        rows = self.convert(
            [(0, 60, 480), (0, 64, 480), (0, 67, 480)], lane_map=[(0, 127, 0)]
        )
        self.assertEqual(rows, [[0, 0, 1], [0, 1, 1], [0, 2, 1]])

    def test_overlapping_hold_blocks_lane(self) -> None:
        rows = self.convert(
            [(0, 60, 1920), (480, 64, 480)], lane_map=[(0, 127, 0)]
        )
        self.assertEqual(rows, [[0, 0, 4], [1, 1, 1]])

    def test_offset_applies_after_placement(self) -> None:
        rows = self.convert([(0, 60, 480)], lane_map=[(0, 127, 0)], offset=4)
        self.assertEqual(rows, [[4, 0, 1]])

    def test_filters(self) -> None:
        midi = tool.parse_midi(
            make_midi([note_track([(0, 40, 480), (480, 60, 480)])])
        )
        rows, _ = tool.build_chart(
            midi, tool.ChartOptions(lane_map=[(0, 127, 0)], min_pitch=50)
        )
        self.assertEqual([row[0] for row in rows], [1])

    def test_velocity_filter(self) -> None:
        midi = tool.parse_midi(make_midi([note_track([(0, 60, 480)])]))
        with self.assertRaises(tool.MidiError):
            tool.build_chart(
                midi,
                tool.ChartOptions(lane_map=[(0, 127, 0)], min_velocity=110),
            )

    def test_auto_lane_map_spans_pitch_order(self) -> None:
        pitches = {40, 50, 60, 70, 80, 90, 100, 110}
        ranges = tool.build_default_lane_map(pitches)
        low = tool.resolve_lane(ranges, 40)
        high = tool.resolve_lane(ranges, 110)
        self.assertEqual(low, tool.AUTO_LANE_ORDER[0])
        self.assertEqual(high, tool.AUTO_LANE_ORDER[-1])

    def test_drum_channel_is_excluded_by_default(self) -> None:
        midi = tool.parse_midi(
            make_midi(
                [
                    note_track([(0, 60, 480)]),
                    note_track([(0, 36, 480)], channel=tool.DRUM_CHANNEL),
                ]
            )
        )
        rows, _ = tool.build_chart(
            midi, tool.ChartOptions(lane_map=[(0, 127, 0)])
        )
        self.assertEqual(rows, [[0, 0, 1]])
        rows, _ = tool.build_chart(
            midi,
            tool.ChartOptions(lane_map=[(0, 127, 0)], include_drums=True),
        )
        self.assertEqual(len(rows), 2)


class LaneMapTests(unittest.TestCase):
    def test_parses_numbers_and_names(self) -> None:
        ranges = tool.parse_lane_map("36-47:down, 48-59:3, 60:1")
        self.assertEqual(
            ranges, [(36, 47, 2), (48, 59, 3), (60, 60, 1)]
        )

    def test_rejects_bad_lane(self) -> None:
        with self.assertRaises(ValueError):
            tool.parse_lane_map("0-127:4")


class FormatTests(unittest.TestCase):
    def test_matches_chart_style(self) -> None:
        text = tool.format_chart([[1, 3, 3], [4, 0, 3]])
        self.assertEqual(text, "[\n  [1, 3, 3],\n  [4, 0, 3]\n]\n")

    def test_output_is_parseable_json(self) -> None:
        import json

        rows = [[1, 0, 1], [2, 3, 2]]
        self.assertEqual(json.loads(tool.format_chart(rows)), rows)


class CliTests(unittest.TestCase):
    def test_end_to_end(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            midi_path = Path(directory) / "song.mid"
            output_path = Path(directory) / "song.json"
            midi_path.write_bytes(
                make_midi([note_track([(0, 60, 480), (480, 64, 960)])])
            )
            code = tool.main(
                [
                    str(midi_path),
                    "-o",
                    str(output_path),
                    "--lane-map",
                    "0-127:up",
                    "--offset",
                    "4",
                    "-q",
                ]
            )
            self.assertEqual(code, 0)
            self.assertEqual(
                output_path.read_text(), "[\n  [4, 0, 1],\n  [5, 0, 2]\n]\n"
            )


if __name__ == "__main__":
    unittest.main()
