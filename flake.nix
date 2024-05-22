{
  description = "Userspace tools for bcachefs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec {
        packages.default = packages.bcachefs-tools;
        packages.bcachefs-tools = pkgs.callPackage ./build.nix { };
        packages.bcachefs-tools-fuse = packages.bcachefs-tools.override { fuseSupport = true; };

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ packages.default ];

          LIBCLANG_PATH = "${pkgs.clang.cc.lib}/lib";
        };
      }
    );
}
