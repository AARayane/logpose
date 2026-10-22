# helium ignores ExtensionInstallForcelist; extensions install via External Extension Descriptors.
{ lib, appimageTools, fetchurl, stdenv, runCommand, python3, commandLineArgs ? ""
, extensions ? [ ] }:

let
  pname = "helium";
  version = "0.20.1.1";

  arch = {
    "x86_64-linux" = "x86_64";
  }.${stdenv.hostPlatform.system} or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  hash = {
    "x86_64-linux" = "sha256-1LeJsl0KmuEsdmceRE6Khe3Pgo4EGcZ40YxB+xrDAw4=";
  }.${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${arch}.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  # Bump prodversion when minimum_chrome_version > 120, else the Web Store serves an empty CRX.
  crxOf = e: fetchurl {
    url = "https://clients2.google.com/service/update2/crx?response=redirect"
      + "&acceptformat=crx2,crx3&prodversion=${e.prodversion or "120.0.0.0"}"
      + "&x=id%3D${e.id}%26installsource%3Dondemand%26uc";
    hash = e.hash;
    name = "${e.id}.crx";
  };

  descriptors = runCommand "helium-ext-descriptors" { nativeBuildInputs = [ python3 ]; } (''
    mkdir -p $out/share/helium/extensions $out/share/chromium/extensions
  '' + lib.concatMapStringsSep "\n" (e:
    let crx = crxOf e; in ''
      ver=$(python3 ${./crx-version.py} ${crx})
      for d in helium chromium; do
        cp ${crx} $out/share/$d/extensions/${e.id}.crx
        printf '{"external_crx":"/usr/share/%s/extensions/%s.crx","external_version":"%s"}\n' \
          "$d" "${e.id}" "$ver" > $out/share/$d/extensions/${e.id}.json
      done
    '') extensions);
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = p: lib.optional (extensions != [ ]) descriptors;

  extraInstallCommands = ''
    # commandLineArgs never reaches wrapType2's binary, and some callers bypass the .desktop.
    if [ -n "${commandLineArgs}" ]; then
      target=$(readlink -f "$out/bin/${pname}")
      rm "$out/bin/${pname}"
      printf '#!${stdenv.shell}\nexec "%s" ${commandLineArgs} "$@"\n' "$target" > "$out/bin/${pname}"
      chmod +x "$out/bin/${pname}"
    fi

    mkdir -p $out/share/applications
    for d in ${appimageContents}/*.desktop ${appimageContents}/usr/share/applications/*.desktop; do
      [ -e "$d" ] || continue
      install -Dm644 "$d" "$out/share/applications/$(basename "$d")"
    done
    if ls $out/share/applications/*.desktop >/dev/null 2>&1; then
      sed -i "s|^Exec=.*|Exec=${pname} %U|" $out/share/applications/*.desktop
    fi
    if [ -d ${appimageContents}/usr/share/icons ]; then
      cp -r ${appimageContents}/usr/share/icons $out/share/
    else
      for png in ${appimageContents}/*.png; do
        [ -e "$png" ] || continue
        install -Dm644 "$png" "$out/share/icons/hicolor/256x256/apps/$(basename "$png")"
      done
    fi
  '';

  meta = with lib; {
    description = "Private, fast, and honest web browser (Chromium-based, by imputnet)";
    homepage = "https://helium.computer";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "helium";
  };
}
