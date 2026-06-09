{
  description = "Nix flake for Pandoc - Universal markup converter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        pandoc-nix = final.callPackage ./package.nix { };
        mkDoc = final.callPackage ./mkDoc.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.pandoc-nix;
          pandoc = pkgs.pandoc-nix;
        };

        mkDoc = pkgs.mkDoc;

        apps = {
          default = {
            type = "app";
            program = "${pkgs.pandoc-nix}/bin/pandoc";
          };
          pandoc = {
            type = "app";
            program = "${pkgs.pandoc-nix}/bin/pandoc";
          };
        };

        formatter = pkgs.nixpkgs-fmt;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pandoc-nix
            texlive.combined.scheme-medium
            nixpkgs-fmt
            nix-prefetch-git
            cachix
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}