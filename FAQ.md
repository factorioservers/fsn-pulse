# FSN Pulse — FAQ

*This file is the content of the mod portal's FAQ tab. Source of truth for
technical details is the [README](https://github.com/factorioservers/fsn-pulse).*

## What does this mod actually do?

It registers exactly one console command, `/fsn-pulse`. When the command is
run, the mod prints one line of text with four values the game already knows:
the current tick, the game speed, whether the tick is paused, and how many
players are online:

```
FSN-PULSE v2 tick=123456 speed=1 paused=false players=3
```

That's the whole mod. There is no other code path. It adds no event handlers
(no `on_tick`), stores nothing in your save, changes no prototypes, and never
touches game state. The entire implementation is one Lua file of about 40
lines: https://github.com/factorioservers/fsn-pulse/blob/main/control.lua

## Why is it installed on my server?

If your server is hosted with [FactorioServers.com](https://factorioservers.com),
this mod powers the UPS graph in your control panel. Our management service
calls `/fsn-pulse` over RCON roughly every 30 seconds, samples the tick twice,
and computes UPS from the difference.

## Why not just sample over RCON without a mod?

Sending raw Lua over RCON (`/sc ...`) counts as using script commands and
**permanently disables achievements** for the save. Executing a command that a
mod registers is achievement-safe. This mod exists purely so UPS can be
measured without ruining achievements on your map.

## Does this affect achievements at all?

Honestly: yes, in the way any mod does. With any mod installed (including this
one), Factorio moves the save to the **modded achievements** track — you still
earn achievements in-game, but they're tracked separately from vanilla and
don't sync to Steam. That's a base-game rule no mod can avoid. What this mod
prevents is the strictly worse outcome of `/sc` sampling, which disables
achievements entirely.

## Does it collect data or phone home?

No. The mod cannot make network requests (Factorio mods have no network API),
collects nothing, and stores nothing. It only *answers* when the command is
invoked, and the answer is the one line documented above. You can verify this
yourself: run `/fsn-pulse` in-game and the exact reported line is echoed back
to you.

## Does it cost any performance (UPS)?

No. Because there are no event handlers, the mod consumes zero CPU during
normal play — code only runs in the instant the command is invoked, and that
code reads four values and formats a string.

## Can I remove it?

Yes, at any time — it's a normal mod, and removing it leaves no trace in your
save (the mod stores nothing). Your server's UPS graph on FactorioServers.com
will simply stop updating.

## Can I use it for my own monitoring?

Yes — MIT licensed. Install the mod, then call `/fsn-pulse` over RCON from
your own tooling. Anchor your parser on the `FSN-PULSE v2 ` prefix and treat
the rest as space-separated `key=value` pairs, ignoring unknown keys. Compute
UPS as Δtick / Δseconds between two samples. Note: a headless server with no
players connected auto-pauses without setting `paused=true` (that field only
reflects the explicit tick-pause flag), so classify Δtick ≈ 0 with
`players=0` as "idle", not as a performance problem.

## Does it work on Factorio 1.1?

This release targets Factorio 2.x. The APIs it uses all exist in 1.1, but the
mod portal only allows one major Factorio version per release — if there's
demand, a 1.1 build will be published from a separate branch. Open an issue on
GitHub if you need it.

## I found a bug / have a question not covered here

Open an issue at https://github.com/factorioservers/fsn-pulse/issues — the
project is small on purpose, so reports get looked at quickly. Feature
requests that grow the mod's scope (anything beyond reporting instantaneous
values) will be politely declined; that logic belongs in tooling around the
mod, not in code running on thousands of servers.
