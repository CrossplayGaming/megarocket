# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""Find a process's window and post key presses to it without needing focus (Windows only)."""

import ctypes
import time
from ctypes import wintypes

user32 = ctypes.WinDLL("user32", use_last_error=True)

WM_CLOSE = 0x0010
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101

# Virtual key, scancode
KEYS = {
    "ctrl": (0x11, 0x1D),
    "alt": (0x12, 0x38),
    "enter": (0x0D, 0x1C),
    "space": (0x20, 0x39),
    "esc": (0x1B, 0x01),
    "f1": (0x70, 0x3B),
    "f2": (0x71, 0x3C),
    "f3": (0x72, 0x3D),
    "f4": (0x73, 0x3E),
    "f5": (0x74, 0x3F),
    "f6": (0x75, 0x40),
    "f7": (0x76, 0x41),
    "f8": (0x77, 0x42),
    "f9": (0x78, 0x43),
    "f10": (0x79, 0x44),
    "f11": (0x7A, 0x57),
    "f12": (0x7B, 0x58),
    "up": (0x26, 0x48),
    "down": (0x28, 0x50),
    "left": (0x25, 0x4B),
    "right": (0x27, 0x4D),
    # the keypad (Num Lock's virtual keys, unextended scan codes): more spare
    # host keys for the oracle runner, SDL's KP_1..KP_0 and KP_PERIOD
    "kp1": (0x61, 0x4F),
    "kp2": (0x62, 0x50),
    "kp3": (0x63, 0x51),
    "kp4": (0x64, 0x4B),
    "kp5": (0x65, 0x4C),
    "kp6": (0x66, 0x4D),
    "kp7": (0x67, 0x47),
    "kp8": (0x68, 0x48),
    "kp9": (0x69, 0x49),
    "kp0": (0x60, 0x52),
    "kpdot": (0x6E, 0x53),
    # letters and digits the Galaxy debug keys need (A+2+Enter, F10+M, F10+Y)
    "a": (0x41, 0x1E), "m": (0x4D, 0x32), "y": (0x59, 0x15), "2": (0x32, 0x03),
    # the Dreams debug warp (F10+W, then the level number)
    "w": (0x57, 0x11), "1": (0x31, 0x02), "3": (0x33, 0x04), "4": (0x34, 0x05), "5": (0x35, 0x06),
    "6": (0x36, 0x07), "7": (0x37, 0x08), "8": (0x38, 0x09), "9": (0x39, 0x0A), "0": (0x30, 0x0B),
}

_EnumWindowsProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]


def windows_of(pid):
    found = []

    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            title = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, title, length + 1)
            found.append((hwnd, title.value))
        return True

    user32.EnumWindows(_EnumWindowsProc(visit), 0)
    return found


def wait_for_window(pid, timeout=30.0):
    end = time.time() + timeout
    while time.time() < end:
        wins = windows_of(pid)
        if wins:
            return wins[0][0]
        time.sleep(0.2)
    return None


def key_down(hwnd, name):
    vk, scan = KEYS[name]
    user32.PostMessageW(hwnd, WM_KEYDOWN, vk, 1 | (scan << 16))


def key_up(hwnd, name):
    vk, scan = KEYS[name]
    user32.PostMessageW(hwnd, WM_KEYUP, vk, 1 | (scan << 16) | (0xC0 << 24))


def tap(hwnd, name, hold=0.15):
    key_down(hwnd, name)
    time.sleep(hold)
    key_up(hwnd, name)


def chord(hwnd, modifier, name, hold=0.15):
    key_down(hwnd, modifier)
    time.sleep(0.05)
    key_down(hwnd, name)
    time.sleep(hold)
    key_up(hwnd, name)
    time.sleep(0.05)
    key_up(hwnd, modifier)


def close(hwnd):
    user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
