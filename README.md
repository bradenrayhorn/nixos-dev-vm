# setup

On MacOS host.

1. Install UTM.
2. Download ISO.
3. Launch VM with QEMU default settings
4. On startup, run `sudo nx-install`.
5. After complete, shutdown: `sudo shutdown now`.
6. Reconfigure QEMU:
    1. Switch to "Emulated VLAN" networking, port forward Host 127.0.0.1:5222 to guest :22
    2. Remove Boot USB ISO drive
    3. Remove Display device
7. Launch VM again, SSH in, and run `sudo nx-init` to setup repo

