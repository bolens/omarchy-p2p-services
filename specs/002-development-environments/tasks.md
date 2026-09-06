# Tasks

- [x] Add locked development tools and source-free image adapters.
- [x] Pass portable tests and adapter regressions in devenv and Podman.
- [ ] Verify CI, archive exclusions, and platform evidence limits.
- [ ] Complete protected delivery and cleanup.

Native devenv and actual rootless Podman passed 238 Python tests, all JavaScript contracts, plugin policy, and Ruby issue-form validation. The image supplies the trusted Python interpreter path and comparison utilities. Live QML/service checks remain outside the portable gate; Docker/native macOS CI and Apple execution evidence remain pending.
