# Helium browser (imputnet) — packaged from the OFFICIAL AppImage releases at
# github.com/imputnet/helium-linux. No third-party flake; the only trust boundary
# is imputnet (the browser vendor). appimageTools handles the bundled Chromium libs.
#
# Helium ships VERSIONED AppImage assets (no version-less "latest" URL) and can't
# build from source, so it can't ride `nix flake update` at the ASSET level. This
# repo (logpose) is the intermediary flake that DOES ride it: `./update-helium.sh`
# rewrites `version` + the arch hash below, and a scheduled GitHub Action runs it so
# this flake's main tracks upstream on its own. A consumer then just bumps the
# `logpose` input like any other (`nix flake update logpose`) — no special-casing.
#
# EXTENSIONS — helium is ungoogled-chromium based and IGNORES ExtensionInstallForcelist
# (proven: 0 installed even with the policy visible + network). It does honour LOCAL
# External Extension Descriptors, so `extensions = [ { id; hash; prodversion?; } … ]`
# force-installs each as a DURABLE EXTERNAL_PREF extension: we fetch the signed Web-Store
# CRX (pinned by hash), read its manifest version, and drop an <id>.json descriptor into
# helium's FHS extensions dir. No key-injection, no --load-extension. (Caveat: some
# extensions still re-open an onboarding tab every launch — a helium-level quirk, not the
# install mechanism; see the consumer's docs/helium-extension-welcome-loop.md.)
{ lib, appimageTools, fetchurl, stdenv, runCommand, python3, commandLineArgs ? ""
, extensions ? [ ] }:

let
  pname = "helium";
  version = "0.17.1.1";

  arch = {
    "x86_64-linux" = "x86_64";
  }.${stdenv.hostPlatform.system} or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  hash = {
    "x86_64-linux" = "sha256-E0A+DPNLWJer96udmZ7kHt8v1YSmCBNLpmFUrvUOeI8=";
  }.${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${arch}.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  # Signed Web-Store CRX for one extension (pinned by hash). The CRX carries the real
  # signing key, so chromium derives the true extension ID from it — no key injection.
  # NordVPN & friends whose minimum_chrome_version > 120 need `prodversion` bumped, else
  # the Web Store serves an EMPTY CRX (looks "delisted").
  crxOf = e: fetchurl {
    url = "https://clients2.google.com/service/update2/crx?response=redirect"
      + "&acceptformat=crx2,crx3&prodversion=${e.prodversion or "120.0.0.0"}"
      + "&x=id%3D${e.id}%26installsource%3Dondemand%26uc";
    hash = e.hash;
    name = "${e.id}.crx";
  };

  # External Extension Descriptors → chromium auto-installs each as a DURABLE
  # EXTERNAL_PREF extension (installed once, kept across launches — not re-loaded like
  # --load-extension). Dropped into BOTH product paths (helium scans its own + the
  # chromium one). external_version is read from the CRX so it always matches.
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

  # Bake the External Extension Descriptors into the FHS (/usr/share/{helium,chromium}/
  # extensions). Only when extensions are declared, so the base package stays clean.
  extraPkgs = p: lib.optional (extensions != [ ]) descriptors;

  extraInstallCommands = ''
    # Bake the runtime flags (Wayland ozone) ONTO THE BINARY, not
    # just the .desktop Exec line.  appimageTools.wrapType2 produces bin/${pname}
    # as `appimage-exec.sh -w <src> -- "$@"` (via buildFHSEnv); `commandLineArgs`
    # is NOT a wrapType2/buildFHSEnv parameter, so on its own it never reaches
    # the launched Chromium.  A consumer that DIRECTLY launches bin/${pname}
    # (e.g. sunny's sandbox-helium bypasses the .desktop file entirely) needs the
    # flags on the binary.  We replace bin/${pname} with a thin wrapper that
    # prepends the flags before the app's own "$@".  Now BOTH the CLI launcher and
    # the desktop entry get the flags from one place.
    if [ -n "${commandLineArgs}" ]; then
      target=$(readlink -f "$out/bin/${pname}")
      rm "$out/bin/${pname}"
      # printf format is single-quoted so bash leaves the literal "$@" alone;
      # %s is substituted with the resolved binary path.  ${commandLineArgs} is
      # Nix-interpolated to the flag string before bash ever sees the line.
      printf '#!${stdenv.shell}\nexec "%s" ${commandLineArgs} "$@"\n' "$target" > "$out/bin/${pname}"
      chmod +x "$out/bin/${pname}"
    fi

    # Pull desktop entry + icons out of the AppImage.  Exec points at our
    # flag-baked wrapper above (no flags here — they live on the binary).
    mkdir -p $out/share/applications
    for d in ${appimageContents}/*.desktop ${appimageContents}/usr/share/applications/*.desktop; do
      [ -e "$d" ] || continue
      install -Dm644 "$d" "$out/share/applications/$(basename "$d")"
    done
    if ls $out/share/applications/*.desktop >/dev/null 2>&1; then
      sed -i "s|^Exec=.*|Exec=${pname} %U|" $out/share/applications/*.desktop
    fi
    # Icons: prefer the AppImage's hicolor tree, else fall back to a root PNG.
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
