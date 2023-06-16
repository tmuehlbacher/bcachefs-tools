{ lib
, stdenv
, pkg-config
, attr
, libuuid
, libsodium
, keyutils
, liburcu
, zlib
, libaio
, udev
, zstd
, lz4
, nix-gitignore
, rustPlatform
, rustc
, cargo
 }:

let
  src = nix-gitignore.gitignoreSource [] ./. ;

  commit = lib.strings.substring 0 7 (builtins.readFile ./.bcachefs_revision);
  version = "git-${commit}";

in stdenv.mkDerivation {
  inherit src version;

  pname = "bcachefs-tools";

  nativeBuildInputs = [
    pkg-config
    cargo
    rustc
    rustPlatform.cargoSetupHook
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libaio
    keyutils # libkeyutils
    lz4 # liblz4

    libsodium
    liburcu
    libuuid
    zstd # libzstd
    zlib # zlib1g
    attr
    udev
  ];

  cargoRoot = "rust-src";
  # when git-based crates are updated, run:
  # nix run github:Mic92/nix-update -- --version=skip --flake default
  # to update the hashes
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/rust-src/Cargo.lock";
    outputHashes = {
      "bindgen-0.64.0" = "sha256-GNG8as33HLRYJGYe0nw6qBzq86aHiGonyynEM7gaEE4=";
    };
  };

  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "VERSION=${commit}"
  ];

  dontStrip = true;
  checkPhase = "./bcachefs version";
  doCheck = true;
}
