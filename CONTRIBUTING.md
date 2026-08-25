# Contributing

Thanks for helping improve P2P Services. Keep changes focused, local-first, and
consistent with Omarchy Shell conventions.

## Development

Clone the repository and install the checkout through Omarchy when testing live
integration. Do not test control or removal behavior against services whose
configuration you cannot restore.

Run the validation matrix in [TESTING.md](TESTING.md). Add tests for behavior,
parsing, process handling, privacy, and privilege boundaries. Never include
credentials, private endpoints, usernames, paths, or unredacted diagnostics.

Open a pull request that explains the problem, chosen behavior, and validation.
Discuss large interface or security changes in an issue first. See
[ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md), and
[RELEASING.md](RELEASING.md) before changing their respective contracts.
