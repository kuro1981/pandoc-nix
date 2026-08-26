{ lib
, stdenv
, fetchurl
, gnutar
, gzip
, unzip
}:

let
	version = "3.10.2";

	releaseAssets = {
		"pandoc-${version}-1-amd64.deb" = {
			sha256 = "6c06b69b49ae95087573631a6fcafb233ab7ab51e5cfa73f7539d6c964a2640d";
			archiveType = "deb";
		};
		"pandoc-${version}-1-arm64.deb" = {
			sha256 = "868c7675806237dd21711e3890e82f2844e011c8f542a1ddc6245df4324dd6b5";
			archiveType = "deb";
		};
		"pandoc-${version}-arm64-macOS.pkg" = {
			sha256 = "0fa0892a05b1545948cf1ef5ef962f0c000b057b3c438510e1596c6f4b9d967d";
			archiveType = "pkg";
		};
		"pandoc-${version}-arm64-macOS.zip" = {
			sha256 = "a30bd546062f0b29c25f45a71f951b7a1cf4f998d5b43974ea2c2416133f2e99";
			archiveType = "zip";
		};
		"pandoc-${version}-linux-amd64.tar.gz" = {
			sha256 = "c7edd535941c48be6a362081a748272837de81ae11777202d9c341d3d8261c9a";
			archiveType = "tar";
		};
		"pandoc-${version}-linux-arm64.tar.gz" = {
			sha256 = "1c4d69f2a092bd47cb180e58a4aab7b9637101ced928252458c7d41a7f7fa71d";
			archiveType = "tar";
		};
		"pandoc-${version}-windows-x86_64.msi" = {
			sha256 = "937ed557c4565f4e7c7e1ee59cb059dfe8aafc9adb5b422bfdf688fcaee63a0b";
			archiveType = "msi";
		};
		"pandoc-${version}-windows-x86_64.zip" = {
			sha256 = "52487faaa63f8cef5363d5a771097da001228d61c6f44f32ed41b27a98c0278c";
			archiveType = "zip";
		};
		"pandoc-${version}-x86_64-macOS.pkg" = {
			sha256 = "d09aa0969d7dd5b3217f9f0121163ed522f04aee7bb185ac19ce29e7a8a50488";
			archiveType = "pkg";
		};
		"pandoc-${version}-x86_64-macOS.zip" = {
			sha256 = "437d378af72e9648f6fb42c170031218a3c2f31cf5089234cf2d0413f91481d0";
			archiveType = "zip";
		};
		"pandoc-wasm-${version}.zip" = {
			sha256 = "8a35ca735b536cd0e484d12a62d19a6bdcfacf47738d83a58bdd311dd62540ac";
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
