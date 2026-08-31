# P2P Services

A configurable Omarchy Shell widget for discovering, inspecting, and controlling
local peer-to-peer clients and overlay-network services.

[Website and user guide](https://bolens.github.io/omarchy-p2p-services/) ·
[Documentation](DOCUMENTATION.md) ·
[Get support](SUPPORT.md) ·
[Report an issue](https://github.com/bolens/omarchy-p2p-services/issues/new/choose)

Contributors: [contributing guide](CONTRIBUTING.md) ·
[architecture](ARCHITECTURE.md) · [security policy](SECURITY.md)

![P2P Services status panel with privacy filtering enabled](preview.png?v=4ef6a8cc4ae6)

<details>
<summary>More interface previews</summary>

| Expanded details | Compact list | Two-column grid |
| --- | --- | --- |
| ![Privacy-filtered I2P details](docs/details.png?v=7f3f1e70e4aa) | ![Compact service list](docs/compact.png?v=58751d521da0) | ![Two-column service grid](docs/grid.png?v=37e30e29373a) |
| General settings | Performance settings | Bar widget |
| ![General settings](docs/general.png?v=81fcb1cb3a1d) | ![Performance settings](docs/performance.png?v=4f35e3820b71) | ![Omarchy bar widget](docs/bar.png?v=3524debc7318) |

</details>

## Highlights

- Automatic discovery across supported systemd services, processes, Docker
  containers, and Podman containers.
- Live state, activity, connection, uptime, failure, and runtime details with
  start, stop, restart, logs, configuration, and web-console actions.
- Searchable list and grid layouts with named views, filters, sorting, grouping,
  favorites, and comfortable, compact, or minimal presentation.
- Per-service customization, package management, configuration backups, and
  custom observation-only service definitions.
- Privacy filtering enabled by default, private diagnostics, safe settings
  transfer, and an optional metadata-only event journal.
- Shared, cached snapshots and event-assisted refresh designed to keep idle CPU
  and process activity bounded.
- Keyboard-focusable controls, named assistive actions, and an option to stop
  loading-indicator motion without hiding loading state.

The [website and user guide](https://bolens.github.io/omarchy-p2p-services/)
is the main source for supported services, controls, configuration, privacy and
performance behavior, requirements, troubleshooting, and lifecycle commands.

## Installation

```sh
omarchy plugin add https://github.com/bolens/omarchy-p2p-services.git --enable
```

You can also install from the Omarchy Plugins marketplace. Add or move the
widget through **Setup → Bar** if it is not already visible.

Runtime dependencies are Python 3, systemd tools, `procps-ng`, `iproute2`,
`libnotify`, Polkit, and Omarchy Shell. Docker and Podman are optional.

## Removal

Remove the widget from the bar, then run:

```sh
omarchy plugin remove io.github.bolens.p2p-services
```

Removing the plugin does not remove or stop managed services, packages, or
containers. See the [removal guide](https://bolens.github.io/omarchy-p2p-services/#removal)
for retained plugin data and optional cleanup.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md), the [validation matrix](TESTING.md), and
[ARCHITECTURE.md](ARCHITECTURE.md). Maintainers can refresh interface images
with the restoring [screenshot workflow](TESTING.md#refreshing-screenshots).

## License

[MIT](LICENSE)
