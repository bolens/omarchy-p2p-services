# P2P Services

An Omarchy Shell bar widget for discovering, inspecting, and controlling local
peer-to-peer clients and overlay-network daemons.

[Website and user guide](https://bolens.github.io/omarchy-p2p-services/) ·
[Source](https://github.com/bolens/omarchy-p2p-services) ·
[Report an issue](https://github.com/bolens/omarchy-p2p-services/issues/new/choose)

![P2P Services status panel with privacy filtering enabled](preview.png?v=346db756e930)

| General settings | Performance settings | Bar widget |
| --- | --- | --- |
| ![P2P Services privacy and behavior settings](docs/general.png?v=dfeb9721209f) | ![P2P Services refresh and resource settings](docs/performance.png?v=f81ed121368c) | ![P2P Services Omarchy bar widget](docs/bar.png?v=f1f8ab12287a) |

| Expanded I2P details | Compact icon list | Two-column grid |
| --- | --- | --- |
| ![I2P Router with privacy-filtered details expanded](docs/details.png?v=05db707bcfef) | ![P2P Services compact icon list](docs/compact.png?v=34a8858116ee) | ![P2P Services two-column service grid](docs/grid.png?v=6a9795f376b4) |

Supported backends include Yggdrasil, Tailscale, ZeroTier, Nebula, Headscale,
NetBird, NetBird Server, Netmaker, Netmaker Client, I2P/I2Pd, Freenet/Hyphanet, AirDC++,
LinuxDC++, EiskaltDC++, Nicotine+, Deluge, qBittorrent, Transmission, aria2,
IPFS/Kubo, Syncthing, ZeroNet, GNUnet, and RetroShare. Only detected services
are shown; newly installed supported software appears automatically.

Additional discovery covers cjdns, Lokinet, Veilid, Tahoe-LAFS, aMule, slskd,
SoulseekQt, rTorrent, Tribler, Fragments, WebTorrent, BTFS, opentracker, Nym
nodes, LND, and Monero nodes.

Docker and Podman containers are discovered through their owning runtime. The
widget keeps that runtime association for status and start, stop, and restart
actions. Reverse-proxy and published-port console discovery works for either
runtime when the container exposes compatible OCI metadata and Compose labels.

Apple's `container` runtime is intentionally not offered on Arch Linux: its
runtime depends on Apple silicon and macOS virtualization frameworks. Images
built for OCI remain usable through Docker or Podman when architecture and
platform support permit.

## Privacy model

The privacy filter is enabled by default. While enabled, the helper omits peer
and socket endpoints, PIDs, configuration paths, and local console URLs from
its JSON output. Turning it off exposes those details in the popup until it is
enabled again.

## Controls

- Start, stop, and restart via a detected user or system systemd unit.
- System units request authorization through Polkit.
- Services without units use only exact, current-user process names.
- Open known local web consoles.
- Open each service's detected configuration file or directory without exposing
  its path while the privacy filter is enabled.
- Middle-click the bar widget to open widget settings.
- Right-click the bar widget for a full status and package-catalog refresh.
- Right-click a service card for its action menu; middle-click it to customize.
- Service actions send desktop notifications for success, cancellation, and
  failure instead of placing command errors in the popup.

Widget settings are available from the gear button or by middle-clicking the bar icon. Appearance controls cover popup width and height, bar presentation, font size, margins, padding, optional fixed width, rotation, idle dimming, header and card density, card metadata and actions, group headers, and theme-aware bar, status, favorite, and activity color roles. Behavior controls include the startup filter or named view, persisted collapsed groups, state-change alerts, and refresh triggers.
Settings are split into General, Appearance, Services, Performance, Discovery,
and Packages views. A compact two-row navigator keeps categories readable,
while titled surfaces separate startup behavior, notifications, visual density,
sorting, refresh cadence, traffic sampling, routing, and settings data.
Package catalog discovery and package-row creation are deferred until the
Packages or per-service settings view is opened.
Status and catalog updates do not begin while the popup is moving. Results that
finish during a pointer drag or kinetic flick are applied once movement ends,
avoiding card reconstruction and layout work in the scrolling frame path.
Middle-click any service row to edit that service's label, icon, stopped-state
visibility, ordering, configuration, console, and backend details.
Services can be favorited and sorted by custom order, name, status, or live
activity. Comfortable, compact, and minimal cards tune vertical space, and notification behavior can
be inherited, always enabled, limited to failures, or silenced per service.
The main panel includes live text search and All, Running, Stopped, and Issues
views. Search matches custom labels, backend IDs, runtime types, and systemd
units. Selecting Stopped temporarily reveals stopped services even when the
global stopped-service preference is disabled.
Service cards keep operational controls visible while process, configuration,
endpoint, and backend details remain collapsed until requested. Only one
service detail section is expanded at a time.
Services can be sorted by custom order, name, category, status, live activity,
connections, uptime, transfer rate, backend, recent state change, or error
severity. Automatic direction puts the
most useful values first for each mode; ascending and descending overrides are
available, and favorite or running-service pinning can be disabled independently.
Live sorts hold their order briefly after updates and during interaction to keep
cards from jumping under the pointer. Compact dropdowns in the main panel provide
direct access to every sort mode and direction without cycling through options.
The bar can show a single aggregate or separate per-category active counts.
Category mode can optionally include detected totals, hide categories with zero
active services, and persist an icon override for each detected category.

Optional status, backend, category, control-scope, and favorite grouping adds
collapsible group headers. Category grouping organizes the catalog by protocol
or purpose, while control scope separates containers, system services, user
services, and standalone processes. Category names also participate in search.
Group ordering can use a semantic default or alphabetical direction; headers can
show an icon plus active, total, or active/total counts. These organization
controls live in Widget settings to keep the main service view focused. Only
saved view shortcuts remain above the service list.
Named views preserve the current search, filter, sorting, grouping, direction,
and favorite behavior, with the first three available directly above the list.
Missing supported services can be installed individually from Widget settings. The installer opens in a terminal and delegates to `omarchy pkg add` using a fixed per-service package allowlist. Installed allowlisted packages can be uninstalled from the service settings after the service is stopped. Before removal, the declared configuration file or directory is copied to `$XDG_DATA_HOME/omarchy/p2p-services/config-backups` (defaulting to `~/.local/share/omarchy/p2p-services/config-backups`); containers, volumes, images, manual installs, and source configuration are not removed.

Tailscale, ZeroTier, Nebula, and Headscale use official Arch packages. NetBird's
client uses its maintained AUR package. NetBird Server, Netmaker, and Netmaker
Client are discovery/control integrations because their common deployments are
containerized or externally installed; the plugin does not offer a package
installation action for them.

Container-backed services show aggregate live receive/transmit rates when counters change. This can be disabled in Widget settings; disabling it also skips container statistics collection. Runtimes that do not expose counters degrade gracefully.

Expanded details include restart counts, state transitions, and available
failure reasons without extra hot-path commands. The card action menu can open
live systemd/container logs or copy a privacy-aware diagnostic summary.

Configuration backups have configurable retention and any retained snapshot can
be restored after confirmation; the current configuration is backed up first.
Protected file restores use a narrowly scoped privileged `install` operation;
the plugin helper itself is never executed as root. Settings can be
exported to and imported from
`$XDG_DATA_HOME/omarchy/p2p-services/settings-export.json` (defaulting to
`~/.local/share/omarchy/p2p-services/settings-export.json`).

Advanced users can define up to 32 custom services. Custom IDs must begin with
`custom-`; executable, process, and systemd unit names are validated exactly,
and arbitrary shell commands are rejected. Custom services are observation-only:
their identifiers support detection but cannot initiate executable, process,
configuration, or systemd mutations.

## Performance model

Each status refresh takes one shared snapshot of processes, sockets, packages, system and user units, and container metadata. Container statistics are requested only for matched running P2P containers. Normal polls inspect running containers; startup, manual refreshes, service actions, and periodic reconciliation also inspect stopped containers. The install/uninstall flow temporarily checks the package catalog more frequently, while steady-state catalog discovery runs every five minutes. A failed or malformed refresh leaves the last successful widget data visible.

Identical status requests from multiple monitors share a short-lived,
lock-protected runtime cache. Manual refreshes and service actions invalidate the
cache, retaining immediate feedback without repeating the expensive snapshot.
Cached payloads are capped to prevent stale request variants from accumulating.

Separate settings control open-panel refreshes (2–60 seconds), background
refreshes (15–300 seconds), and full stopped-container reconciliation (30–600
seconds). Immediate refreshes after opening, changing settings, and service
actions can be disabled independently. Traffic-rate smoothing, the minimum
displayed activity rate, and the stale-data warning threshold are configurable.
These defaults keep
visible status responsive while reducing background process, systemd, and
container-runtime queries.

Optional event-assisted refresh listens for systemd and container changes in the
shared service, debounces bursts, and keeps periodic polling as a
fallback. Results are still deferred while scrolling. Full or manual refreshes
requested during an active scan are coalesced and run afterward, while redundant
periodic polls are dropped. Consecutive failures back polling off to four times
the configured interval and a successful scan restores the normal cadence.

A keep-loaded singleton now owns the event watcher and status process for every
monitor. Its versioned watcher protocol includes health heartbeats, bounded
restart backoff, and telemetry for heartbeat age, scan age, duration, and partial
probe warnings. Per-monitor widgets retain the local scanner as a compatibility
fallback if the singleton service is unavailable.

Settings are mirrored atomically with mode 0600 at
`~/.local/state/omarchy/p2p-services/settings.json` and reconciled with the
inline `shell.json` entry at startup, preserving preferences across shell
restarts. Versioned schema migration removes unknown fields, clamps values, and
uses monotonic revisions to select the newest copy safely. Imported per-service
labels, icons, visibility flags, console URLs, and notification policies are
normalized by type before QML consumes them.
Concurrent widget instances submit field-level patches under a file lock so
unrelated edits are retained. Each durable change preserves a private previous
snapshot that can be restored with **Undo last change**.

The settings surface is loaded only while open, reducing steady-state QML object
count. Service notifications use Omarchy's notification command so desktop
do-not-disturb and shell notification policy are respected.

## Validation

Run `tests/run_all.sh` for Python behavior/security tests, JavaScript model and
architecture contracts, Python compilation, QML lint/format checks, and manifest
validation. Run `tests/run_qml_runtime.sh` from a graphical session for the real
Quickshell JavaScript-engine check.

The console editor accepts a validated `http://` or `https://` URL. Row and settings-page
console buttons always open that saved URL, falling back to the backend default
only when no override is configured.

## Installation

Install the current public GitHub version:

```sh
omarchy plugin add https://github.com/bolens/omarchy-p2p-services.git --enable
```

You can also install it through the Omarchy Plugins marketplace. Add **P2P
Services** to the bar from Omarchy Shell settings if it was not enabled during
installation, then restart Omarchy Shell if it is already running.

Runtime dependencies are Python 3, systemd tools, `procps-ng`, `iproute2`, `libnotify`, Polkit, and Omarchy Shell. Docker and Podman are optional and detected independently. Service packages are optional and installed only when requested.

## Removal

Remove the widget from the bar, then run:

```sh
omarchy plugin remove io.github.bolens.p2p-services
```

Removing the plugin does not remove or stop service packages and containers.
The P2P Services directories under `$XDG_DATA_HOME` and `$XDG_STATE_HOME`
(defaulting to `~/.local/share` and `~/.local/state`) are retained so removal does not destroy
user data; remove those directories separately only if you no longer need them.

## Security

Service and package identifiers are fixed allowlists. Container matching is exact, console URLs and hosts are validated, private mode redacts sensitive values before serialization, and privileged systemd actions use absolute executables through Polkit. Start, stop, and restart are verified after execution before success is reported.
