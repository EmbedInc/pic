{   Program FILTBITS b1 ... bN
*
*   Show the 0 to 1 step response of an N pole butterworth discrete
*   filter.  Each command line parameter is the number of bits to shift
*   to create the filter fraction for one pole.  For example, if a command
*   line parameter is 3, then each filter iteration will result in 1/8 of
*   the new value plus 7/8 of the old value.
}
program filtbits;
%include 'base.ins.pas';
%include 'math.ins.pas';

const
  max_poles = 100;                     {maximum poles allowed in the filter}
  thresh_stop = 0.999;                 {stop when output reaches this level}
  max_msg_args = 1;                    {max arguments we can pass to a message}

type
  filt_t =                             {state for one compound filter}
    array[0 .. max_poles] of double;

var
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  r: real;                             {scratch floating point number}
  iter: sys_int_machine_t;             {number of interactions performed}
  poles: sys_int_machine_t;            {number of poles in the filter}
  frac: array[1 .. max_poles] of double; {filter fractions for each pole}
  step: filt_t;                        {filter with unit step input}
  impulse: filt_t;                     {filter with unit impulse input}
  noise: filt_t;                       {filter with white noise input}
  rand: math_rand_seed_t;              {random number generator state}
  seed: sys_int_machine_t;             {random number generator initial seed}
  enditer: sys_int_machine_t;          {ending iteration number when TOITER set}
  toiter: boolean;                     {run to specific iteration}

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts;
{
********************************************************************************
*
*   Subroutine FILT_ITERATION (FILT)
*
*   Perform one iteration of the filter FILT.  The input value is FILT[0], and
*   the remaining values are the peristant state for each pole.  POLES indicates
*   the number of poles in the filter.  FRAC is the array of filter fractions,
*   one for each pole.
}
procedure filt_iteration (             {perform one iteration of a filter}
  in out  filt: filt_t);               {filter state to update}
  val_param; internal;

var
  ii: sys_int_machine_t;

begin
  for ii := 1 to poles do begin        {once for each pole of the compound filter}
    filt[ii] := filt[ii] + frac[ii]*(filt[ii-1] - filt[ii]);
    end;
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
  poles := 0;                          {init number of filter poles}
  toiter := false;                     {not end at specific iteration}
  seed := -123456;                     {arbitrary random number generator seed}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  {
  *   Try to handle as unlabeled filter fraction value.
  }
  string_t_fpm (opt, r, stat);
  if not sys_error(stat) then begin    {command line option is bare numeric value ?}
    if poles >= max_poles then begin   {too many poles defined ?}
      sys_msg_parm_int (msg_parm[1], max_poles);
      sys_message_bomb ('pic', 'poles_too_many', msg_parm, 1);
      end;
    poles := poles + 1;                {count one more pole in the filter}
    frac[poles] := 2.0**(-r);          {make filter fraction for this pole}
    goto next_opt;
    end;
  sys_error_none (stat);
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-TO',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -TO iteration
}
1: begin
  string_cmline_token_int (enditer, stat);
  toiter := true;
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
  if poles <= 0 then begin             {no poles defined ?}
    sys_message_bomb ('pic', 'poles_zero', nil, 0);
    end;
{
*   POLES and FRAC all set.
*
*   Now initialize the filter values.
}
  math_rand_init_int (seed, rand);     {initialize the random number generator}

  for ii := 0 to poles do begin
    step[ii] := 0.0;
    impulse[ii] := 0.0;
    noise[ii] := 0.5;
    end;

  step[0] := 1.0;                      {step input is fixed}
{
*   Keep doing filter iterations until the overall output value reaches or
*   exceeds the THRESH_STOP threshold.
}
  writeln ('Iteration, Step, Impulse, Noise');
  iter := 0;                           {init number of filter iterations performed}
  writeln (iter:9, ',', step[poles]:9:6, ',', impulse[poles]:9:6, ',', noise[poles]:9:6);

  while true do begin                  {back here each new filter iteration}
    {
    *   Set the inputs to the various filters for this iteration.  ITER is the
    *   0-N iteration number.
    }
    if iter = 0
      then impulse[0] := 1.0
      else impulse[0] := 0.0;
    noise[0] := math_rand_real (rand);

    iter := iter + 1;                  {make 1-N number of this iteration}
    filt_iteration (step);
    filt_iteration (impulse);
    filt_iteration (noise);
    writeln (iter:9, ',', step[poles]:9:6, ',', impulse[poles]:9:6, ',', noise[poles]:9:6);
    if toiter
      then begin                       {end at specific iteration}
        if iter >= enditer then exit;
        end
      else begin                       {end automatically at step response threshold}
        if step[poles] >= thresh_stop then exit;
        end
      ;
    end;                               {back to do next iteration}
  end.
