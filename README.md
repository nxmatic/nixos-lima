# Run NixOS on a Lima VM
Heavily inspired from [patryk4815/ctftools](https://github.com/patryk4815/ctftools/tree/master/lima-vm)

This is a fork of https://github.com/kasuboski/nixos-lima

Note that there is also a https://github.com/nixos-lima/nixos-lima project
that is tyring to collect work from multiple contributors in a single repo.

## Generating the image
On a linux machine or ubuntu lima vm for example:

```bash
# install nix
sh <(curl -L https://nixos.org/nix/install) --daemon
# enable kvm feature
echo "system-features = nixos-test benchmark big-parallel kvm" >> /etc/nix/nix.conf
reboot

# build nixos
nix build .#nixosConfigurations.nixos.config.system.build.toplevel 

# build image
nix build .#packages.aarch64-linux.img
```

On your mac:
* Move `nixos-aarch64.img` under `imgs`

## Running NixOS
```bash
limactl start --name=default nixos.yaml

lima
# switch to this repo directory
nixos-rebuild switch --flake .#nixos --use-remote-sudo
```


