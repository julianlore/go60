# Based off https://github.com/GaetanLepage/glove80-zmk-config with some modifications for Go60
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    go60-zmk = {
      url = "github:moergo-sc/zmk/main";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      go60-zmk,
      flake-parts,
      devshell,
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ inputs.devshell.flakeModule ];

      perSystem = { config, pkgs, ... }: {
        packages.default =
          let
            firmware = import go60-zmk { inherit pkgs; };

            keymap = ./go60.keymap;
            kconfig = ./go60.conf;

            go60_left = firmware.zmk.override {
              board = "go60_lh";
              inherit keymap;
              inherit kconfig;
            };

            go60_right = firmware.zmk.override {
              board = "go60_rh";
              inherit keymap;
              inherit kconfig;
            };

          in
          firmware.combine_uf2 go60_left go60_right "go60";

        devshells.default.commands = [
          {
            name = "flash";
            command = ''
              set +e

              root="/run/media/$(whoami)"
              # Redirect ls stderr to null as /run/media won't exist if nothing is mounted
              dest_folder_name=$(ls $root 2> /dev/null | grep GO60)

              if [ -n "$dest_folder_name" ]; then
                cp ${config.packages.default}/go60.uf2 "$root"/"$dest_folder_name"/CURRENT.UF2
                exit 0
              fi

              echo "Waiting for Go60 to be mounted in bootloader mode..."
              while :; do
                sleep 1
                dest_folder_name=$(ls $root 2> /dev/null | grep GO60)
                if [ -n "$dest_folder_name" ]; then
                  cp ${config.packages.default}/go60.uf2 "$root"/"$dest_folder_name"/CURRENT.UF2
                  exit 0
                fi
              done
            '';
            help = "Builds the firmware and copies it to the plugged-in keyboard half.";
          }
        ];
      };
    };
}
