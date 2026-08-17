# config_ssh

Personal OpenSSH client configuration and public keys for each machine.
Private keys must never be stored in this repository.

## SSH client configuration

```text
config                         # entry point: install as ~/.ssh/config
config.d/
├── 20-tailscale.conf        # Tailscale/MagicDNS host aliases
├── 30-public-vps.conf       # public DNS names and custom ports
├── 90-common.conf           # settings shared by macOS and Linux
└── 95-macos.conf            # macOS keychain settings, safe on Linux
```

OpenSSH uses the first value found for each setting, so host-specific files are
included before the common defaults. Add a MagicDNS machine to the `Host` list
in `20-tailscale.conf`. Add a public server as its own block in
`30-public-vps.conf`.

`UseKeychain` is specific to Apple's OpenSSH. `95-macos.conf` places
`IgnoreUnknown UseKeychain` before it, so Linux OpenSSH ignores that option;
`AddKeysToAgent` continues to work on both platforms.

### Apply

The deployment script validates every public key and configured host, then
installs the client configuration and the generated `authorized_keys` together:

```sh
./build_and_deploy_authorized_keys.sh --check
./build_and_deploy_authorized_keys.sh
```

The second command shows the same plan and asks once before deployment. It
replaces `~/.ssh/config`, the managed files in `~/.ssh/config.d/`, and
`~/.ssh/authorized_keys` without creating backups. Use `--yes` only when a
non-interactive deployment is required.

Check the effective settings before connecting:

```sh
ssh -G amity  | grep -E '^(hostname|user|port|identityfile) '
ssh -G gin    | grep -E '^(hostname|user|port|identityfile) '
```

Expected differences are `amity.riovila.com` with port `22226` for the
public VPS, and the unmodified MagicDNS hostname with port `22` for Tailscale
hosts.

## Public keys

Public SSH keys are stored as `*.pub`. The deployment script assembles the
top-level Ed25519 keys, removes duplicate and blank lines, and deploys the
result to `~/.ssh/authorized_keys`. Files under `rsa/` are retained as reference
material and are not included.
