{ lib
, autoreconfHook
, fetchpatch
, fetchurl
, pkgsCross
, stdenv
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "npth";
  version = "1.7";

  src = fetchurl {
    url = "mirror://gnupg/npth/npth-${finalAttrs.version}.tar.bz2";
    hash = "sha256-hYn1aTe3XOM7KNMS/MvzArO3HsPzlF/eaqp0AnkUrQU=";
  };

  patches = [
    # Fix INSERT_EXPOSE_RWLOCK_API for musl C library
    (fetchpatch {
      name = "musl.patch";
      url = "https://git.gnupg.org/cgi-bin/gitweb.cgi?p=npth.git;a=patch;h=417abd56fd7bf45cd4948414050615cb1ad59134";
      hash = "sha256-0g2tLFjW1bybNi6oxlW7vPimsQLjmTih4JZSoATjESI=";
    })
  ];

  nativeBuildInputs = [ autoreconfHook ];

  doCheck = true;

  passthru.tests = {
    musl = pkgsCross.musl64.npth;
  };

  meta = {
    homepage = "https://gnupg.org/software/npth/index.html";
    description = "The New GNU Portable Threads Library";
    longDescription = ''
      This is a library to provide the GNU Pth API and thus a non-preemptive
      threads implementation.

      In contrast to GNU Pth is is based on the system's standard threads
      implementation.  This allows the use of libraries which are not
      compatible to GNU Pth.  Experience with a Windows Pth emulation showed
      that this is a solid way to provide a co-routine based framework.
    '';
    license = lib.licenses.lgpl3;
    mainProgram = "npth-config";
    maintainers = with lib.maintainers; [ AndersonTorres ];
    platforms = lib.platforms.all;
  };
})
