Run `bash bootstrap.sh --repair-gui` after upgrades remove sensor/UPS widgets.
See [README.md](../README.md) for backup locations and repair limitations.

Do not restore old vendor `Nodes.pm` or `pvemanagerlib.js` backups across package
upgrades. Repair downloads clean files matching the installed package versions.
If those versions are unavailable, resolve APT availability or finish updating
packages, then retry.
