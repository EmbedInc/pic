{   Program HFX29 <hexnum>
}
program hfx29;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';

var
  tk:                                  {scratch token}
    %include '(cog)lib/string32.ins.pas';
  i32: sys_int_min32_t;
  d: double;                           {final value}
  stat: sys_err_t;                     {completion status}

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (tk, stat);      {get the command line argument}
  sys_error_abort (stat, '', '', nil, 0);
  string_cmline_end_abort;             {nothing further allowed on the command line}

  string_t_int32h (tk, i32, stat);     {convert hex string to integer}
  sys_error_abort (stat, '', '', nil, 0);

  d := i32 / 65536.0;                  {account for 16 fraction bits}
  d := d / 8192.0;                     {another 13 fraction bits, 29 total}

  writeln (d:12:9);
  end.
