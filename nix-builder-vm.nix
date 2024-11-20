{ config, modulesPath, pkgs, lib, ... }: {

  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/nix-builder-vm.nix")
  ];

  documentation.enable = lib.mkForce true;

  # Environment
  environment.systemPackages = with pkgs; [
    yq-go
  ];

  nix = {
    buildMachines = [{
      hostName = "localhost";
      systems = [ "x86_64-linux" "aarch64-linux" ];
      supportedFeatures = [ "kvm" "big-parallel" ];
      maxJobs = 4;
    }];
    distributedBuilds = true;
    extraOptions = ''
        builders-use-substitutes = true
      '';
    channel.enable = lib.mkForce true;
  };

  system = {
    disableInstallerTools = lib.mkForce false;
  };

  virtualisation.fileSystems = {
    "/etc/ssl/certs" = {
      device = lib.mkForce "certs";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "ro"  ];
    };
    "/etc/ssl/cert.pem" = {
      device = lib.mkForce "certs";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "ro"  ];
    };
    "/tmp/shared" = {
      device = lib.mkForce "shared";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
    "/tmp/xchg" = {
      device = lib.mkForce "xchg";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
    "/var/keys" = {
      device = lib.mkForce "keys";
      fsType = lib.mkForce "virtiofs";
      options = lib.mkForce [ "rw"  ];
    };
  };
}
