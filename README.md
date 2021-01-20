# SceneryStrikeScript

```lua
scenery.config.ZONES = {
    ["Bad Guy Building"]     = 1,
    ["Other Structure"]  = 1,
    ["Storage Tanks"] = 4,
}

scenery.config.POLL_INTERVAL = 600
scenery.config.WRITE_REPORT = true
scenery.config.REPORT_FILENAME = "scenery_strike_report.csv"

scenery.init()
```

## Development

1. Clone this repo
2. Rename `config.example.lua` to `config.lua`
3. Rename `test_mission.example.miz` to `test_mission.miz`
