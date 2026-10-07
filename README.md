# SR1_Console

Developer console with keyboard typing for Saints Row 1 (via Saints Reborn recompile).

Press **~** (tilde) to open the console, type your command, then press **Enter**. Press **~** again to close.

## Console Commands

A full list of available console commands is available at:

https://fl1ppy.com/files/games/saintsrow/sr1commands.txt

## Installation

1. Extract the `SR1_Console` folder into your `dist\mods` directory (the one containing `WhompaysModLoader.exe`).
2. Run `WhompaysModLoader.exe`, tick **SR1_Console**, and press **Play**.

   Alternatively, add `+SR1_Console` to `dist\mods\modlist.ini`.

3. Launch the game in **single-player** or a **private party**. The console does not work in public matchmaking.

## How to Activate In-Game

1. Start a single-player game (or create a private party).
2. Press **~** (tilde, above Tab) to open the developer console.
3. Type a command and press **Enter**.
4. Press **~** again to close.

The console byte is toggled directly at `0x83710223`, so there is no lag or delay — keys are forwarded to the game as real input events.

## Changing the Keybind

The toggle key is set in `mod.ini` under the `[settings]` section:

```ini
[settings]
key = ~
```

You can set it to:

- A **key name** the loader recognises (e.g. `"F8"`, `"F9"`, `"SPACE"`).
- A **decimal virtual-key code** (e.g. `121` for F8).
- The literal **`~`** string, which is mapped to `VK_OEM_3` (0xC0).

### Common key codes

| Key | VK code |
|-----|---------|
| `~` (tilde) | `~` or `192` |
| `F8` | `F8` or `119` |
| `F9` | `F9` or `120` |
| `F10` | `F10` or `121` |

## How It Works

This mod merges two previous standalone mods — **Console Toggle** and **Console Keyboard (stage 2)** — into a single drop-in.

- **Toggle**: writes `1`/`0` to the console flag byte each time the toggle key is pressed. The byte is read and inverted (not a local counter), so external changes to the byte (e.g. from Whompays Trainer's menu) stay in sync.
- **Keystroke forwarding**: three hooks are installed:
  - `sub_82648ED8` (parent) — after the game runs its normal keystroke reader each frame, the mod also calls `sub_82649B78` (the reader) so queued keystrokes are consumed.
  - `sub_827166F8` (poller) — intercepts the `XamInputGetKeystrokeEx` wrapper and feeds real keyboard events (VirtualKey + flags) instead of "device not connected."
  - While the console is open, typing keys (A–Z, 0–9, numpad, and common editing keys) are taken from the normal movement controls so WASD doesn't move you.
