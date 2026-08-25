"""Pure package-command planning kept separate from process execution."""


def install_command(omarchy, service_id, packages, aur_service_ids):
  if not packages: raise RuntimeError("no installation package is defined for this service")
  route = [omarchy, "pkg"]
  route += ["aur", "add"] if service_id in aur_service_ids else ["add"]
  return route + [packages[0]]


def uninstall_command(omarchy, packages):
  if not packages: raise RuntimeError("no removable Omarchy-managed package is installed")
  return [omarchy, "pkg", "drop"] + list(packages)
