{ config, modulesPath, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    htop
    lsd
    fd
    bat
    fzf
    zoxide
    yq-go
    fish
    starship
	  zsh
  ];

  programs = {
    fish.enable = true;
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
