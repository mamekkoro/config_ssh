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

Back up an existing SSH configuration first, then install both the entry point
and the included directory:

```sh
mkdir -p ~/.ssh/config.d
cp config ~/.ssh/config
cp config.d/*.conf ~/.ssh/config.d/
chmod 700 ~/.ssh ~/.ssh/config.d
chmod 600 ~/.ssh/config ~/.ssh/config.d/*.conf
```

The copy commands replace files with the same names. If `~/.ssh/config` already
contains unrelated settings, merge the `Include` lines into it instead of
replacing it.

Check the effective settings before connecting:

```sh
ssh -G cradle | grep -E '^(hostname|user|port|identityfile) '
ssh -G gin    | grep -E '^(hostname|user|port|identityfile) '
```

Expected differences are `cradle.icardiology.jp` with port `22226` for the
public VPS, and the unmodified MagicDNS hostname with port `22` for Tailscale
hosts.

## Public keys

Public SSH keys are stored as `*.pub`. Run
`./build_and_deploy_authorized_keys.sh` on a target machine to assemble the
top-level Ed25519 keys, review the prompt, and optionally deploy them to
`~/.ssh/authorized_keys`. Existing `authorized_keys` is backed up first.
