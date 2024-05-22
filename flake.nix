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
    {
      self,
      nixpkgs,
      utils,
      ...
    }:
    {
      overlays.default = final: prev: { bcachefs = final.callPackage ./build.nix { }; };
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      rec {
        packages = {
          inherit (pkgs) bcachefs;
          bcachefs-fuse = pkgs.bcachefs.override { fuseSupport = true; };
          default = pkgs.bcachefs;
        };

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ packages.default ];

          LIBCLANG_PATH = "${pkgs.clang.cc.lib}/lib";
        };
      }
    );
}
