"""The bridge to a graphical client (bridge/server.py): one client, one game, JSON lines both ways."""
import json
import socket
import tempfile
import threading
import unittest
from pathlib import Path

from bridge.server import Session, encode, _whole


class Client:
    def __init__(self, sock: socket.socket):
        self.sock = sock
        self.file = sock.makefile("rwb")

    def send(self, **data):
        self.file.write((json.dumps(data) + "\n").encode("utf-8"))
        self.file.flush()

    def read(self):
        line = self.file.readline()
        return json.loads(line) if line else None

    def until(self, kind: str, limit: int = 4000):
        """The next message of this kind (others are skipped)."""
        for _ in range(limit):
            m = self.read()
            if m is None:
                break
            if m["type"] == kind:
                return m
        raise AssertionError(f"no '{kind}' message arrived")


class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.save = Path(self.folder.name) / "save.json"
        ours, theirs = socket.socketpair()
        ours.settimeout(60)
        self.client = Client(ours)
        self.theirs = theirs
        self.session = Session(theirs, self.save, seed=3, speed=0)
        self.thread = threading.Thread(target=self.session.run, daemon=True)
        self.thread.start()

    def tearDown(self):
        try:
            self.client.send(cmd="quit")
        except OSError:
            pass
        self.thread.join(timeout=30)
        self.client.file.close()
        self.client.sock.close()
        self.theirs.close()
        self.folder.cleanup()

    def test_a_whole_session(self):
        c = self.client
        hello = c.until("hello")
        self.assertIsNone(hello["save"])
        self.assertEqual(len(hello["map"]["rows"]), hello["map"]["height"])
        self.assertIn("fire", hello["map"]["spots"])
        self.assertIn("food", hello["character"]["needs"])
        self.assertTrue(hello["items"] and hello["action_kinds"])

        c.send(cmd="start", new=True, seed=3)
        self.assertFalse(c.until("started")["continued"])
        state = c.until("state")
        view, ui = state["view"], state["ui"]
        self.assertEqual(view["you"], "Alice")
        self.assertTrue(view["map"]["people"])
        self.assertEqual({g["type"] for g in ui["groups"]}, {k["type"] for k in hello["action_kinds"]})
        self.assertTrue(ui["innovations"])
        self.assertIn("speed", ui["pacer"])

        c.send(cmd="pause", on=True)                      # hold the clock still while we choose
        c.send(cmd="menu", kind="care")
        menu = c.until("menu")
        self.assertEqual(menu["kind"], "care")
        if "menu" in menu:                                # free to act: the picker, every item with its action
            item = menu["menu"]["items"][0]
            self.assertIn("type", item["action"])
        else:
            self.assertTrue(menu["unavailable"])

        c.send(cmd="act", action={"type": "sort_items", "params": {}})   # a quick action made by the client
        self.assertTrue(c.until("result")["ok"])

        c.send(cmd="crafts")
        crafts = c.until("crafts")
        self.assertTrue(crafts["rows"] and crafts["rows"][0]["detail"])

        c.send(cmd="quit")
        bye = c.until("bye")
        self.assertEqual(bye["reason"], "saved")
        self.assertTrue(self.save.exists())

    def test_numbers_and_odd_values_survive_the_wire(self):
        self.assertEqual(_whole({"slot": 3.0, "give": [{"count": 2.0, "share": 0.5}]}),
                         {"slot": 3, "give": [{"count": 2, "share": 0.5}]})
        sent = json.loads(encode({"type": "x", "far": float("inf"), "names": {"b", "a"}}))
        self.assertIsNone(sent["far"])
        self.assertEqual(sent["names"], ["a", "b"])


if __name__ == "__main__":
    unittest.main()
