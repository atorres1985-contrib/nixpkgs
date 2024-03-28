{ lib
, fetchurl
, stdenv
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pth";
  version = "2.0.7";

  src = fetchurl {
    url = "mirror://gnu/pth/pth-${finalAttrs.version}.tar.gz";
    hash = "sha256-cjU2YMWiyq/WAbIOEuddhl/Yj2zxoIizBqOWPwvHcjI=";
  };

  preConfigure = lib.optionalString stdenv.isAarch32 ''
    configureFlagsArray=("CFLAGS=-DJB_SP=8 -DJB_PC=9")
  '' + lib.optionalString (stdenv.hostPlatform.libc == "glibc") ''
    configureFlagsArray+=("ac_cv_check_sjlj=ssjlj")
  '';

  # Fails parallel build due to missing dependency on autogenrated
  # 'pth_p.h' file:
  #     ./shtool scpp -o pth_p.h ...
  #     ./libtool --mode=compile --quiet gcc -c -I. -O2 -pipe pth_uctx.c
  #     pth_uctx.c:31:10: fatal error: pth_p.h: No such file
  enableParallelBuilding = false;

  meta = {
    homepage = "https://www.gnu.org/software/pth";
    description = "The GNU Portable Threads library";
    longDescription = ''
      Pth is a very portable POSIX/ANSI-C based library for Unix platforms which
      provides non-preemptive priority-based scheduling for multiple threads of
      execution (aka `multithreading') inside event-driven applications. All
      threads run in the same address space of the server application, but each
      thread has it's own individual program-counter, run-time stack, signal
      mask and errno variable.

      The thread scheduling itself is done in a cooperative way, i.e., the
      threads are managed by a priority- and event-based non-preemptive
      scheduler. The intention is that this way one can achieve better
      portability and run-time performance than with preemptive scheduling. The
      event facility allows threads to wait until various types of events occur,
      including pending I/O on filedescriptors, asynchronous signals, elapsed
      timers, pending I/O on message ports, thread and process termination, and
      even customized callback functions.

      Additionally Pth provides an optional emulation API for POSIX.1c threads
      ("Pthreads") which can be used for backward compatibility to existing
      multithreaded applications.
    '';
    license = lib.licenses.lgpl21Plus;
    mainProgram = "pth-config";
    maintainers = with lib.maintainers; [ AndersonTorres ];
    platforms = lib.platforms.all;
  };
})
