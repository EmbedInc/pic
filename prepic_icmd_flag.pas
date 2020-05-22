{   Intrinsic command
*
*   /FLAG name
}
module prepic_icmd_flag;
define prepic_icmd_flag;
%include 'prepic.ins.pas';
{
********************************************************************************
*
*   FLAG name
*
*   Create a new global flag bit with the indicated name.  Several macros to
*   manipulate the flag are also defined.
}
procedure prepic_icmd_flag (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  gfln: sys_int_machine_t;             {0-N number of byte containing this flag}
  name: string_var80_t;                {flag name}
  gflnstr: string_var32_t;             {GFLN number string}
  bitstr: string_var32_t;              {bit number string}
  syname: string_var32_t;              {scratch symbol name}
  tk: string_var132_t;                 {scratch token for string conversion}
  sym_p: escr_sym_p_t;                 {pointer to symbol to create or update}

begin
  if e.inhibit_p^.inh then return;     {execution is inhibited ?}
  name.max := size_char(name.str);     {init local var strings}
  gflnstr.max := size_char(gflnstr.str);
  bitstr.max := size_char(bitstr.str);
  syname.max := size_char(syname.str);
  tk.max := size_char(tk.str);

  if not escr_get_token (e, name) then begin {get NAME parameter}
    escr_stat_cmd_noarg (e, stat);     {required parameter}
    return;
    end;
  if not escr_get_end (e, stat) then return; {no more parameters allowed}
{
*   Determine the GFLn variable number and the bit number within the variable
*   for this flag.  GFLN will be set to the 0-N global flag word number
*   containing this flag, and GFLNSTR the string representation of GFLN.  The
*   global FLAG_BITN is the bit number of this flag within its word, and BITSTR
*   will be its string representation.
}
  nflags := nflags + 1;                {count one more flag created}
  if flag_bitn = 0 then begin          {this is first flag in a new flags byte ?}
    flag_byten := flag_byten + 1;      {one more GFLn flags byte}
    end;
  gfln := flag_byten - 1;              {0-N number of this GFLn flags byte}
  string_f_int (gflnstr, gfln);        {make flags byte number string}
  string_f_int (bitstr, flag_bitn);    {make bit number string}
{
*   Update or create the global constant FLAGDATA_NFLAGS.  This is set to the
*   total number of flags created.
}
  string_vstring (syname, 'Flagdata_nflags'(0), -1); {make name of this symbol}
  escr_sym_find_curr (                 {look for existing constant}
    e,                                 {ESCR library use state}
    syname,                            {name of symbol to look for}
    escr_sytype_const_k,               {symbol type}
    sym_p);                            {pointer to symbol, NIL for not found}

  if sym_p = nil then begin            {doesn't already exist, need to create ?}
    escr_sym_new_const (               {create the new symbol}
      e,                               {script system state}
      syname,                          {name of symbol to create}
      escr_dtype_int_k,                {value will be integer}
      true,                            {make new symbol global}
      sym_p,                           {returned pointer to the new symbol}
      stat);
    if sys_error(stat) then return;
    end;

  sym_p^.const_val.int := nflags;      {set or update total number of flags}
{
*   Update or create the global constant FLAGDATA_NWORDS.  This is set to the
*   total number of flag words used.
}
  string_vstring (syname, 'Flagdata_nwords'(0), -1); {make name of this symbol}
  escr_sym_find_curr (                 {look for existing constant}
    e,                                 {ESCR library use state}
    syname,                            {name of symbol to look for}
    escr_sytype_const_k,               {symbol type}
    sym_p);                            {pointer to symbol, NIL for not found}

  if sym_p = nil then begin            {doesn't already exist, need to create ?}
    escr_sym_new_const (               {create the new symbol}
      e,                               {script system state}
      syname,                          {name of symbol to create}
      escr_dtype_int_k,                {value will be integer}
      true,                            {make new symbol global}
      sym_p,                           {returned pointer to the new symbol}
      stat);
    if sys_error(stat) then return;
    end;

  sym_p^.const_val.int := flag_byten;  {set or update total number of flag words}
{
*   Create the FLAGDATA_FLAGn constant for this flag.  This is a string that
*   contains 3 tokens: flag name, 0-N number of the flag word, and 0-N number of
*   the bit within the flag word.
}
  string_vstring (syname, 'Flagdata_flag'(0), -1); {make name of this symbol}
  string_f_int (tk, nflags);
  string_append (syname, tk);

  tk.len := 0;                         {init the constant string value}
  string_append_token (tk, name);      {add flag name}
  string_append_token (tk, gflnstr);   {add GLFn number}
  string_append_token (tk, bitstr);    {add bit number within GFLn word}

  escr_sym_new_const (                 {create the string constant}
    e,                                 {script system state}
    syname,                            {name of constant to create}
    escr_dtype_str_k,                  {value will be a string}
    true,                              {make new symbol global}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  if sys_error(stat) then return;

  strflex_copy_f_vstr (tk, sym_p^.const_val.stf); {set the constant's value}

  case lang of                         {what is the input source language ?}
{
********************
*
*   Input source language is MPASM.
}
lang_aspic_k: begin
{
*   Update the assembler variable NFLAGB if an additional GFLx flag byte
*   is required:
*
*   NFLAGB set <n>
}
  if flag_bitn = 0 then begin          {starting a new flags byte ?}
    string_vstring (e.obuf, 'nflagb set '(0), -1);
    string_f_int (tk, flag_byten);
    string_append (e.obuf, tk);
    escr_write_obuf (e, stat);
    if sys_error(stat) then return;
    end;
{
*   flag_<name>_regn equ <gfl n>
}
  string_vstring (e.obuf, 'flag_'(0), -1);
  string_append (e.obuf, name);
  string_appends (e.obuf, '_regn equ '(0));
  string_append (e.obuf, gflnstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   #define flag_<name>_reg gflx
}
  string_vstring (e.obuf, '#define flag_'(0), -1);
  string_append (e.obuf, name);
  string_appends (e.obuf, '_reg gfl'(0));
  string_append (e.obuf, gflnstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   flag_<name>_bit equ <n>
}
  string_vstring (e.obuf, 'flag_'(0), -1);
  string_append (e.obuf, name);
  string_appends (e.obuf, '_bit equ '(0));
  string_append (e.obuf, bitstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   #define flag_<name> gfl<n>,<bit>
}
  string_vstring (e.obuf, '#define flag_'(0), -1);
  string_append (e.obuf, name);
  string_appends (e.obuf, ' gfl'(0));
  string_append (e.obuf, gflnstr);
  string_append1 (e.obuf, ',');
  string_append (e.obuf, bitstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update the flags state for next time.
}
  flag_bitn := flag_bitn + 1;          {make bit number for next flag}
  if flag_bitn >= 8 then flag_bitn := 0; {starting with new byte next time ?}
  end;                                 {end of MPASM language case}
{
********************
*
*   Input source language is ASM30.
}
lang_dspic_k: begin
{
*   Update the assembler variable NFLAGB if an additional GFLx flags
*   word is required:
*
*   .set nflagb <n>
}
  if flag_bitn = 0 then begin          {starting a new flags word ?}
    string_appends (e.obuf, '.set nflagb, '(0));
    string_f_int (tk, flag_byten);
    string_append (e.obuf, tk);
    escr_write_obuf (e, stat);
    if sys_error(stat) then return;
    end;
{
*   .equ flag_<name>_regn, <gfl n>
}
  string_appends (e.obuf, '.equ flag_'(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_regn, '(0));
  string_append (e.obuf, gflnstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .equ flag_<name>_reg, <gflx>
}
  string_appends (e.obuf, '.equ flag_'(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_reg, gfl'(0));
  string_append (e.obuf, gflnstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .equ flag_<name>_bit, <n>
}
  string_appends (e.obuf, '.equ flag_'(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_bit, '(0));
  string_append (e.obuf, bitstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;


(*
{
*   #define flag_<name> gfl<n>,<bit>
}
  string_appends (e.obuf, '#define flag_'(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, ' gfl'(0));
  string_append (e.obuf, gflnstr);
  string_append1 (e.obuf, ',');
  string_append (e.obuf, bitstr);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
*)

{
*   Update the flags state for next time.
}
  flag_bitn := flag_bitn + 1;          {make bit number for next flag}
  if flag_bitn >= 16 then flag_bitn := 0; {starting with new word next time ?}
  end;                                 {end of ASM30 language case}
{
********************
*
*   Unexpected input source file language.
}
otherwise
    err_lang (lang, 'PREPIC_CMD_FLAG', 1);
    end;
  end;
