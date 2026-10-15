# Remote NVIDIA

An [Omarchy](https://omarchy.org/) bar widget that draws the NVIDIA cards on a machine you can reach over SSH. Each card shows a fan, the temperature, and a VRAM stripe. Click one for load, power, clocks, a temperature trace, and the compute processes. The card name comes from `nvidia-smi`, so a 3090 reads 3090 and a 4090 reads 4090.

The widget polls every 2 seconds. If the host drops off, the last good reading stays up and the next try waits longer, up to 30 seconds.

## Install

```bash
omarchy plugin add https://github.com/tonydelligatti-boop/omarchy-remote-nvidia.git --enable
```

Then tell it which machine to watch. On the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "remote-nvidia",
  "host": "gpu-box",
  "user": "yourname"
}
```

Leave the key unset when your normal SSH config already reaches that host. To use a specific key, add `"identityFile"` with that key's path. The poll uses `BatchMode`, so a key that asks for a password will not work. Check the connection the same way the widget does:

```bash
ssh -o BatchMode=yes yourname@gpu-box nvidia-smi
```

The remote machine needs `nvidia-smi` on the default `PATH`. This machine needs `ssh`, which Omarchy already has. The widget does not change `shell.json` on its own. You add the host and user.

## Remove

```bash
omarchy plugin remove remote-nvidia
```

## How to read it

Temperature color runs cyan, green, gold, orange, then red. Orange starts at `warnC` (83° by default, where a 3090 starts holding its boost). Red starts at `hotC` (90°). Change both numbers on the same shell.json entry for a different card.

A fan that is still while the card is cool is a stopped fan. VRAM can stay full after the load drops if a model is still resident. A card pinned at its power limit is called out on its own, separate from a real thermal throttle.

- Click opens the panel.
- Right-click opens a terminal running live `nvidia-smi` on that host.
- Middle-click refreshes now.

## Settings

| Field | Default | Meaning |
| --- | --- | --- |
| `host` | empty | SSH hostname or address |
| `user` | empty | SSH user |
| `identityFile` | empty | Optional key path. Blank uses your SSH config |
| `pollMs` | 2000 | Poll interval, from 1000 to 60000 |
| `warnC` | 83 | Orange temperature |
| `hotC` | 90 | Red temperature |

## License

MIT. See [LICENSE](LICENSE).
