{ lib
, stdenv
, fetchurl
, gnutar
, gzip
, unzip
}:

let
	version = "3.12.1";

	releaseAssets = {
		"pandoc-${version}-1-amd64.deb" = {
			sha256 = "b4217ac7c54067c442f9d4cd38bcd0c184a43f3e7053431a12263a6f92a33ba2";
			archiveType = "deb";
		};
		"pandoc-${version}-1-arm64.deb" = {
			sha256 = "38f44718c0cb15cb81fc31026bd68c33e8628ca5f7ab15ca86494a7f24f7b8e4";
			archiveType = "deb";
		};
		"pandoc-${version}-arm64-macOS.pkg" = {
			sha256 = "40205bb2d91dee791b98be2a1ce78a2823491bba329f20b922e4120d9a8b428c";
			archiveType = "pkg";
		};
		"pandoc-${version}-arm64-macOS.zip" = {
			sha256 = "c2146cf33a583f3ac93eccddf1bb662371d5cfcce1aad1c87ad860cca1435d46";
			archiveType = "zip";
		};
		"pandoc-${version}-linux-amd64.tar.gz" = {
			sha256 = "d0c90410e90204c9ca83b8539fac5c7aed01fd537207e4585849f8abc5df20b8";
			archiveType = "tar";
		};
		"pandoc-${version}-linux-arm64.tar.gz" = {
			sha256 = "445d96fd08801fe636cab1158b4f017ee320ac3b7446328b4fe2f902117b19b9";
			archiveType = "tar";
		};
		"pandoc-${version}-windows-x86_64.msi" = {
			sha256 = "b6bf9f2c8408a1689272be5722e45f93ed9da17ba74321d0f7ef4e5a196605e8";
			archiveType = "msi";
		};
		"pandoc-${version}-windows-x86_64.zip" = {
			sha256 = "6ef431cb20b2c24a0371fc19200dc49d452be54b1b5c9239f3462841ef53e587";
			archiveType = "zip";
		};
		"pandoc-${version}-x86_64-macOS.pkg" = {
			sha256 = "e657f383500d189721bfb77531d63083f84eefba2117acf6fabe164bbd8a954f";
			archiveType = "pkg";
		};
		"pandoc-${version}-x86_64-macOS.zip" = {
			sha256 = "81ed3e2cfecf096df15d407152f89a684fd65221082b919963f738e977fad3bc";
			archiveType = "zip";
		};
		"pandoc-${version}.wasm.zip" = {
			sha256 = "976eedd4e516b4b137cda2091595d1bd998c7d66553de4cf65337b44a2c72c2d";
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
