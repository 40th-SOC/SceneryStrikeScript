# SceneryStrikeScript

Track the destruction of DCS scenery objects.

## Usage

1. Place a zone on top of an object in the mission editor
2. Specify the zone in the `scenery.config.ZONES` table. See below.
3. Set a number of targets that must be destroyed inside the zone. For example, if there are 4 storage tanks in the zone and `4` is specified, all 4 storage tanks must be destroyed to make the target "dead"

See the `test_mission.example.miz` for an example.

```lua
scenery.config.ZONES = {
    ["Bad Guy Building"] = 1,
    ["Other Structure"] = 1,
    ["Storage Tanks"] = 4,
}

scenery.config.WRITE_REPORT = true
scenery.config.REPORT_FILENAME = "scenery_strike_report.csv"

scenery.init()
```

## Development

1. Clone this repo
2. Copy and rename `config.example.lua` to `config.lua`
3. Copy and rename `test_mission.example.miz` to `test_mission.miz`
