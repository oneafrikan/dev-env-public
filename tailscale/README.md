# tailscale/

Tailscale command reference and helpers for this dev environment.

Tailscale is installed via **snap** on this machine (`/snap/bin/tailscale`), so the
daemon service is `snap.tailscale.tailscaled`. The Linux client is CLI-only — there is
no official GUI (see [GUI options](#gui-options) below).

## Connect / disconnect

```bash
sudo tailscale up                 # log in / connect (prints an auth URL on first run)
sudo tailscale up --reset         # connect with all flags reset to defaults
sudo tailscale down               # disconnect (stays installed & configured)
sudo tailscale logout             # drop the node's auth — full re-login next time
sudo tailscale up --auth-key=tskey-...   # non-interactive login (servers/CI)
```

## Status & info

```bash
tailscale status                  # peers, their 100.x IPs, online state
tailscale status --json           # same, machine-readable
tailscale ip -4                   # this machine's 100.x.y.z address
tailscale whois <ip|host>         # who owns a peer address
tailscale version                 # client version
```

## Connectivity & diagnostics

```bash
tailscale ping <host>             # path + latency to a peer (tries direct, then DERP)
tailscale netcheck                # NAT type, latency to DERP relays, IPv6 support
tailscale status --peers=false    # just this node
sudo tailscale bugreport          # generate a support identifier for Tailscale support
journalctl -u snap.tailscale.tailscaled -e   # daemon logs (snap install)
```

## Exit nodes

```bash
# Use a peer as your exit node (route ALL traffic through it)
tailscale exit-node list                       # peers offering exit-node service
sudo tailscale set --exit-node=<peer-ip-or-name>
sudo tailscale set --exit-node=                # stop using an exit node

# Offer THIS machine as an exit node (must approve in admin console after)
sudo tailscale set --advertise-exit-node
sudo tailscale set --advertise-exit-node=false
```

## Subnet routing

```bash
# Advertise a LAN subnet so peers can reach it (approve in admin console)
sudo tailscale set --advertise-routes=192.0.2.0/24,198.51.100.0/24
sudo tailscale set --advertise-routes=          # stop advertising

# Accept routes/DNS advertised by other nodes
sudo tailscale set --accept-routes
sudo tailscale set --accept-dns=false           # ignore MagicDNS settings
```

> Routing as an exit node / subnet router needs IP forwarding enabled:
> ```bash
> echo 'net.ipv4.ip_forward = 1'  | sudo tee /etc/sysctl.d/99-tailscale.conf
> echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
> sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
> ```

## Tailscale SSH

```bash
sudo tailscale set --ssh          # enable Tailscale SSH on this node (ACL-gated)
ssh <user>@<peer-name>            # then SSH over the tailnet by MagicDNS name
sudo tailscale set --ssh=false    # disable
```

## File transfer (Taildrop)

```bash
tailscale file cp <file>... <host>:     # send file(s) to a peer
tailscale file get <dir>                # receive queued files into <dir>
```

## Service management (snap install)

```bash
systemctl status  snap.tailscale.tailscaled
sudo systemctl restart snap.tailscale.tailscaled
sudo snap refresh tailscale             # update the client
snap info tailscale                     # installed/available versions
```

## GUI options

Tailscale ships no official Linux GUI. If you ever want one:

- **Built-in web UI:** `sudo tailscale web` → http://localhost:8088
- **Admin console:** https://login.tailscale.com — manage the whole tailnet
- **Trayscale** (community GTK app, via Flatpak/Flathub)
- **GNOME extension:** search "Tailscale" in GNOME Extensions

## References

- CLI docs: https://tailscale.com/kb/1080/cli
- Exit nodes: https://tailscale.com/kb/1103/exit-nodes
- Subnet routers: https://tailscale.com/kb/1019/subnets
- Tailscale SSH: https://tailscale.com/kb/1193/tailscale-ssh
- Taildrop: https://tailscale.com/kb/1106/taildrop
