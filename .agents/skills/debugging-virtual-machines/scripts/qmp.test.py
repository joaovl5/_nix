import base64
import importlib.util
import pathlib
import sys
import unittest

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
MODULE_PATH = SCRIPT_DIR / "qmp.py"
SPEC = importlib.util.spec_from_file_location("vm_qmp_skill", MODULE_PATH)
qmp = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
sys.modules[SPEC.name] = qmp
SPEC.loader.exec_module(qmp)


class SerialLogPathTests(unittest.TestCase):
  def test_derives_serial_log_path_from_socket(self) -> None:
    """It derives .serial.log from .qmp sockets."""
    self.assertEqual(
      pathlib.Path("/tmp/demo.serial.log"),
      qmp.derive_serial_log_path(pathlib.Path("/tmp/demo.qmp")),
    )

  def test_derives_serial_log_path_without_qmp_suffix(self) -> None:
    """It appends .serial.log when the socket has another suffix."""
    self.assertEqual(
      pathlib.Path("/tmp/demo.sock.serial.log"),
      qmp.derive_serial_log_path(pathlib.Path("/tmp/demo.sock")),
    )


class KeyMappingTests(unittest.TestCase):
  def test_key_chord_to_send_key_keys(self) -> None:
    """It maps key chords into qcode dictionaries."""
    self.assertEqual(
      [
        {"type": "qcode", "data": "ctrl"},
        {"type": "qcode", "data": "alt"},
        {"type": "qcode", "data": "f9"},
      ],
      qmp.chord_to_keys("ctrl-alt-f9"),
    )

  def test_text_to_events_supports_newline_and_shifted_punctuation(
    self,
  ) -> None:
    """It maps printable text into per-character key events."""
    self.assertEqual(
      [
        [{"type": "qcode", "data": "a"}],
        [
          {"type": "qcode", "data": "shift"},
          {"type": "qcode", "data": "1"},
        ],
        [{"type": "qcode", "data": "ret"}],
      ],
      qmp.text_to_event_keys("a!\n"),
    )

  def test_unsupported_character_fails_clearly(self) -> None:
    """It rejects characters that lack send-key mappings."""
    with self.assertRaisesRegex(ValueError, "Unsupported character"):
      qmp.text_to_event_keys("🙂")


class SerialParsingTests(unittest.TestCase):
  def test_extract_serial_result_ignores_stale_markers(self) -> None:
    """It reads the newest tagged marker block from the serial log."""
    text = "\n".join(
      [
        "VM boot log",
        qmp.marker_line(tag="old", kind="begin"),
        "stale output",
        qmp.marker_line(tag="old", kind="status", value="0"),
        qmp.marker_line(tag="old", kind="end"),
        qmp.marker_line(tag="fresh", kind="begin"),
        "hello ",
        qmp.marker_line(tag="fresh", kind="status", value="7"),
        "world",
        qmp.marker_line(tag="fresh", kind="end"),
      ]
    )
    result = qmp.extract_serial_result(text=text, tag="fresh")
    self.assertEqual("hello \nworld", result.output)
    self.assertEqual(7, result.exit_code)

  def test_extract_serial_result_handles_no_newline_before_status(
    self,
  ) -> None:
    """It parses inline status markers without losing preceding output."""
    tag = "fresh"
    text = "\n".join(
      [
        qmp.marker_line(tag=tag, kind="begin"),
        f"foo{qmp.marker_line(tag=tag, kind='status', value='0')}",
        qmp.marker_line(tag=tag, kind="end"),
      ]
    )
    result = qmp.extract_serial_result(text=text, tag=tag)
    self.assertEqual("foo", result.output)
    self.assertEqual(0, result.exit_code)

  def test_extract_pull_bytes_from_no_newline_serial_output(self) -> None:
    """It decodes base64 payloads without extra line breaks."""
    tag = "fresh"
    payload = base64.b64encode(b"hello\n").decode()
    text = "\n".join(
      [
        qmp.marker_line(tag=tag, kind="begin"),
        f"{payload}{qmp.marker_line(tag=tag, kind='status', value='0')}",
        qmp.marker_line(tag=tag, kind="end"),
      ]
    )
    result = qmp.extract_serial_result(text=text, tag=tag)
    self.assertEqual(
      b"hello\n",
      qmp.extract_pull_bytes(payload_text=result.output),
    )

  def test_strip_ansi_removes_escape_sequences(self) -> None:
    """It strips ANSI sequences from captured serial output."""
    self.assertEqual(
      "plain red text", qmp.strip_ansi("plain \x1b[31mred\x1b[0m text")
    )


class SerialWrapperTests(unittest.TestCase):
  def test_build_serial_bootstrap_command_uses_base64_wrapper(self) -> None:
    """It embeds the wrapper script in the typed bootstrap command."""
    typed_command, script_text = qmp.build_serial_bootstrap_command(
      command="echo 'hi'",
      tag="tag123",
    )
    self.assertIn("base64 -d", typed_command)
    self.assertIn("| /bin/sh", typed_command)
    encoded = typed_command.split("'", 4)[3]
    decoded = base64.b64decode(encoded, validate=True).decode()
    self.assertEqual(script_text, decoded)
    self.assertIn("/bin/sh -lc", script_text)
    self.assertIn(qmp.marker_line(tag="tag123", kind="begin"), script_text)
    self.assertIn(qmp.marker_line(tag="tag123", kind="end"), script_text)
    self.assertIn(qmp.marker_line(tag="tag123", kind="status"), script_text)
    self.assertIn(">/dev/ttyS0 2>&1", script_text)

  def test_decode_pulled_file_data(self) -> None:
    """It decodes plain base64 payloads."""
    payload = qmp.extract_pull_bytes(
      payload_text=base64.b64encode(b"hello\n").decode()
    )
    self.assertEqual(b"hello\n", payload)


if __name__ == "__main__":
  unittest.main()
