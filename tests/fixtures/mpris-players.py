#!/usr/bin/python3
"""Two synthetic MPRIS players, exclusively on the caller's private D-Bus."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
PLAYER = "org.mpris.MediaPlayer2.Player"
ROOT = "org.mpris.MediaPlayer2"
PROPS = "org.freedesktop.DBus.Properties"
calls = []
cycles = int(os.environ.get("OMADECK_MPRIS_CYCLES", "1"))
completed = 0
connected = 0
resources = []


class Player(dbus.service.Object):
    def __init__(self, label):
        global connected
        connected += 1
        self.label = label
        self.bus = dbus.SessionBus(private=True)
        self.bus.set_exit_on_disconnect(False)
        self.name = dbus.service.BusName(ROOT + ".fixture" + label, self.bus)
        super().__init__(self.name, "/org/mpris/MediaPlayer2")
        self.playing = True
        self.controllable = True

    def properties(self, interface):
        if interface == ROOT:
            return dict(Identity="Fixture " + self.label, DesktopEntry="fixture" + self.label,
                        CanQuit=True, CanRaise=False, HasTrackList=False,
                        SupportedUriSchemes=dbus.Array([], signature="s"),
                        SupportedMimeTypes=dbus.Array([], signature="s"))
        if interface == PLAYER:
            return dict(PlaybackStatus="Playing" if self.playing else "Paused",
                        CanControl=self.controllable, CanPlay=self.controllable,
                        CanPause=self.controllable, CanGoNext=self.controllable,
                        CanGoPrevious=False, CanSeek=False, Rate=1.0,
                        MinimumRate=1.0, MaximumRate=1.0, Volume=1.0,
                        Position=dbus.Int64(42000000),
                        Metadata=dbus.Dictionary({"xesam:title": "Fixture " + self.label,
                            "mpris:trackid": dbus.ObjectPath("/fixture/" + self.label),
                            "mpris:length": dbus.Int64(180000000)}, signature="sv"))
        return {}

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.properties(interface)

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.properties(interface)[name]

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.method(PLAYER)
    def Pause(self):
        calls.append([self.label, "Pause"])
        self.playing = False
        self.controllable = False
        self.PropertiesChanged(PLAYER, self.properties(PLAYER), [])

    @dbus.service.method(PLAYER)
    def Next(self):
        calls.append([self.label, "Next"])

    @dbus.service.method(ROOT)
    def Quit(self):
        calls.append([self.label, "Quit"])
        GLib.idle_add(self.disconnect)

    def disconnect(self):
        self.remove_from_connection()
        self.bus.close()
        global connected, completed
        connected -= 1
        if connected == 0:
            completed += 1
            if completed < cycles:
                GLib.timeout_add(150, respawn)
        return False


def respawn():
    global players
    resources.append({
        "cycle": completed,
        "fixtureFds": len(list(Path("/proc/self/fd").iterdir())),
        "shellFds": len(list(Path(f"/proc/{child.pid}/fd").iterdir())),
        "shellChildren": Path(f"/proc/{child.pid}/task/{child.pid}/children").read_text().split(),
    })
    players = [Player("A"), Player("B")]
    return False


players = [Player("A"), Player("B")]
child = subprocess.Popen(["/usr/bin/qs", "--no-color", "-p", sys.argv[1]],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
loop = GLib.MainLoop()
deadline = time.monotonic() + max(12, cycles * 0.8)


def poll():
    if child.poll() is not None or time.monotonic() > deadline:
        if child.poll() is None:
            child.kill()
        loop.quit()
        return False
    return True


GLib.timeout_add(50, poll)
try:
    loop.run()
finally:
    if child.poll() is None:
        child.kill()
    output, _ = child.communicate(timeout=2)
print(output)
print("MPRIS_CALLS " + json.dumps(calls))
print("MPRIS_RESOURCES " + json.dumps(resources))
sys.exit(child.returncode)
