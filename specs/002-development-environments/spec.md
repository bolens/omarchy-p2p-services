# Development environments

Provide a locked devenv shell for the portable Python, JavaScript, Ruby issue-form, and plugin policy tests. Export a source-free tool image for Docker, Podman, and Apple container. Preserve all service-control and privilege boundaries; development validation must not start real peer-to-peer services.

Acceptance: the existing portable suite and container-helper regressions pass with declared tools; local container runs preserve caller ownership and argument boundaries. Development files remain excluded from plugin release archives. Native Quickshell, Wayland, and service integration remain Linux host checks.
