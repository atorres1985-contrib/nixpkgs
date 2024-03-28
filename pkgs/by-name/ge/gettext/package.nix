{ lib
, bash
, darwin
, fetchurl
, libiconv
, stdenv
, xz

, enableCoreServices ? stdenv.isDarwin
# HACK, see #10874 (and 14664)
, enableLibiconv ? (!stdenv.isLinux && !stdenv.hostPlatform.isCygwin)
}:

# Note: this package is used for bootstrapping fetchurl, and thus cannot use
# fetchpatch! All mutable patches (retrieved via by GitHub, cgit or similar
# means) that perhaps are needed here should be included directly in Nixpkgs as
# regular files inside this same directory.

stdenv.mkDerivation (finalAttrs: ({
  pname = "gettext";
  version = "0.22";

  src = fetchurl {
    url = "mirror://gnu/gettext/gettext-${finalAttrs.version}.tar.gz";
    hash = "sha256-SfCJvhG0kBcLvwntL1Hl9Rd/Vb5MxmUEpYYYIOD7Bqs=";
  };

  patches = [
    # Parameterize some tools to their absolute paths in gettext.sh.in
    ./001-absolute-paths.diff
    # fix reproducibile output, in particular in the grub2 build
    # https://savannah.gnu.org/bugs/index.php?59658
    ./002-msginit-do-not-use-pot-creation-date.patch
  ]
  ++ lib.optionals enableCoreServices [
    # prevent infinite recursion for the darwin stdenv
    ./003-revert-avoid-crash-on-macos-14.patch
  ];

  outputs = [ "out" "man" "doc" "info" ];

  hardeningDisable = [ "format" ];

  configureFlags = [
    (lib.enableFeature false "csharp")
    (lib.withFeature true "xz")
  ] ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    # On cross building, gettext supposes that the wchar.h from libc does not
    # fulfill gettext needs, so it tries to work with its own wchar.h file,
    # which does not cope well with the system's wchar.h and stddef.h (gcc-4.3 -
    # glibc-2.9)
    "gl_cv_func_wcwidth_works=yes"
  ];

  postPatch = ''
   substituteAllInPlace gettext-runtime/src/gettext.sh.in
   substituteInPlace gettext-tools/projects/KDE/trigger --replace "/bin/pwd" pwd
   substituteInPlace gettext-tools/projects/GNOME/trigger --replace "/bin/pwd" pwd
   substituteInPlace gettext-tools/src/project-id --replace "/bin/pwd" pwd
  '' + lib.optionalString stdenv.hostPlatform.isCygwin ''
    sed -i -e "s/\(cldr_plurals_LDADD = \)/\\1..\/gnulib-lib\/libxml_rpl.la /" gettext-tools/src/Makefile.in
    sed -i -e "s/\(libgettextsrc_la_LDFLAGS = \)/\\1..\/gnulib-lib\/libxml_rpl.la /" gettext-tools/src/Makefile.in
  '' + lib.optionalString stdenv.hostPlatform.isMinGW ''
    sed -i "s/@GNULIB_CLOSE@/1/" */*/unistd.in.h
  '';

  nativeBuildInputs = [
    xz
    (lib.getBin xz)
  ];

  buildInputs = lib.optionals (!stdenv.hostPlatform.isMinGW) [
    bash
  ]
  ++ lib.optionals enableLibiconv [
    libiconv
  ]
  ++ lib.optionals enableCoreServices [
    darwin.apple_sdk.frameworks.CoreServices
  ];

  strictDeps = true;

  env = {
    LDFLAGS = lib.optionalString stdenv.isSunOS "-lm -lmd -lmp -luutil -lnvpair -lnsl -lidmap -lavl -lsec";
    gettextNeedsLdflags = stdenv.hostPlatform.libc != "glibc" && !stdenv.hostPlatform.isMusl;
  };

  enableParallelBuilding = true;
  enableParallelChecking = false; # fails sometimes

  setupHooks = [
    ../../../build-support/setup-hooks/role.bash
    ./gettext-setup-hook.sh
  ];

  meta = {
    homepage = "https://www.gnu.org/software/gettext/";
    description = "Well integrated set of translation tools and documentation";
    longDescription = ''
      Usually, programs are written and documented in English, and use English
      at execution time for interacting with users.  Using a common language is
      quite handy for communication between developers, maintainers and users
      from all countries.  On the other hand, most people are less comfortable
      with English than with their own native language, and would rather be
      using their mother tongue for day to day's work, as far as possible.  Many
      would simply love seeing their computer screen showing a lot less of
      English, and far more of their own language.

      GNU gettext is an important step for the GNU Translation Project, as it is
      an asset on which we may build many other steps. This package offers to
      programmers, translators, and even users, a well integrated set of tools
      and documentation. Specifically, the GNU gettext utilities are a set of
      tools that provides a framework to help other GNU packages produce
      multi-lingual messages.
    '';
    mainProgram = "gettext";
    maintainers = with lib.maintainers; [ zimbatm AndersonTorres ];
    license = with lib.licenses; [ gpl2Plus ];
    platforms = lib.platforms.all;
  };
}
// lib.optionalAttrs stdenv.isDarwin {
  makeFlags = [ "CFLAGS=-D_FORTIFY_SOURCE=0" ];
}))
