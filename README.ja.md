# pandoc-nix

Pandoc を Nix で再現可能に使うための Flake ベースのパッケージングリポジトリです。

English README: [README.md](README.md)

## Inspiration / Thanks

この README 構成と運用方針は、
[sadjow/codex-cli-nix](https://github.com/sadjow/codex-cli-nix) に強くインスパイアされています。

また、Pandoc を Nix で扱う設計の観点では
[serokell/nix-pandoc](https://github.com/serokell/nix-pandoc) を重要な参考実装として学びました。

素晴らしい設計・運用の公開に深く感謝します。ありがとうございます。

## Why

Pandoc をチームや CI で安定運用する際に、次の価値を重視しています。

1. 宣言的な導入: Nix 設定に組み込みやすい
2. 再現可能な環境: マシン差分を最小化できる
3. Flake での利用: 開発環境と配布を同じインターフェースで扱える
4. 拡張しやすい構成: overlay / package の分離がしやすい

## Quick Start

### ローカルで試す

```bash
# 開発シェルに入る
nix develop

# パッケージをビルド
nix build
```

### この Flake を入力として使う

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

### mkDoc で文書をビルドする

`serokell/nix-pandoc` の設計を参考に、`mkDoc` 関数も公開しています。

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
# フォーマット
nix fmt

# ビルド確認
nix build
```

## License

このリポジトリのライセンスは [LICENSE](LICENSE) を参照してください。
