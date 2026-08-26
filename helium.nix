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
# NOTE — no ExtensionInstallForcelist here: helium is ungoogled-chromium based,
# which DELIBERATELY ignores that policy (ungoogled-software/ungoogled-chromium
# #2523), so a managed-policy bind is a silent no-op. Declarative force-install
# needs --load-extension / external_crx; the CONSUMER passes those via
# `commandLineArgs` (e.g. sunny's sandboxed-apps.nix does `.override`).
{ lib, appimageTools, fetchurl, stdenv, commandLineArgs ? "" }:

let
  pname = "helium";
  version = "0.13.6.1";

  arch = {
    "x86_64-linux" = "x86_64";
  }.${stdenv.hostPlatform.system} or (throw "helium: unsupported system ${stdenv.hostPlatform.system}");

  hash = {
    "x86_64-linux" = "sha256-ZcZo/vFXWrZjuPjIt2MYbsxs4LU7NvpB3I6mrPzAJjE=";
  }.${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${arch}.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

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
