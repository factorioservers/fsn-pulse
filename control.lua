-- fsn-pulse — https://github.com/factorioservers/fsn-pulse
--
-- Registers exactly one console command, /fsn-pulse, which prints one
-- machine-parseable line with instantaneous timing values. It mutates
-- nothing and registers no event handlers, so it has zero per-tick cost.
--
-- Output contract (parsed by the FactorioServers.com control plane —
-- see README.md before changing anything here):
--
--   FSN-PULSE v1 tick=<uint> speed=<number> paused=<true|false>

local function pulse(command)
  local line = string.format(
    "FSN-PULSE v1 tick=%d speed=%.6g paused=%s",
    game.tick,
    game.speed,
    tostring(game.tick_paused)
  )

  -- Reaches the RCON caller when invoked over RCON; no-op otherwise.
  rcon.print(line)

  -- Echo to the invoking player so anyone in-game can run /fsn-pulse and
  -- see exactly what this mod reports.
  if command.player_index then
    local player = game.get_player(command.player_index)
    if player then
      player.print(line)
    end
  end
end

commands.add_command(
  "fsn-pulse",
  "Print one FSN-PULSE status line (tick, speed, paused) for server monitoring.",
  pulse
)
