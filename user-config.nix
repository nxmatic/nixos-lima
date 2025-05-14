{ config, modulesPath, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    bash
    bat
    fd
    fish
    htop
    lsd
    lsof
    fzf
    starship
    yq-go
    zoxide
    zsh
  ];

  programs = {
    fish.enable = true;
    bash.enable = true;
    zsh.enable = true;
  };

  users.users = {
    nxmatic = {
      shell = "/run/current-system/sw/bin/zsh";
      isNormalUser = true;
      group = "users";
      home = "/home/nxmatic.linux";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowGroups = [ "nixbld" ];
    };
  };
}
