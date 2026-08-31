# Contributing

Thanks for helping improve P2P Services. Keep changes focused, local-first, and
consistent with Omarchy Shell conventions.

The [website guide](https://bolens.github.io/omarchy-p2p-services/#guide) is the
canonical home for user behavior. Update it with user-visible changes and link
to it from repository docs instead of duplicating operational guidance.

## Development

Clone the repository and install the checkout through Omarchy when testing live
integration. Do not test control or removal behavior against services whose
configuration you cannot restore.

Run `npm run hooks:install` once after cloning. The pre-commit hook validates
the staged release payload and runs the deterministic suite. Graphical and
live-system checks remain explicit.

Run the validation matrix in [TESTING.md](TESTING.md). Add tests for behavior,
parsing, process handling, privacy, and privilege boundaries. Never include
credentials, private endpoints, usernames, paths, or unredacted diagnostics.

Open a pull request that explains the problem, chosen behavior, and validation.
Discuss large interface or security changes in an issue first. See
[ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md), and
[RELEASING.md](RELEASING.md) before changing their respective contracts.
