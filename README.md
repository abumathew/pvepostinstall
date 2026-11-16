# Proxmox post-install setup

Run as root on PVE 8 (Debian bookworm) or PVE 9 (Debian trixie).

```sh
cp .env.example .env
chmod 600 .env
# Edit .env for your UPS, SMB share and hardware.
bash bootstrap.sh
```

Setup configures no-subscription repositories, updates packages, then stops at a
persisted reboot checkpoint. Reboot when your workloads are ready and run the
same command again to finish NUT, sensors/UPS GUI, storage, IOMMU and powertop.
It never initiates a reboot. Configuration changes to IOMMU may need a final reboot.

| Command | Purpose |
| --- | --- |
| `bash bootstrap.sh` | Resume unfinished setup; completed steps are skipped |
| `bash bootstrap.sh --rerun` | Reapply all steps, including package updates and the reboot checkpoint |
| `bash bootstrap.sh --repair-gui` | Restore sensors/UPS summary after a Proxmox update |
| `bash bootstrap.sh --reset` | Clear completion markers and exit; retain the reboot checkpoint |

After `--rerun` reaches its reboot checkpoint, run `bash bootstrap.sh` after
reboot. The saved rerun mode also reapplies previously completed configuration
steps. Failures leave their step unfinished so another run retries it.

## Repair after an upgrade

```sh
cd /path/to/pvepostinstall
bash bootstrap.sh --repair-gui
```

Set `ENABLE_PVE_SENSOR_GUI_MOD="true"` in `.env`. Repair includes both sensor
and UPS widgets and uses `UPS_NAME@UPS_HOST`. The UPS must be reachable and report
a model. GUI preferences default to all CPU cores, zero-speed fans, Celsius and
system information type 1; override `GUI_CPU_MODE`, `GUI_ZERO_FANS`,
`GUI_TEMP_UNIT` and `GUI_SYSTEM_INFO` in `.env` if desired.

Repair checks file hashes and configuration, so repeat runs skip an intact patch.
Changed files are rebuilt from pristine copies of the **exact installed package
versions**, downloaded through APT. If those versions are no longer available,
repair fails without replacing the live GUI files. It stages the vendor patch,
checks required UPS insertions and Perl syntax, backs up the current files under
`/var/lib/proxmox-bootstrap-state/gui-backup.*`, then installs and restarts
`pveproxy`. A failed installation/restart restores that backup. Clear the browser
cache afterward. Future GUI layouts can require an update to the vendor patch;
this workflow does not guarantee compatibility with untested Proxmox releases.

Repair is explicit, not automatically invoked by APT. It does not reconfigure
NUT, SMB, IOMMU, powertop or perform a distribution upgrade. `.env` still needs
to exist, with UPS name/host; other service credentials are not required for repair.

## Repositories and existing installations

The repository step disables existing PVE enterprise/no-subscription entries
and writes one managed no-subscription source. Existing Ceph enterprise sources
are switched to their corresponding no-subscription channel, preserving the
Ceph release and suite. Both legacy `.list` and deb822 `.sources` are supported;
unrelated repositories are preserved. Mixed Proxmox stanzas must be split first.
Original changed source files are saved as `*.pvepostinstall.bak`.

The update step now uses local `apt-get update` and `apt-get dist-upgrade -y`.
It no longer downloads/runs the interactive community post-install or CPU governor
scripts. Their incidental changes (for example subscription banners or governor
selection) are outside this setup. No major PVE/Debian release upgrade is attempted.

On a host configured by the old scripts, use `--repair-gui` for the missing
widgets or `--rerun` for the complete workflow. Existing CIFS storage is retained;
reruns do not update its credentials or share settings. NUT templates are reapplied,
so keep desired UPS configuration in `.env`.

## Local checks

```sh
make test
```

Tests use temporary repository fixtures and mocked bootstrap steps, never host
APT or service commands. Live Proxmox GUI compatibility must be checked on a host.
