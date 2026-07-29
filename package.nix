{ lib
, stdenv
, fetchurl
, gnutar
, gzip
, unzip
}:

let
	version = "3.10.1";

	releaseAssets = {
		"pandoc-${version}-1-amd64.deb" = {
			sha256 = "b419369915e0f3181be0afdb040ec8ecc6b70e72e5992652a0d83aed9e6bc109";
			archiveType = "deb";
		};
		"pandoc-${version}-1-arm64.deb" = {
			sha256 = "14add8849fda702051f8f4da7b080dfab91ac7a11144602a9643e065d3b4c206";
			archiveType = "deb";
		};
		"pandoc-${version}-arm64-macOS.pkg" = {
			sha256 = "768f16693ca5d2c44cefb8db811bf5c75a15c9fce87c9f46133c79a9a4ac9ec3";
			archiveType = "pkg";
		};
		"pandoc-${version}-arm64-macOS.zip" = {
			sha256 = "8607160694a70ed9aa63776caa44acef3afb729c379c7c283724b7e27455bfda";
			archiveType = "zip";
		};
		"pandoc-${version}-linux-amd64.tar.gz" = {
			sha256 = "72948bf5784f560d5ad1876709daca27e0667f262da727bb33f77b58e52df2f5";
			archiveType = "tar";
		};
		"pandoc-${version}-linux-arm64.tar.gz" = {
			sha256 = "cd3963da375793a4804c65ae538b4f7b9c23f87cac7f6c74a1cf5e2fff7e8d59";
			archiveType = "tar";
		};
		"pandoc-${version}-windows-x86_64.msi" = {
			sha256 = "cd2fb4a07bd22139aea56ec43763a61602aaddc9d58b96f7811d71585355e214";
			archiveType = "msi";
		};
		"pandoc-${version}-windows-x86_64.zip" = {
			sha256 = "4725a1883e2171c2e181e6fd45003acb59ca4e9cbe031fdd3b79ef0d697d36aa";
			archiveType = "zip";
		};
		"pandoc-${version}-x86_64-macOS.pkg" = {
			sha256 = "174f7e2c818be48dc003090178f984ceeca54ff78b94127f0dbe56748d2c5f26";
			archiveType = "pkg";
		};
		"pandoc-${version}-x86_64-macOS.zip" = {
			sha256 = "76430dd0ce5305fc4b91d8c0d5c22a00c8d2197ad3cef3937f65048f087164f7";
			archiveType = "zip";
		};
		"pandoc-wasm.zip" = {
			sha256 = "cdf1ec6303fb0aa1fc508c06136b80db875efa2b28f6a8ee706919e012b022cf";
			archiveType = "zip";
		};
	};

	platformMap = {
		"x86_64-linux" = "pandoc-${version}-linux-amd64.tar.gz";
		"aarch64-linux" = "pandoc-${version}-linux-arm64.tar.gz";
		"x86_64-darwin" = "pandoc-${version}-x86_64-macOS.zip";
		"aarch64-darwin" = "pandoc-${version}-arm64-macOS.zip";
	};

	selectedAssetName = platformMap.${stdenv.hostPlatform.system} or null;
	selected = if selectedAssetName == null then null else releaseAssets.${selectedAssetName};
in
assert selected != null ||
	throw "Pandoc ${version} binary is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux";

stdenv.mkDerivation rec {
	pname = "pandoc";
	inherit version;

	src = fetchurl {
		url = "https://github.com/jgm/pandoc/releases/download/${version}/${selectedAssetName}";
		hash = "sha256:${selected.sha256}";
	};

	dontUnpack = true;

	nativeBuildInputs = [ gnutar gzip unzip ];

	buildPhase = ''
		runHook preBuild
		mkdir -p build

		if [ "${selected.archiveType}" = "tar" ]; then
			tar -xzf "$src" -C build
		else
			unzip "$src" -d build
		fi

		runHook postBuild
	'';

	installPhase = ''
		runHook preInstall
		mkdir -p "$out/bin" "$out/share"

		pandoc_bin="$(find build -type f -path '*/bin/pandoc' | head -n1)"
		if [ -z "$pandoc_bin" ]; then
			echo "Could not find pandoc binary in extracted archive" >&2
			exit 1
		fi

		install -m755 "$pandoc_bin" "$out/bin/pandoc"

		share_dir="$(find build -type d -path '*/share' | head -n1)"
		if [ -n "$share_dir" ]; then
			cp -r "$share_dir"/* "$out/share/"
		fi

		runHook postInstall
	'';

	meta = with lib; {
		description = "Pandoc ${version} binary package";
		homepage = "https://github.com/jgm/pandoc";
		license = licenses.gpl2Plus;
		platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
		mainProgram = "pandoc";
	};
}
