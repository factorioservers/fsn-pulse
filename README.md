# FSN Pulse

A deliberately tiny Factorio mod that powers the UPS graphs on
[FactorioServers.com](https://factorioservers.com). It registers **one console
command**, `/fsn-pulse`, which prints **one line** of instantaneous timing
values — and does nothing else.

This repo is public on purpose: if this mod runs on your server, you can read
every line of code it ships (there is exactly one Lua file,
[`control.lua`](control.lua), ~40 lines) and verify what it does and does not
do.

## Why this exists

To graph a server's UPS you sample `game.tick` twice and compute
Δticks / Δseconds. The obvious way — sending raw Lua over RCON with `/sc` —
**permanently disables achievements** for the save. Commands registered by a
mod, however, are achievement-safe to *execute*. So this mod's entire job is
to register one such command; our control plane calls it over RCON roughly
every 30 seconds and does all the math on its side.

### The achievements trade-off, honestly

Running *any* mod (including this one) moves the save onto the
**modded-achievements** track: you keep earning achievements in-game, but they
count separately from vanilla achievements and don't sync to Steam. That is a
Factorio platform rule, not something this mod can avoid. What this mod *does*
avoid is the strictly worse outcome of `/sc` sampling, which disables
achievements outright. FactorioServers.com discloses this trade-off in its UI.

## What it does

On load, `control.lua` registers the `/fsn-pulse` command. When invoked, it
prints one line via `rcon.print` (and echoes the same line to you if you run
it as a player in-game, so you can see exactly what gets reported).

### Output contract (v2)

This line is a versioned contract consumed by the FactorioServers.com sampler.
Format changes will bump the version token (`v2`), never silently change it.

```
FSN-PULSE v2 tick=<uint> speed=<number> paused=<true|false> players=<uint>
```

| Field     | Source                    | Meaning                                                       |
| --------- | ------------------------- | ------------------------------------------------------------- |
| `tick`    | `game.tick`               | Current map tick (integer, monotonically increasing at 60/s at speed 1.0 when not paused) |
| `speed`   | `game.speed`              | Configured game-speed multiplier (`1` = normal; formatted with `%.6g`, so e.g. `1`, `0.5`) |
| `paused`  | `game.tick_paused`        | Whether the explicit tick-pause flag is set (`true`/`false`) — see the warning below |
| `players` | `#game.connected_players` | Number of players currently online                             |

Example:

```
FSN-PULSE v2 tick=123456 speed=1 paused=false players=3
```

**⚠️ `paused` does NOT detect auto-pause.** It reflects only the explicit
`game.tick_paused` flag. A headless server that auto-pauses because it is
empty keeps reporting `paused=false` while the tick is frozen — verified
against production servers. Consumers must never treat `paused=false` as
"the simulation is advancing". That is what `players` is for: the
authoritative idle rule is **Δtick ≈ 0 AND `players=0` → idle/paused
sample, not a UPS dip**. Applying that rule is the consumer's job.

Parsers should anchor on the `FSN-PULSE v2 ` prefix and treat the rest as
space-separated `key=value` pairs; unknown extra pairs in future `v2.x`
outputs must be ignored.

**v1 is superseded.** Mod releases up to 1.0.1 emitted
`FSN-PULSE v1 tick=... speed=... paused=...` (no `players` field). From 1.1.0
the command emits only the v2 line — nothing a parser keyed on the
`FSN-PULSE v1 ` prefix will accept. This is a deliberate clean break on the
version token.

## What it deliberately does NOT do

- **No event handlers.** No `on_tick`, no `script.on_event` of any kind.
  Zero per-tick cost; the mod consumes CPU only in the instant the command runs.
- **No game-state mutation.** It only reads four values.
- **No global/persistent state.** Nothing is stored in the save file.
- **No UI, no gameplay changes, no prototypes.** There is no `data.lua`.
- **No telemetry or data collection.** The mod never sends anything anywhere;
  it only answers when asked, and the answer is the one documented line above.

This scope is a hard ceiling. Features that would grow it belong in the
control plane, not here.

## Installation

Normally you don't install this yourself — FactorioServers.com includes it on
managed servers. To use it elsewhere:

1. Download `fsn-pulse_<version>.zip` from the
   [mod portal](https://mods.factorio.com/mod/fsn-pulse) or this repo's
   [releases](https://github.com/factorioservers/fsn-pulse/releases).
2. Drop it into the server's `mods/` directory and restart.

Requires Factorio **2.x** (`factorio_version` is `"2.0"`). The APIs used
(`commands.add_command`, `game.tick`, `game.speed`, `game.tick_paused`,
`rcon.print`) also exist in 1.1, but the mod portal allows only one major
Factorio version per release — if 1.1 support is ever needed it will live on a
separate `1.1` branch with its own version line.

## Development

```sh
./scripts/package.sh   # builds dist/fsn-pulse_<version>.zip (portal-ready)
./tests/smoke.sh       # docker headless server + RCON round-trip contract test
```

The smoke test starts `factoriotools/factorio` in Docker with the freshly
built zip, waits for RCON, invokes `/fsn-pulse`, and asserts the response
matches the contract regex. CI runs it on every push and PR; tagging `v<x.y.z>`
(matching `info.json`) builds the zip and attaches it to a GitHub release.
Mod-portal upload is currently manual.

## License

[MIT](LICENSE) © Cinder Logic LLC.
