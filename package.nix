{ lib
, stdenv
, fetchurl
, gnutar
, gzip
, unzip
}:

let
	version = "3.12";

	releaseAssets = {
		"pandoc-${version}-1-amd64.deb" = {
			sha256 = "91903ff19f1b1d4db4129797c7e18f71212990d7394fcff1787719aebf04e372";
			archiveType = "deb";
		};
		"pandoc-${version}-1-arm64.deb" = {
			sha256 = "9c9165d5eb627b2ccc12868478f847487bda9dc043aa09a964105d5aebfc7b79";
			archiveType = "deb";
		};
		"pandoc-${version}-arm64-macOS.pkg" = {
			sha256 = "7c753a9c6c9e44c4544ad5f256313e0b9eea74276890b0bbcc55f8c312eecc87";
			archiveType = "pkg";
		};
		"pandoc-${version}-arm64-macOS.zip" = {
			sha256 = "f148ca09c9f36594db527a9fc988ad736290ce428f79594c50208cd1ec58b3c0";
			archiveType = "zip";
		};
		"pandoc-${version}-linux-amd64.tar.gz" = {
			sha256 = "67d7d011fed8c8543306022b985b9b2499ab9b74818df91d8727c7e9ebc5ba06";
			archiveType = "tar";
		};
		"pandoc-${version}-linux-arm64.tar.gz" = {
			sha256 = "6cefcf7100e23a99447c26f89d1ff5b253f3407fcef99a9e27ae06f3ed16cb82";
			archiveType = "tar";
		};
		"pandoc-${version}-windows-x86_64.msi" = {
			sha256 = "a1342617c3ec4adb2e005284b566a9fde5dc20ee67012bbd9694fdda93fdfd61";
			archiveType = "msi";
		};
		"pandoc-${version}-windows-x86_64.zip" = {
			sha256 = "2a77ebc2517d13e95056e76b1cd5b574cfe958ac61aa6058117d80c22ca19b79";
			archiveType = "zip";
		};
		"pandoc-${version}-x86_64-macOS.pkg" = {
			sha256 = "751f8ec787081b25080af6269205c1aa1df3090619aa272c48ee57a601d31d26";
			archiveType = "pkg";
		};
		"pandoc-${version}-x86_64-macOS.zip" = {
			sha256 = "18577f9460c3dc5d2651ad3bab37d513bc2034a5a777fbe18fa0a5acf2e936ea";
			archiveType = "zip";
		};
		"pandoc-${version}.wasm.zip" = {
			sha256 = "f14bc3e7722c8bdd58188707e8d5445ce1ac909eae43373f903b45c2f7390cf9";
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
