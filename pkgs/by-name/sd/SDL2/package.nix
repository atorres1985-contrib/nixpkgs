{
  lib,
  alsa-lib,
  audiofile,
  config,
  darwin,
  dbus,
  fetchFromGitHub,
  ibus,
  libGL,
  libICE,
  libX11,
  libXScrnSaver,
  libXcursor,
  libXext,
  libXi,
  libXinerama,
  libXrandr,
  libXxf86vm,
  libdecor,
  libdrm,
  libiconv,
  libpulseaudio,
  libxkbcommon,
  mesa,
  nix-update-script,
  pipewire, # NOTE: must be built with SDL2 without pipewire support
  pkg-config,
  stdenv,
  testers,
  udev,
  wayland,
  wayland-protocols,
  wayland-scanner,
  xorgproto,
  # Boolean flags
  alsaSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  dbusSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  drmSupport ? false,
  enableSdltest ? (!stdenv.isDarwin),
  ibusSupport ? false,
  libGLSupported ? lib.elem stdenv.hostPlatform.system lib.platforms.mesaPlatforms,
  libdecorSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  openglSupport ? libGLSupported,
  pipewireSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  pulseaudioSupport ?
    config.pulseaudio or stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  udevSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  waylandSupport ? stdenv.isLinux && !stdenv.hostPlatform.isAndroid,
  withStatic ? stdenv.hostPlatform.isMinGW,
  x11Support ? !stdenv.hostPlatform.isWindows && !stdenv.hostPlatform.isAndroid,
}:

# NOTE: When editing this expression see if the same change applies to SDL
# expression too

