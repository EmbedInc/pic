{   Routines for dealing with MPLINK MAP files.
}
module pic_map;
define pic_map_syms30_get;
%include 'pic2.ins.pas';
{
********************************************************************************
*
*   Subroutine PIC_MAP_SYMS30_GET (SYMS, NSYMS, FNAM, STAT)
*
*   Resolve the values of a list of symbols from reading a dsPIC .map file.
*   SYMS is the list of symbols to resolve, and NSYMS is the number of symbols
*   in the list.  FNAM is the name of the .MAP file to read.
*
*   If the value of a symbol is found in the MAP file, then the VAL field of
*   the SYMS entry for that symbol is set to the value and the FOUND field is
*   set to TRUE.  No data is altered for symbols not found in the MAP file.
}
procedure pic_map_syms30_get (         {get values of list of symbols from dsPIC MAP file}
  in out  syms: univ pic_mapsym_ar_t;  {list of symbols to resolve}
  in      nsyms: sys_int_machine_t;    {number of symbols in the list}
  in      fnam: univ string_var_arg_t; {name of MAP file to read}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  conn: file_conn_t;                   {connection to the MAP file}
  ibuf: string_var132_t;               {one line MAP file input buffer}
  p: string_index_t;                   {IBUF parse index}
  tk, tk2: string_var32_t;             {scratch tokens}
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  adr: sys_int_min32_t;                {address converted from HEX number}

begin
  ibuf.max := size_char(ibuf.str);     {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);

  file_open_read_text (fnam, '.map', conn, stat); {open the MAP file for reading}
  if sys_error(stat) then return;

  while true do begin                  {back here to read each new MAP file line}
    file_read_text (conn, ibuf, stat); {read the next MAP file line}
    if sys_error(stat) then exit;      {didn't get next line ?}
    string_unpad (ibuf);               {strip trailing blanks from the line}
    if ibuf.len <= 0 then next;        {ignore blank lines}
    p := 1;                            {init parse index for this line}
    {
    *   Process the first token.  This must be the symbol value with the format
    *   0xHHH, where HHH is 1 to 8 hexadecimal digits.
    }
    string_token (ibuf, p, tk, stat);  {get the first token on the line}
    if sys_error(stat) then next;      {no token available ?}
    if tk.len < 3 then next;           {not at least 0xH ?}
    if tk.len > 10 then next;          {too long for 0xHHHHHHHH ?}
    string_substr (tk, 3, tk.len, tk2); {extract just the HEX digits}
    string_t_int32h (tk2, adr, stat);  {get value of HEX string into ADR}
    if sys_error(stat) then next;      {not a valid HEX number ?}
    {
    *   Get the second token.  This is the symbol name.  Save it in TK.
    }
    string_token (ibuf, p, tk, stat);  {get the second token on the line}
    if sys_error(stat) then next;
    {
    *   Check for next token.  The line must either end here, or the next token
    *   must be "=".
    }
    string_token (ibuf, p, tk2, stat); {try to get third token on line}
    if not string_eos(stat) then begin {othern than end of line ?}
      if sys_error(stat) then return;  {hard error}
      if tk2.len <> 1 then next;       {skip this line if not "="}
      if tk2.str[1] <> '=' then next;
      end;
    {
    *   This is a valid symbol definition line.  The symbol name is in TK, and
    *   its address in ADR.
    }
    for ii := 1 to nsyms do begin      {once for each symbol in list to resolve}
      if not string_equal (syms[ii].name, tk) then next; {not this symbol ?}
      syms[ii].val := adr;             {set value of this symbol}
      syms[ii].found := true;          {indicate value was found for this symbol}
      end;                             {back to check next symbol in caller's list}
    end;                               {back for next line of MAP file}
{
*   Done reading MAP file one way or another.  STAT is indicating the reason why
*   the next line could not be read.
}
  discard( file_eof(stat) );           {no error if hit end of file normally}
  file_close (conn);                   {close connection to the MAP file}
  end;
