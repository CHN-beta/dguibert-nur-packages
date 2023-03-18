{
  description = "A flake for building my NUR packages";

  inputs.nixpkgs.url          = "github:dguibert/nixpkgs/pu";
  inputs.nix.url              = "github:dguibert/nix/pu";
  inputs.nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.url      = "github:numtide/flake-utils";

  # for overlays/updated-from-flake.nix
  inputs.dwm-src.url = "github:dguibert/dwm/pu";
  inputs.dwm-src.flake = false;
  inputs.st-src.url = "github:dguibert/st/pu";
  inputs.st-src.flake = false;
  inputs.dwl-src.url = "github:dguibert/dwl/pu";
  inputs.dwl-src.flake = false;
  inputs.mako-src.url = "github:emersion/mako/master";
  inputs.mako-src.flake = false;

  outputs = inputs@{ self, flake-parts, nixpkgs, nix,... }: let
    inherit (self) outputs;

    nixpkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays =  [
          (final: prev: import ./overlays/default final prev)
          (final: prev: import ./overlays/extra-builtins final prev)
          (final: prev: import ./overlays/updated-from-flake.nix final prev)
          nix.overlays.default
        ];
        config.allowUnfree = true;
        config.allowUnsupportedSystem = true;
    };

  in flake-parts.lib.mkFlake { inherit inputs; } {
    flake = {
      lib = nixpkgs.lib;
      ## - TODO: NixOS-related outputs such as nixosModules and nixosSystems.
      nixosModules = import ./modules;

      overlays = import ./overlays { inherit inputs; lib = inputs.nixpkgs.lib; };

      templates = {
        env_flake = {
          path = ./templates/env_flake;
          description = "A bery basic env for my project";
        };
        terraform = {
          path = ./templates/terraform;
          description = "A template to use terranix/terraform";
        };
      };

    };
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    imports = [
      #./home/profiles
      #./hosts
      #./modules/all-modules.nix
      #./lib
      #./checks
      ./shells
    ];

    perSystem = {config, self', inputs', pkgs, system, ...}: {
      legacyPackages = nixpkgsFor system;

      #devShells = import ./shells {
      #  inherit system;
      #  inherit (outputs) lib;
      #  inherit inputs outputs;
      #};

      apps = import ./apps {
        inherit system;
        inherit (outputs) lib;
        inherit inputs outputs;
      };

      checks = inputs.flake-utils.lib.flattenTree (import ./checks { inherit inputs outputs system;
                                                                 pkgs = self.legacyPackages.${system};
                                                                 lib = inputs.nixpkgs.lib; });
    };
  };

}
