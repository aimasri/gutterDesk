# Operational Runbook: gutterDesk

## 1. Bare-Metal Provisioning Guide

This section outlines the definitive deployment process for installing **gutterDesk** onto fresh hardware from an official **Debian 13 (Trixie) Net-inst ISO**.

### A. BIOS / UEFI Firmware Setup
1. **Enter BIOS:** Tap `F2`, `Delete` (ASUS/Desktop), `F12` (Lenovo/Dell), or `F10` (HP) upon system power-on.
2. **Firmware Settings:**
   * **Secure Boot:** `Disabled` (Required for custom Plymouth splash & DKMS).
   * **Fast Boot:** `Disabled`.
   * **Boot Mode:** `UEFI Only` (Never Legacy/CSM).
   * **Storage Controller (Intel Laptops):** Set Intel VMD Controller to `Disabled` (Native AHCI mode).
3. **Save and Exit:** Press `F10`.

### B. Debian 13 Net-Install
1. Boot the minimal netinst USB installer in UEFI mode.
2. **Hostname:** Enter machine role name (e.g. `aim-stream`, `AiM-Home`, `aim-book`).
3. **Domain Name:** **Leave completely blank** (prevents DNS resolution conflicts on roaming Wi-Fi).
4. **Root Password:** **Leave completely blank / empty**. Debian automatically disables the root account and grants unrestricted `sudo` privileges to your user account.
5. **Username:** Enter primary username (e.g. `ahmed`).
6. **Partitioning:** Select `Guided - use entire disk` -> `All files in one partition`.
7. **Package Selection (`tasksel`):**
   * `[ ] Debian desktop environment` (**UNCHECK**)
   * `[ ] ... (all other desktops: GNOME, XFCE, KDE)` (**UNCHECK**)
   * `[*] SSH server` (**CHECK**)
   * `[*] standard system utilities` (**CHECK**)
8. **GRUB Bootloader:** Install to EFI removable media path if prompted. Reboot upon completion.

### C. Universal Base Bootstrap
Log into the text console (`login:`) as your standard user and execute:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/aimasri/gutterDesk.git ~/gutterDesk
cd ~/gutterDesk
sudo ./bootstrap.sh
sudo reboot
```

### D. Broadband Router Fixed IP Reservation (Central Server / NFS Host)
A central headless node hosting canonical repositories, NFSv4 exports, and the Banyan trading engine (`aim-stream`) requires an immutable IP address on the local LAN:

1. **Audit Network Parameters:**
   During `core/04-network-iwd.sh` or `install.sh --server`, gutterDesk automatically audits and displays the server's active network configuration:
   - **Active Interface:** e.g. `wlan0`
   - **MAC Address:** e.g. `f0:9e:4a:af:79:0e`
   - **Assigned LAN IP:** e.g. `192.168.1.48`
   - **Router Gateway URL:** e.g. `http://192.168.1.1`

2. **Configure Router Static Lease / Reservation:**
   - Log into your broadband router portal (e.g. `http://192.168.1.1`).
   - Navigate to **DHCP Settings / Address Reservation / Static Leases**.
   - Create a static reservation binding the server's MAC address to its IP.
   - **Do not configure a static IP directly on the host:** Leave `aim-stream` set to standard DHCP (`iwd` / Debian netinst). The router guarantees immutable IP delivery without the risk of network bricking if gateways or router models change.

---

## 2. Multi-Node Cluster Synchronization Runbook

gutterDesk is deployed across three active physical machines. All codebase enhancements, dotfiles, and system configurations originate on `aim-stream` and are pushed to client workstations.

```
                      +---------------------------------------+
                      |       aim-stream (100.96.229.63)      |
                      |          Origin Development           |
                      +-------------------+-------------------+
                                          |
                                    git push origin
                                          |
                                          v
                              GitHub (aimasri/gutterDesk)
                                          |
                      +-------------------+-------------------+
                      | git pull                              | git pull
                      v                                       v
+---------------------------------------+   +---------------------------------------+
|        AiM-Home (100.101.23.16)       |   |         aim-book (100.118.241.19)     |
|              Workstation              |   |                 Laptop                |
+---------------------------------------+   +---------------------------------------+
```

### Cluster Sync Protocol:
When changes to dotfiles, scripts, or wallpapers are committed on `aim-stream`:

1. **Push from `aim-stream`:**
   ```bash
   cd ~/projects/gutterDesk
   git status
   git add <modified-files>
   git commit -m "feat/fix: <descriptive message>"
   git push origin main
   ```

2. **Sync to `AiM-Home` (Workstation):**
   ```bash
   ssh ahmed@AiM-Home "cd ~/gutterDesk && git pull && sudo ./bootstrap.sh"
   ```

3. **Sync to `aim-book` (Laptop):**
   ```bash
   ssh ahmed@aim-book "cd ~/gutterDesk && git pull && sudo ./bootstrap.sh"
   ```

4. **Verify Live X11 Display Sync (Optional):**
   If wallpapers or menus were modified, reconfigure the running session:
   ```bash
   # Reconfigure Openbox menu on workstation
   ssh ahmed@AiM-Home "DISPLAY=:0 openbox --reconfigure"
   
   # Re-apply dual-monitor wallpapers
   ssh ahmed@AiM-Home "DISPLAY=:0 auto-wallpaper"
   ```

---

## 3. Private Profile Restoration (`backup/`)

To restore private SSH identity keys, project environment secrets, and application databases after a fresh bootstrap:

```bash
# 1. Extract backup archive
mkdir -p ~/gutterDesk/backup
tar -xzf /path/to/gutterdesk-private-backup.tar.gz -C ~/gutterDesk/backup/ --strip-components=1

# 2. Stage 1: Connect system identity, SSH keys, and desktop profiles
cd ~/gutterDesk/backup
./connect.sh

# 3. Stage 2: Sync project credentials (.env) and Apache virtual hosts
./sync.sh
```

---

## 4. Diagnostics & Troubleshooting

### A. Wi-Fi Troubleshooting (`iwd`):
If wireless does not automatically associate on boot:
```bash
# Check iwd service status
systemctl status iwd

# Inspect devices and networks via interactive shell
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "SSID"
```

### B. NFSv4 Mount Verification:
If remote storage at `~/aim-stream` fails to respond on client machines:
```bash
# 1. On server (aim-stream): Verify NFS daemon and exports
sudo systemctl status nfs-server
sudo exportfs -v

# 2. On client: Check automount status and force mount
systemctl status home-ahmed-aim\\x2dstream.automount
ls -la ~/aim-stream
```

### C. Openbox Menu Compilation Reset:
If the root desktop menu becomes desynchronized:
```bash
gutterdesk-menu init
openbox --reconfigure
```
