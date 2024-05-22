{
  description = "Userspace tools for bcachefs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      flake-compat,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # can be extended, but these have proper binary cache support in nixpkgs
      # as of writing.
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        {
          self',
          config,
          pkgs,
          ...
        }:
        {
          packages.default = config.packages.bcachefs-tools;
          packages.bcachefs-tools = pkgs.callPackage ./build.nix { };

          packages.bcachefs-tools-fuse = config.packages.bcachefs-tools.override { fuseSupport = true; };

          formatter = pkgs.nixfmt-rfc-style;

          devShells.default = pkgs.mkShell {
            inputsFrom = [ config.packages.default ];

            LIBCLANG_PATH = "${pkgs.clang.cc.lib}/lib";
          };
        };
    };
}
