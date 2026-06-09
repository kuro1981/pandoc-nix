# pandoc-nix

Flake-based packaging repository for reproducible Pandoc usage with Nix.

Japanese README: [README.ja.md](README.ja.md)

## Inspiration / Thanks

This repository structure and maintenance approach are strongly inspired by
[sadjow/codex-cli-nix](https://github.com/sadjow/codex-cli-nix).

For Pandoc-oriented design, this project also learned from
[serokell/nix-pandoc](https://github.com/serokell/nix-pandoc).

Many thanks for sharing such excellent open-source work.

## Why

For team and CI usage, this repository focuses on:

1. Declarative setup in Nix configuration
2. Reproducible environments across machines
3. Flake-first usage for both development and distribution
4. Extensible structure (overlay and package separation)

## Quick Start

### Try locally

```bash
# Enter development shell
nix develop

# Build package
nix build
```

### Use this flake as an input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pandoc-nix.url = "github:YOUR_USER/pandoc-nix";
  };

  outputs = { self, nixpkgs, pandoc-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pandoc-nix.packages.${system}.default
        ];
      };
    };
}
```

### Build documents with mkDoc

This repository exposes an `mkDoc` helper inspired by `serokell/nix-pandoc`.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pandoc-nix.url = "github:YOUR_USER/pandoc-nix";
  };

  outputs = { self, nixpkgs, pandoc-nix, ... }:
    let
      system = "x86_64-linux";
    in {
      packages.${system}.document = pandoc-nix.mkDoc.${system} {
        name = "README.html";
        src = ./.;
        phases = [ "unpackPhase" "buildPhase" "installPhase" ];
        buildPhase = ''
          pandoc --to html -o README.html README.md
        '';
        installPhase = ''
          mkdir -p $out
          cp README.html $out/
        '';
      };
    };
}
```

## Development

```bash
# Format
nix fmt

# Build check
nix build
```

## License

See [LICENSE](LICENSE).




