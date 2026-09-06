# Feature specification: Bounded service discovery, control, and private settings

**Created**: 2026-09-05
**Status**: Retrospective baseline
**Inspected revision**: `e359e7572a8ac4b2c4dfc6321f2754eef75a4321`
**Input**: The owner requested a fleet-wide Spec Kit retrofit and implementation audit.

This retrospective baseline maps the existing plugin architecture and behavioral contracts to their source owners and available acceptance evidence.

This specification records existing contracts after implementation. It does not
claim that the original work followed Spec Kit. New behavior requires a separate
change contract. Existing feature specifications remain authoritative within their
own scope.

## User scenarios and testing

### User story 1: Use the stock-shell feature (P1)

A user interacts with the plugin through its documented bar and settings entry points.

**Acceptance**: Model and contract fixtures preserve the invariants below; source delivery does not replace the running shell.

### User story 2: Recover from change and failure (P2)

Monitor, settings, dependency, or subprocess state changes while the plugin is active.

**Acceptance**: The named failure and lifecycle tests preserve ownership, pending state, and recovery rather than presenting unsupported success.

### User story 3: Maintain the plugin safely (P3)

A maintainer changes a shared behavior or setting.

**Acceptance**: Manifest, model, QML, helpers, docs, and tests remain one contract, with real-engine verification selected for affected QML behavior.

## Requirements

- **FR-001**: Observation MUST remain separate from explicitly requested service controls, and custom services MUST be observation-only.
- **FR-002**: Runtime adapters MUST return bounded argument arrays for allowlisted service, package, unit, and process actions.
- **FR-003**: Settings MUST share canonical manifest defaults, sanitize imports, serialize durable writes, and preserve unrelated settings.
- **FR-004**: Refresh and action controllers MUST retain bounded queue ownership and reject stale results.
- **FR-005**: Private projections and support reports MUST omit service identities, endpoints, paths, and arbitrary command output where documented.
- **FR-006**: Missing tools, probe failures, and lifecycle uncertainty MUST remain distinguishable from verified healthy or active state.

## Success criteria

- **SC-001**: Every requirement has a named source owner and acceptance check in `coverage.md`.
- **SC-002**: The listed native checks pass for the reviewed candidate, with unavailable environments and operational checks recorded separately.
- **SC-003**: Retrofitting preserves existing interfaces and completed specifications. Any confirmed implementation gap is corrected under an explicit requirement before it is marked complete.

## Edge cases and operational limits

Portable fixtures and static QML checks do not prove live compositor, service, device, or rendered interaction behavior. Real-engine harnesses listed in TESTING.md remain required when their runtime boundary changes. This baseline does not authorize installation, live control, stress tests, screenshot capture against the running shell, or marketplace publication.