let
  inherit (darwin.apple_sdk.frameworks)
    AudioUnit
    Cocoa
    CoreAudio
    CoreServices
    ForceFeedback
    OpenGL
    ;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "SDL2";
  version = "2.30.2";

  src = fetchFromGitHub {
    owner = "libsdl-org";
    repo = "SDL";
    rev = "release-${finalAttrs.version}";
    hash = "sha256-yYYtsF6+IKynXpfay0rUmCQPdL8vp6dlmon8N7UG89A=";
  };

  dontDisableStatic = withStatic;

  outputs = [
    "out"
    "dev"
  ];
  outputBin = "dev"; # sdl2-config

  patches = [
    # `sdl2-config --cflags` from Nixpkgs returns include path to just SDL2.
    # On a normal distro this is enough for includes from all SDL2* packages to
    # work, but on NixOS they're spread across different paths.
    # This patch + the setup-hook will ensure that `sdl2-config --cflags` works
    # correctly.
    ./find-headers.patch
  ];

  # Fix running wayland-scanner for the build platform when cross-compiling.
  #   https://github.com/libsdl-org/SDL/issues/4860#issuecomment-1119003545
  postPatch = ''
    substituteInPlace configure \
      --replace '$(WAYLAND_SCANNER)' 'wayland-scanner'
  '';

  strictDeps = true;

  depsBuildBuild = [ pkg-config ];

  nativeBuildInputs =
    [ pkg-config ]
    ++ lib.optionals waylandSupport [
      wayland
      wayland-scanner
    ];

  dlopenPropagatedBuildInputs =
    # Propagated for #include <GLES/gl.h> in SDL_opengles.h.
    lib.optionals (openglSupport && !stdenv.isDarwin) [ libGL ]
    # Propagated for #include <X11/Xlib.h> and <X11/Xatom.h> in SDL_syswm.h.
    ++ lib.optionals x11Support [ libX11 ];

  propagatedBuildInputs =
    finalAttrs.dlopenPropagatedBuildInputs
    ++ lib.optionals x11Support [ xorgproto ];

  dlopenBuildInputs =
    lib.optionals alsaSupport [
      alsa-lib
      audiofile
    ]
    ++ lib.optionals dbusSupport [ dbus ]
    ++ lib.optionals libdecorSupport [ libdecor ]
    ++ lib.optionals pipewireSupport [ pipewire ]
    ++ lib.optionals pulseaudioSupport [ libpulseaudio ]
    ++ lib.optionals udevSupport [ udev ]
    ++ lib.optionals waylandSupport [
      libxkbcommon
      wayland
    ]
    ++ lib.optionals x11Support [
      libICE
      libXScrnSaver
      libXcursor
      libXext
      libXi
      libXinerama
      libXrandr
      libXxf86vm
    ]
    ++ lib.optionals drmSupport [
      libdrm
      mesa
    ];

  buildInputs =
    [ libiconv ]
    ++ finalAttrs.dlopenBuildInputs
    ++ lib.optionals ibusSupport [ ibus ]
    ++ lib.optionals waylandSupport [ wayland-protocols ]
    ++ lib.optionals stdenv.isDarwin [
      AudioUnit
      Cocoa
      CoreAudio
      CoreServices
      ForceFeedback
      OpenGL
    ];

  enableParallelBuilding = true;

  configureFlags = [
    (lib.enableFeature false "oss")
    (lib.withFeature x11Support "x")
    (lib.enableFeature stdenv.hostPlatform.isWindows "video-opengles")
    (lib.enableFeature enableSdltest "sdltest")
    (lib.withFeatureAs alsaSupport "alsa-prefix" "${alsa-lib.out}/lib")
  ];

  postInstall = ''
    moveToOutput bin/sdl2-config "$dev"
  '';

  # 1.
  # We remove libtool .la files when static libs are requested, because they
  # make the builds of downstream libs like `SDL_tff` fail with `cannot find
  # -lXext, `-lXcursor` etc. linker errors, since the `.la` files are not pruned
  # if static libs exist
  # (see https://github.com/NixOS/nixpkgs/commit/fd97db43bcb05e37f6bb77f363f1e1e239d9de53)
  # and they also don't carry the necessary `-L` paths of their X11-related
  # dependencies.
  # For static linking, it is better to rely on `pkg-config` files.

  # 2.
  # SDL is weird in that instead of just dynamically linking with libraries when
  # you `--enable-*` (or when `configure` finds) them it `dlopen`s them at
  # runtime. In principle, this means it can ignore any missing optional
  # dependencies like alsa, pulseaudio, some x11 libs, wayland, etc if they are
  # missing on the system and/or work with wide array of versions of said
  # libraries. In nixpkgs, however, we don't need any of that. Moreover, since
  # we don't have a global ld-cache we have to stuff all the propagated
  # libraries into rpath by hand or else some applications that use SDL API that
  # requires said libraries will fail to start.
  #
  # You can grep SDL sources with `grep -rE 'SDL_(NAME|.*_SYM)'` to list the
  # symbols used in this way.
  postFixup =
    let
      rpath = lib.makeLibraryPath (
        finalAttrs.dlopenPropagatedBuildInputs ++ finalAttrs.dlopenBuildInputs
      );
    in
    (if withStatic then ''rm $out/lib/*.la'' else ''rm $out/lib/*.a'')
    + lib.optionalString (stdenv.hostPlatform.extensions.sharedLibrary == ".so") ''
      for lib in $out/lib/*.so* ; do
        if ! [[ -L "$lib" ]]; then
          patchelf --set-rpath "$(patchelf --print-rpath $lib):${rpath}" "$lib"
        fi
      done
    '';

  setupHook = ./setup-hook.sh;

  passthru = {
    inherit openglSupport;
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "release-(.*)"
      ];
    };
    tests.pkg-config = testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };
  };

  meta = {
    homepage = "http://www.libsdl.org/";
    description = "A cross-platform multimedia library";
    changelog = "https://github.com/libsdl-org/SDL/releases/tag/release-${finalAttrs.version}";
    license = lib.licenses.zlib;
    mainProgram = "sdl2-config";
    maintainers = lib.teams.sdl.members ++ (with lib.maintainers; [ cpages ]);
    pkgConfigModules = [ "sdl2" ];
    platforms = lib.platforms.all;
  };
})
