/*   Messages for the PIC library and associated applications.
/*
msg err_anx_bad
  lan english -def
    Parameter "%p1s" is not a valid ANx parameter.
msg err_anx_none
  lan english -def
    Missing ANx parameter to /INANA command.
msg err_cmd_mpasm
  lan english -def
    Error on attempt to run the MPLAB PIC assembler.  This is usually
    caused by the MPLABDir environment variable not set or set
    incorrectly.  See the ASMPIC documentation file for details. The
    command line was:
    .nfill
    %p1s
msg err_cmd_prepic
  lan english -def
    Error on attempt to run PIC assembler preprocessor.  The command line
    was:
    .nfill
    %p1s
msg err_dspic_linkdir
  lan english -def
    Unable to open the dsPIC linker files directory "%p1s".  The DSPICDIR
    environment variable may be set incorrectly.
msg err_inbit_dup
  lan english -def
    A /INBIT of name "%p1s" was previously defined.
msg err_lang
  lan english -def
    Screwup in program PREPIC: Input source code language with ID %p1i
    not implemented in module %p2s, checkpoint %p3i.  Oops.
msg err_prepic_insuff
  lan english -def
    Invalid input file to PREPIC.  The input file name must contain one of
    the allowed suffixes.
msg poles_too_many
  lan english -def
    Too many poles specified, only up to %p1i are supported.
msg poles_zero
  lan english -def
    No poles specified, at least one is required.
