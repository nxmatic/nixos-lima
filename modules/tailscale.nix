{ config, pkgs, ... }:
let tailscaleKey = ./tailscale.key;
in {
  systemd.tmpfiles.rules =
    [ "L /run/tailscale/auth.key - root root - ${tailscaleKey}" ];

  services.tailscale = {
    enable = true;
    authKeyFile = "/run/tailscale/auth.key";
    useRoutingFeatures = "both";
    extraUpFlags = [ "--ssh" "--advertise-tags=tag:nixos" ];
  };
}
