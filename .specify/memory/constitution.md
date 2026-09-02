# P2P Services Constitution

## Core Principles

### I. Explicit Service Control
Starting, stopping, enabling, disabling, or reconfiguring peer-to-peer services MUST require explicit user intent and target only declared services.

### II. Honest, Deterministic State
Displayed and persisted state MUST distinguish requested, pending, active, failed, unavailable, and degraded conditions. Reloads MUST reproduce successful settings without races or lost updates.

### III. Least-Privilege Boundaries
Commands, service names, paths, and IPC inputs MUST be allowlisted and argument-safe. The plugin MUST NOT broaden privileges, network exposure, or process scope silently.

### IV. Synchronized QML Contracts
Module metadata, defaults, settings UI, IPC, documentation, service adapters, and tests MUST change together. Missing optional services degrade cleanly.

### V. Isolated Verification
Tests MUST mock service management and isolate HOME, XDG, and Quickshell state. They MUST NOT control real services or depend on timing alone.

## Governance

Security, architecture, and testing documentation govern detailed behavior. Exceptions require rationale, regression tests, and a constitution version update.

**Version**: 1.0.0 | **Ratified**: 2026-09-02 | **Last Amended**: 2026-09-02
