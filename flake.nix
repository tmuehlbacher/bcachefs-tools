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
      {
        packages = {
          inherit (pkgs) bcachefs;
          bcachefs-fuse = pkgs.bcachefs.override { fuseSupport = true; };
          default = pkgs.bcachefs;
        };

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.callPackage (
          {
            mkShell,
            rustc,
            cargo,
            gnumake,
            gcc,
            clang,
            pkg-config,
            libuuid,
            libsodium,
            keyutils,
            liburcu,
            zlib,
            libaio,
            zstd,
            lz4,
            udev,
            bcachefs,
          }:
          mkShell {
            LIBCLANG_PATH = "${clang.cc.lib}/lib";
            inherit (bcachefs) nativeBuildInputs buildInputs;
          }
        ) { };
      }
    );
}
