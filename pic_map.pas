{   Routines for dealing with MPLINK MAP files.
}
module pic_map;
define pic_map_syms_get;
%include 'pic2.ins.pas';
{
********************************************************************************
*
*   Subroutine PIC_MAP_SYMS_GET (SYMS, NSYMS, FNAM, STAT)
*
*   Resolve the values of a list of symbols from reading a MPLINK .map file.
*   SYMS is the list of symbols to resolve, and NSYMS is the number of symbols
*   in the list.  FNAM is the name of the .MAP file to read.
*
*   If the value of a symbol is found in the MAP file, then the VAL field of
*   the SYMS entry for that symbol is set to the value and the FOUND field is
*   set to TRUE.  No data is altered for symbols not found in the MAP file.
}
procedure pic_map_syms_get (           {get values of list of symbols from MAP file}
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
  i: sys_int_machine_t;                {scratch integer and loop counter}
  adr: sys_int_min32_t;                {address converted from HEX number}

begin
  ibuf.max := size_char(ibuf.str);     {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);

  file_open_read_text (fnam, '.map', conn, stat); {open the MAP file for reading}
  if sys_error(stat) then return;

  while true do begin                  {back here to read each new MAP file line}
    file_read_text (conn, ibuf, stat); {read the next MAP file line}
    if file_eof(stat) then exit;       {end of file ?}
    if sys_error(stat) then exit;      {hard error ?}
    string_unpad (ibuf);               {strip trailing blanks from the line}
    if ibuf.len <= 0 then next;        {ignore blank lines}
    string_upcase (ibuf);
    p := 1;                            {init parse index for this line}
    string_token (ibuf, p, tk, stat);  {get the first token on the line}
    if sys_error(stat) then next;
    string_token (ibuf, p, tk2, stat); {get the second token on the line}
    if sys_error(stat) then next;
    if tk2.len < 3 then next;          {not long enough to be 0XNNNNNN integer ?}
    if tk2.str[1] <> '0' then next;    {second token not start with "0X"}
    if tk2.str[2] <> 'X' then next;
    for i := 3 to tk2.len do begin     {move string left to delete the leading "0X"}
      tk2.str[i-2] := tk2.str[i];
      end;
    tk2.len := tk2.len - 2;
    string_t_int32h (tk2, adr, stat);  {convert HEX string to integer value}
    if sys_error(stat) then next;      {not a valid HEX number ?}
{
*   This line defines the value of a symbol.  The symbol name is in TK, and its
*   integer value is in ADR.
*
*   Now scan the list of symbols to resolve and set the value of any that match
*   TK.
}
    for i := 1 to nsyms do begin       {once for each symbol in list to resolve}
      if not string_equal (syms[i].name, tk) then next; {not this symbol ?}
      syms[i].val := adr;              {set value of this symbol}
      syms[i].found := true;           {indicate value was found for this symbol}
      end;                             {back to check next symbol in caller's list}
    end;                               {back for next line of MAP file}
{
*   Done reading MAP file one way or another.  STAT is indicating no error if
*   this was due to end of file, which is the expected terminating condition.
*   If terminated due to error, STAT is set to that error.
}
  file_close (conn);                   {close connection to the MAP file}
  end;
