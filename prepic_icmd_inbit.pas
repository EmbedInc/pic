{   Commands INBIT and INANA
*
*   INBIT defines a I/O pin as a digital input, and INANA as a analog input.
*   Both these commands are in the same module so that they can share common
*   code.
}
module prepic_icmd_inbit;
define prepic_icmd_inbit;
define prepic_icmd_inana;
%include 'prepic.ins.pas';

type
  intype_k_t = (                       {ID for each type of input pin}
    intype_dig_k,                      {digital input}
    intype_ana_k);                     {analog input}

procedure input_pin (                  {common code for all input pin definitions}
  in out  e: escr_t;                   {ESCR library use state}
  in      intype: intype_k_t;          {specific type of input being defined}
  out     stat: sys_err_t);            {completion status}
  val_param; forward;
{
********************************************************************************
*
*   /INBIT name port bit [PUP]
*
*   Declares a I/O pin to be configured as a digital input.
}
procedure prepic_icmd_inbit (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

begin
  input_pin (e, intype_dig_k, stat);   {process the command for digital input}
  end;
{
********************************************************************************
*
*   /INANA name port bit ANx
*
*   Declares a I/O pin is to be configured as a analog input.
}
procedure prepic_icmd_inana (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

begin
  input_pin (e, intype_ana_k, stat);   {process the command for analog input}
  end;
{
********************************************************************************
*
*   Local subroutine INPUT_PIN (E, INTYPE, STAT)
*
*   Common code to process the various commands that define input pins.  INTYPE
*   specifies the particular input type the pin is being defined as.
*
*   The remaining tokens on the command line for each INTYPE are:
*
*     INTYPE_DIG_K  (from INBIT command)
*
*       name port bit [PUP]
*
*     INTYPE_ANA_K  (from INANA command)
*
*       name port bit ANx
*
*   PORT is the name of the port containing the bit, and BIT is the bit number
*   within the port register.  The following assembler constants will be
*   declared:
*
*     <name>_reg   -  Address of port register containing I/O bit.
*     <name>_tris  -  Address of TRIS register controlling in/out direction.
*     <name>_bit   -  Number of bit within port and tris regs for this I/O bit.
*     <name>_lat   -  Address of LAT register for this port, if any.
*
*   The following assembler variables will be updated:
*
*     VAL_TRISx  -  Initial value for TRIS register
*     VAL_PULLUPx  -  Indicates which pins need pullups enabled
*     VAL_ANALOGx  -  Indicates which pins should be configured as analog
*     ANALOGUSED0  -  Mask of which analog channels 0-31 are used
*     ANALOGUSED1  -  Mask of which analog channels 32-63 are used
*
*   String substitution macros will be defined:
*
*     #define <name>_pin <port>,<bit>
*     #define <name>_pinlat <lat>,<bit>
*
*   Preprocessor constants will be created:
*
*     PORTDATA_<port><bit>: name IN POS|NEG DIG|ANA
*     INBIT_<name>_PORT: <port>
*     INBIT_<name>_BIT: <bit>
}
procedure input_pin (                  {common code for all input pin definitions}
  in out  e: escr_t;                   {ESCR library use state}
  in      intype: intype_k_t;          {specific type of input being defined}
  out     stat: sys_err_t);            {completion status}
  val_param;

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  pick: sys_int_machine_t;             {number of token picked from list}
  portl: char;                         {A-Z I/O port name, lower case}
  portu: char;                         {A-Z I/O port name, upper case}
  pup: boolean;                        {enable passive pullup}
  ana: boolean;                        {flag pin as analog}
  an: sys_int_machine_t;               {0-N analog channel number}
  name: string_var80_t;                {I/O bit name}
  namel: string_var80_t;               {lower case I/O bit name}
  im: sys_int_max_t;                   {max size integer}
  ii: sys_int_machine_t;               {scratch integer}
  bit: sys_int_machine_t;              {number of I/O bit within port register}
  strbit: string_var16_t;              {decimal integer I/O bit number string}
  tk: string_var80_t;                  {scratch tokens}
  tk2, tk3: string_var32_t;
  syname: string_var32_t;              {scratch symbol name}
  sym_p: escr_sym_p_t;                 {pointer to newly created symbol}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

label
  err_anx;

begin
  if e.inhibit_p^.inh then return;     {execution is inhibited ?}
  name.max := size_char(name.str);     {init local var strings}
  namel.max := size_char(namel.str);
  strbit.max := size_char(strbit.str);
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  tk3.max := size_char(tk3.str);
  syname.max := size_char(syname.str);

  ana := intype = intype_ana_k;        {this pin is analog ?}
{
*   Get NAME.
}
  if not escr_get_token (e, name) then begin {get NAME parameter}
    escr_stat_cmd_noarg (e, stat);
    return;
    end;

  string_copy (name, namel);           {make lower case version of name}
  string_downcase (namel);
{
*   Get PORTx parameter.
}
  if not escr_get_token (e, tk) then begin {get PORTx parameter}
    escr_stat_cmd_noarg (e, stat);
    return;
    end;

  string_downcase (tk);                {make lower case port register name}
  portl := tk.str[5];                  {extract lower case a-z port letter}
  if                                   {invalid port register name ?}
      (tk.len <> 5) or                 {not right length for "PORTx"}
      (tk.str[1] <> 'p') or            {does not start with "port"}
      (tk.str[2] <> 'o') or
      (tk.str[3] <> 'r') or
      (tk.str[4] <> 't') or
      (portl < 'a') or (portl > 'z')   {not a valid port letter ?}
      then begin
    err_parm_last_bad;
    end;
  portu := string_upcase_char (portl); {make upper case port letter}
{
*   Get bit number parameter.
}
  if not escr_get_int (e, im, stat) then begin {get bit number}
    escr_stat_cmd_noarg (e, stat);
    return;
    end;
  bit := im;                           {save the bit number into BIT}

  if bit < 0 then err_parm_last_bad;   {negative bit numbers not allowed}
  case lang of
lang_aspic_k: begin                    {MPASM}
      if bit > 7 then err_parm_last_bad; {bit value too large ?}
      end;
lang_dspic_k: begin                    {ASM30}
      if bit > 15 then err_parm_last_bad; {bit value too large ?}
      end;
otherwise
    err_lang (lang, 'PREPIC_ICMD_INBIT', 1);
    end;
  string_f_int (strbit, bit);          {make bit number string}
{
*   Get optional PUP parameter.  This is only allowed for non-analog pins.
}
  pup := false;                        {init to default of not enable pullup}

  if not ana then begin                {not a analog pin ?}
    escr_get_keyword (e, 'PUP', pick, stat); {get keyword, pick from list}
    if sys_error(stat) then return;
    case pick of
1:    pup := true;
      end;
    end;
{
*   Read the ANx parameter and set AN to the analog channel number.  This is
*   only for analog pins.
}
  if ana then begin                    {analog pin ?}
    if not escr_get_token (e, tk) then begin
      err_atline ('pic', 'err_anx_none', nil, 0);
      end;
    string_upcase (tk);                {upper case to make case-insensitive}
    if tk.len < 3 then begin
err_anx:                               {invalid ANx parameter}
      sys_msg_parm_vstr (msg_parm[1], tk);
      err_atline ('pic', 'err_anx_bad', msg_parm, 1);
      end;
    if (tk.str[1] <> 'A') or (tk.str[2] <> 'N') then goto err_anx;
    string_substr (tk, 3, tk.len, tk2); {get number string after the "AN"}
    string_t_int (tk2, an, stat);      {convert to integer in AN}
    if sys_error(stat) then return;
    if (an < 0) or (an > 63) then goto err_anx; {AN number is out of range ?}
    end;
{
*   Done reading the command parameters.
}
  if not escr_get_end (e, stat) then return; {no more parameters allowed}
{
*   Create the preprocessor constant Portdata_<port><bit> where PORT is the
*   single letter port name and BIT is the 0-N number of this bit within the
*   port.
}
  syname.len := 0;                     {build the constant name}
  string_appends (syname, 'Portdata_'(0));
  string_append1 (syname, portl);
  string_append (syname, strbit);

  escr_sym_find_curr (                 {find constant if it already exists}
    e,                                 {ESCR library use state}
    syname,                            {name of symbol to look for}
    escr_sytype_const_k,               {symbol type}
    sym_p);                            {returned pointer to symbol, NIL if not found}
  if sym_p <> nil then begin           {already exists ?}
    escr_sym_del (e, sym_p, stat);     {delete it}
    if sys_error(stat) then return;
    end;

  tk.len := 0;                         {build the constant string value}
  string_append_token (tk, name);      {add name of this I/O pin}
  string_append_token (tk, string_v('IN'(0))); {this is a input bit}
  string_append_token (tk, string_v('POS'(0))); {all INBIT positive logic for now}
  if ana
    then begin                         {analog pin}
      string_append_token (tk, string_v('ANA'(0)));
      string_vstring (tk2, 'AN'(0), -1); {make start of ANx parameter}
      string_f_int (tk3, an);          {make analog channel number string}
      string_append (tk2, tk3);        {assemble the whole ANx parameter}
      string_append_token (tk, tk2);   {add ANx parameter}
      end
    else begin                         {digital pin}
      string_append_token (tk, string_v('DIG'(0)));
      end
    ;

  escr_sym_new_const (                 {create the constant}
    e,                                 {script system state}
    syname,                            {name of the constant}
    escr_dtype_str_k,                  {value will be a string}
    tk.len,                            {string length}
    true,                              {make this new symbol global}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  if sys_error(stat) then return;
  string_copy (tk, sym_p^.const_val.str); {set the constant's value}
{
*   Create the preprocessor constant
*
*     Inbit_<name>_port
*
*   This is a string constant that contains the upper case name of the port.
*   For example, if the bit is within Port B, then the value of this constant
*   would be "B".
}
  syname.len := 0;                     {build the constant name}
  string_appends (syname, 'Inbit_'(0));
  string_append (syname, namel);
  string_appends (syname, '_port'(0));

  escr_sym_find_curr (                 {find constant if it already exists}
    e,                                 {ESCR library use state}
    syname,                            {name of symbol to look for}
    escr_sytype_const_k,               {symbol type}
    sym_p);                            {returned pointer to symbol, NIL if not found}
  if sym_p <> nil then begin           {already exists ?}
    sys_msg_parm_vstr (msg_parm[1], name);
    err_atline ('pic', 'err_inbit_dup', msg_parm, 1); {bomb with error message}
    end;

  tk.len := 0;                         {build the string value}
  string_append1 (tk, portu);

  escr_sym_new_const (                 {create the constant}
    e,                                 {script system state}
    syname,                            {name of the constant}
    escr_dtype_str_k,                  {value will be a string}
    tk.len,                            {string length}
    true,                              {make this new symbol global}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  if sys_error(stat) then return;
  string_copy (tk, sym_p^.const_val.str); {set the constant's value}
{
*   Create the preprocessor constant
*
*     Inbit_<name>_bit
*
*   This is a integer constant set to the bit number of this inbit within its
*   port register.
}
  syname.len := 0;                     {build the constant name}
  string_appends (syname, 'Inbit_'(0));
  string_append (syname, namel);
  string_appends (syname, '_bit'(0));

  escr_sym_find_curr (                 {find constant if it already exists}
    e,                                 {ESCR library use state}
    syname,                            {name of symbol to look for}
    escr_sytype_const_k,               {symbol type}
    sym_p);                            {returned pointer to symbol, NIL if not found}
  if sym_p <> nil then begin           {already exists ?}
    sys_msg_parm_vstr (msg_parm[1], name);
    err_atline ('pic', 'err_inbit_dup', msg_parm, 1); {bomb with error message}
    end;

  escr_sym_new_const (                 {create the constant}
    e,                                 {script sstem state}
    syname,                            {name of the constant}
    escr_dtype_int_k,                  {value will be integer}
    0,                                 {unused for integer data type}
    true,                              {make this new symbol global}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  if sys_error(stat) then return;
  sym_p^.const_val.int := bit;         {set the value of the new constant}

  case lang of                         {what is the input source language ?}
{
********************
*
*   Input source language is MPASM.
}
lang_aspic_k: begin
{
*   <name>_reg equ portx
}
  string_append (e.obuf, name);
  string_appends (e.obuf, '_reg equ port'(0));
  string_append1 (e.obuf, portl);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*     ifdef trisx
*   <name>_tris equ trisx
*       endif
}
  string_appends (e.obuf, '  ifdef tris'(0));
  string_append1 (e.obuf, portl);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

  string_append (e.obuf, name);
  string_appends (e.obuf, '_tris equ tris'(0));
  string_append1 (e.obuf, portl);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

  string_appends (e.obuf, '    endif'(0));
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   <name>_bit equ <bit>
}
  string_append (e.obuf, name);
  string_appends (e.obuf, '_bit equ '(0));
  string_append (e.obuf, strbit);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   val_trisx set val_trisx | (1 << <bit>)
}
  string_appends (e.obuf, 'val_tris'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ' set val_tris'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ' | (1 << '(0));
  string_append (e.obuf, strbit);
  string_appends (e.obuf, ')'(0));
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update VAL_PULLUPx according to the PUP parameter.
}
  if pup
    then begin                         {pullup enabled}
      {
      *   val_pullupx set val_pullupx | (1 << <bit>)
      }
      string_appends (e.obuf, 'val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ' set val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  | (1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    else begin                         {pullup disabled}
      {
      *   val_pullupx set val_pullupx & ~(1 << <bit>)
      }
      string_appends (e.obuf, 'val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ' set val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  & ~(1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    ;
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update VAL_ANALOGx according to the ANA parameter.
}
  if ana
    then begin                         {analog pin}
      {
      *   val_analogx set val_analogx | (1 << <bit>)
      }
      string_appends (e.obuf, 'val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ' set val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  | (1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    else begin                         {digital pin}
      {
      *   val_analogx set val_analogx & ~(1 << <bit>)
      }
      string_appends (e.obuf, 'val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ' set val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  & ~(1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    ;
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update ANALOGUSEDn for this analog channel.
*
*   analogusedN set analogusedN | (1 << M)
}
  if ana then begin
    ii := rshft(an, 5);                {make ANALOGUSED variable number}

    string_appends (e.obuf, 'analogused'(0));
    string_append_intu (e.obuf, ii, 0);
    string_appends (e.obuf, ' set analogused'(0));
    string_append_intu (e.obuf, ii, 0);
    string_appends (e.obuf, ' | (1 << '(0));
    string_append_intu (e.obuf, an & 16#1F, 0);
    string_appends (e.obuf, ')'(0));
    escr_write_obuf (e, stat);
    if sys_error(stat) then return;
    end;
{
*   #define <name>_pin portx,<bit>
}
  string_appends (e.obuf, '#define '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_pin port'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ',');
  string_append (e.obuf, strbit);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*     ifdef latx
*   <name>_lat equ latx
*   #define <name>_pinlat latx,<bit>
*       endif
}
  string_appends (e.obuf, '  ifdef lat'(0));
  string_append1 (e.obuf, portl);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

  string_append (e.obuf, name);
  string_appends (e.obuf, '_lat equ lat'(0));
  string_append1 (e.obuf, portl);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

  string_appends (e.obuf, '#define '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_pinlat lat'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ','(0));
  string_append (e.obuf, strbit);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

  string_appends (e.obuf, '    endif'(0));
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;

    end;                               {end of MPASM language case}
{
********************
*
*   Input source language is ASM30.
}
lang_dspic_k: begin
{
*   .equ <name>_reg, _PORTx
}
  string_appends (e.obuf, '.equ '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_reg, _PORT'(0));
  string_append1 (e.obuf, portu);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .equ <name>_tris, _TRISx
}
  string_appends (e.obuf, '.equ '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_tris, _TRIS'(0));
  string_append1 (e.obuf, portu);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .equ <name>_bit, <bit>
}
  string_appends (e.obuf, '.equ '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_bit, '(0));
  string_append (e.obuf, strbit);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .equ <name>_lat, _LATx
}
  string_appends (e.obuf, '.equ '(0));
  string_append (e.obuf, name);
  string_appends (e.obuf, '_lat, _LAT'(0));
  string_append1 (e.obuf, portu);
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   .set val_trisx, val_trisx | (1 << <bit>)
}
  string_appends (e.obuf, '.set val_tris'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ', val_tris'(0));
  string_append1 (e.obuf, portl);
  string_appends (e.obuf, ' | (1 << '(0));
  string_append (e.obuf, strbit);
  string_appends (e.obuf, ')'(0));
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update VAL_PULLUPx according to the PUP parameter.
}
  if pup
    then begin                         {pullup enabled}
      {
      *   .set val_pullupx, val_pullupx | (1 << <bit>)
      }
      string_appends (e.obuf, '.set val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ', val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  | (1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    else begin                         {pullup disabled}
      {
      *   .set val_pullupx, val_pullupx & ~(1 << <bit>)
      }
      string_appends (e.obuf, '.set val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ', val_pullup'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  & ~(1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    ;
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update VAL_ANALOGx according to the PUP parameter.
}
  if ana
    then begin                         {analog pin}
      {
      *   .set val_analogx, val_analogx | (1 << <bit>)
      }
      string_appends (e.obuf, '.set val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ', val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  | (1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    else begin                         {digital pin}
      {
      *   .set val_analogx, val_analogx & ~(1 << <bit>)
      }
      string_appends (e.obuf, '.set val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, ', val_analog'(0));
      string_append1 (e.obuf, portl);
      string_appends (e.obuf, '  & ~(1 << '(0));
      string_append (e.obuf, strbit);
      string_appends (e.obuf, ')'(0));
      end
    ;
  escr_write_obuf (e, stat);
  if sys_error(stat) then return;
{
*   Update ANALOGUSEDn for this analog channel.
*
*   .set analogusedN, analogusedN | (1 << M)
}
  if ana then begin
    ii := rshft(an, 5);                {make ANALOGUSED variable number}

    string_appends (e.obuf, '.set analogused'(0));
    string_append_intu (e.obuf, ii, 0);
    string_appends (e.obuf, ', analogused'(0));
    string_append_intu (e.obuf, ii, 0);
    string_appends (e.obuf, ' | (1 << '(0));
    string_append_intu (e.obuf, an & 16#1F, 0);
    string_appends (e.obuf, ')'(0));
    escr_write_obuf (e, stat);
    if sys_error(stat) then return;
    end;

    end;                               {end of ASM30 language case}
{
********************
*
*   Unexpected input source file language.
}
otherwise
    err_lang (lang, 'PREPIC_CMD_INBIT', 2);
    end;
  end;
