{ lib
, stdenv
, fetchurl
, gnutar
, gzip
, unzip
}:

let
	version = "3.10";

	releaseAssets = {
		"pandoc-${version}-1-amd64.deb" = {
			sha256 = "d502599878eb29af3ae5f0cb5d559134df96534125d452c7a0674a5bad2c5ecf";
			archiveType = "deb";
		};
		"pandoc-${version}-1-arm64.deb" = {
			sha256 = "b651c8bfd5a0a2f6650d6c0830131747ef67a1d9c0475b1399626611419e2205";
			archiveType = "deb";
		};
		"pandoc-${version}-arm64-macOS.pkg" = {
			sha256 = "822032365a2d6dde71017cb0be4e475d396f7cca5d45fc6c03a808a9c091696b";
			archiveType = "pkg";
		};
		"pandoc-${version}-arm64-macOS.zip" = {
			sha256 = "d9cad01d96ae774a0dc8c8c45bb1ad3e4c5ff2cc2e24f45958f5f9b7974aee34";
			archiveType = "zip";
		};
		"pandoc-${version}-linux-amd64.tar.gz" = {
			sha256 = "e0f8af62d0f267d22baa5bcefe6d5dda3a097ccc60de794b759fe03159923244";
			archiveType = "tar";
		};
		"pandoc-${version}-linux-arm64.tar.gz" = {
			sha256 = "55413dfb0c1aec861641fe858f1f73e84848f3db497b1c0c02e62887ea76f4a4";
			archiveType = "tar";
		};
		"pandoc-${version}-windows-x86_64.msi" = {
			sha256 = "5334f560afb99efc2917c95ddd6d4337f4562f57b0122839b611854e2a6678e0";
			archiveType = "msi";
		};
		"pandoc-${version}-windows-x86_64.zip" = {
			sha256 = "bb808d00fd58762299d64582a9b4c3e4b106cd929e62c5f19bcdcb496f1e54ae";
			archiveType = "zip";
		};
		"pandoc-${version}-x86_64-macOS.pkg" = {
			sha256 = "e6a5217a84ba1cdba040b87012a00d146cf832fc7a9ade59c371bfe2c4da5c09";
			archiveType = "pkg";
		};
		"pandoc-${version}-x86_64-macOS.zip" = {
			sha256 = "6334f4d9af7c9e37e761dfad56fa5507685f6d29724ebf31c4be6d5c654a3161";
			archiveType = "zip";
		};
		"pandoc-${version}.wasm.zip" = {
			sha256 = "e0865674db6fa2698d29811ca2fcb91ab00a2f8b7d0220eae4ea28405d9cab2b";
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
