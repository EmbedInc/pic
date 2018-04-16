{   ASPIC_FIX <options>
*
*   Fix the formatting of a PIC assembler source file.
}
program aspic_fix;
%include '(cog)lib/base.ins.pas';

const
  def_col_opc_k = 10;                  {default column for opcodes}
  def_col_oper_k = 18;                 {default column for operands}
  def_col_com_k = 30;                  {default column for end of line comments}
  max_msg_args = 2;                    {max arguments we can pass to a message}

type
  precmd_p_t = ^precmd_t;

  line_p_t = ^line_t;
  line_t = record                      {info about one input file line}
    next_p: line_p_t;                  {points to info about next input file line}
    lnum: sys_int_machine_t;           {1-N input file line number}
    cont_p: string_var_p_t;            {points to content string from input line}
    comm_p: string_var_p_t;            {points to comment string, NIL for none}
    comcol: sys_int_machine_t;         {1-N comment start column number, 0 for none}
    end;

  parse_k_t = (                        {parsing state}
    parse_norm_k,                      {normal, not within special syntax}
    parse_quote_k);                    {in quoted string}

  etk_k_t = (                          {end of token delimiter}
    etk_eol_k,                         {end of line}
    etk_space_k,                       {space}
    etk_comma_k);                      {comma}

  tktype_k_t = (                       {token type}
    tktype_first_k,                    {first token on a line}
    tktype_label_k,                    {label}
    tktype_opc_k,                      {opcode}
    tktype_oper_k,                     {operand}
    tktype_dir1_k,                     {assembler directive for column 1}
    tktype_dirn_k,                     {assembler directive, write nested}
    tktype_diro_k,                     {assembler directive, write as opcode}
    tktype_prep_k);                    {preprocessor directive}

  dirtype_k_t = (                      {assembler directive types}
    dirtype_none_k,                    {not an assembler directive}
    dirtype_col1_k,                    {should start in column 1}
    dirtype_col1np_k,                  {start in column 1, no following padding}
    dirtype_inest_k,                   {increases nesting level}
    dirtype_nest_k,                    {indented according to nesting level}
    dirtype_unest_k,                   {decreases nesting level}
    dirtype_opc_k);                    {written as if it were an opcode}

  asmdir_p_t = ^asmdir_t;
  asmdir_t = record                    {info about one assembler directive}
    next_p: asmdir_p_t;                {pointer to next directive in list}
    name_p: string_var_p_t;            {pointer to name string, upper case}
    ty: dirtype_k_t;                   {type of this directive}
    end;

  precmd_handler_p_t = ^procedure (    {custom handler for a preprocessor command}
    in    pcmd_p: precmd_p_t);         {pointer to the command to handle}
    val_param;

  precmd_t = record                    {info about one preprocessor command}
    next_p: precmd_p_t;                {pointer to next command in the list}
    name_p: string_var_p_t;            {pointer to name string, upper case without "/"}
    handler_p: precmd_handler_p_t;     {pointer to handler routine, NIL for defaults}
    end;

  blkty_k_t = (                        {ID of preprocessor nested commands block type}
    blkty_if_k,                        {IF command}
    blkty_subr_k,                      {subroutine}
    blkty_macro_k,                     {macro}
    blkty_block_k);                    {block started with BLOCK command}

  precmd_block_p_t = ^precmd_block_t;
  precmd_block_t = record              {info for one nested preprocessor commands block}
    prev_p: precmd_block_p_t;          {pointer to parent block, NIL = at top}
    indl: sys_int_machine_t;           {parent indentation level}
    blkty: blkty_k_t;                  {type of this block}
    case blkty_k_t of                  {unique state for each block type}
blkty_if_k: (                          {IF command}
      thenl: boolean;                  {THEN keyword in IF command}
      );
blkty_subr_k: (                        {subroutine}
      );
blkty_macro_k: (                       {macro}
      );
blkty_block_k: (                       {BLOCK command}
      );
    end;

var
  fnam_in, fnam_out:                   {input and output file names}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  iname_set: boolean;                  {TRUE if the input file name already set}
  oname_set: boolean;                  {TRUE if the output file name already set}
  asmdir_p: asmdir_p_t;                {points to list of assembler directives}
  col_opc: sys_int_machine_t;          {start column for opcode}
  col_oper: sys_int_machine_t;         {start column for operands}
  col_com: sys_int_machine_t;          {start column for comment}
  dirnest: sys_int_machine_t;          {assembler directive nesting level}
  nestinc: sys_int_machine_t;          {asm directive nest increment after proc}
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  col: sys_int_machine_t;              {start column of current token}
  first_p: line_p_t;                   {pointer to first input line in list}
  last_p: line_p_t;                    {pointer to last input line in list}
  line_p: line_p_t;                    {pointer to current input file line info}
  conn: file_conn_t;                   {connection to input or output file}
  mem_p: util_mem_context_p_t;         {pointer to private memory context}
  precmd_p: precmd_p_t;                {points to list of preprocessor commands}
  preind: sys_int_machine_t;           {preprocessor commands indentation level}
  preindinc: sys_int_machine_t;        {PREIND increment at end of current token}
  pblock_p: precmd_block_p_t;          {pointer to innermost preprocessor command block}
  p: string_index_t;                   {string parse index}
  qchar: char;                         {end quoted string character}
  parse: parse_k_t;                    {current parsing state}
  c: char;                             {current parsed character}
  etk: etk_k_t;                        {end of token delimiter ID}
  tktype: tktype_k_t;                  {token type ID}
  nblank: sys_int_machine_t;           {number of unwritten blank output lines}
  nopad: boolean;                      {do not insert following padding}
  forum: boolean;                      {for posting on Microchip forum with CODE tags}
  oline1: boolean;                     {current output line is line 1}
  popcmd: boolean;                     {pop the current preproc command block after this cmd}
  pcmd: boolean;                       {curr line is a preprocessor command}
  buf:                                 {one line in/out buffer}
    %include '/cognivision_links/dsee_libs/string/string8192.ins.pas';
  eolcomm:                             {end of line comment start sequence}
    %include '/cognivision_links/dsee_libs/string/string4.ins.pas';
  asmnest0col: sys_int_machine_t;      {column for 0 nested ASM directive}

  opt:                                 {upcased command line option}
    %include '/cognivision_links/dsee_libs/string/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '/cognivision_links/dsee_libs/string/string8192.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts,
  loop_iline, found_comm, eof_in, loop_newoline, loop_otk,
  done_tktype, done_otk, done_ocomm, done_obuf, done_out;
{
********************************************************************************
*
*   Subroutine ASMDIR (NAME, TY)
*
*   Add a new directive to the list of assembler directives.  This list will
*   be used later to identify directives in the source code.  NAME is the
*   directive name, and TY is its type.
}
procedure asmdir (                     {add new assembler directive to list}
  in      name: string;                {directive name}
  in      ty: dirtype_k_t);            {type of assembler directive}
  val_param; internal;

var
  tk: string_var80_t;                  {var string directive name}
  dir_p: asmdir_p_t;                   {pointer to this new list entry}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_vstring (tk, name, size_char(name)); {make var string directive name}
  string_upcase (tk);                  {make upper case for keyword matching later}

  util_mem_grab (                      {allocate memory for this directive info}
    sizeof(dir_p^), mem_p^, false, dir_p);

  dir_p^.next_p := asmdir_p;           {link new entry to start of chain}
  asmdir_p := dir_p;
  dir_p^.ty := ty;                     {save directive type ID}
  string_alloc (tk.len, mem_p^, false, dir_p^.name_p); {allocate memory for name}
  string_copy (tk, dir_p^.name_p^);    {save the directive name}
  end;
{
********************************************************************************
*
*   Subroutine PRECMD (NAME, HANDLER)
*
*   Add a new entry to the list of preprocessor commands.  NAME is the command
*   name without the leading "/", and HANDLER is a pointer to the handler
*   subroutine for this command.  HANDLER may be NIL when no special handling
*   is required.
}
procedure precmd (                     {add preprocessor command to list}
  in      name: string;                {proprocessor command name}
  in      handler: precmd_handler_p_t); {handler subroutine, may be NIL}
  val_param; internal;

var
  tk: string_var80_t;                  {var string command name}
  cmd_p: precmd_p_t;                   {pointer to new list entry}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_vstring (tk, name, size_char(name)); {make var string directive name}
  string_upcase (tk);                  {make upper case for keyword matching later}

  util_mem_grab (                      {allocate memory for the new list entry}
    sizeof(cmd_p^), mem_p^, false, cmd_p);

  cmd_p^.next_p := precmd_p;           {link new entry to start of chain}
  precmd_p := cmd_p;
  string_alloc (tk.len, mem_p^, false, cmd_p^.name_p); {allocate memory for name}
  string_copy (tk, cmd_p^.name_p^);    {save the directive name}
  cmd_p^.handler_p := handler;         {save pointer to handler for this command}
  end;
{
********************************************************************************
*
*   Function DIRECTIVE_TYPE (NAME)
*
*   Returns the type of assembler directive that NAME is.  Returns
*   DIRTYPE_NONE_K if NAME is not an assembler directive.
}
function directive_type (              {get type of assembler directive}
  in      name: univ string_var_arg_t) {directive name}
  :dirtype_k_t;                        {returned directive type}
  val_param; internal;

var
  un: string_var80_t;                  {upper case directive name}
  dir_p: asmdir_p_t;                   {pointer to curr asm directive info}

begin
  un.max := size_char(un.str);         {init local var string}

  string_copy (name, un);              {make local upper case copy of directive name}
  string_upcase (un);

  dir_p := asmdir_p;                   {init to first directive in list}
  while dir_p <> nil do begin          {loop thru the list of direcitives}
    if string_equal(dir_p^.name_p^, un) then begin {found entry for this directive ?}
      directive_type := dir_p^.ty;     {return type of this directive}
      return;
      end;
    dir_p := dir_p^.next_p;            {advance to next directive in list}
    end;                               {back to process this new directive}

  directive_type := dirtype_none_k;    {indicate NAME is not an asm directive}
  end;
{
********************************************************************************
*
*   Subroutine TOKEN (COL, TK, ETK)
*
*   Extract the next token from the content string of the current
*   input line.  LINE_P must be pointing to the input line, and P
*   is the parse index into the content string.  COL is returned the
*   1-N column number of the start of the token.  COL is returned
*   0 to indicate the input string has been exhausted.  The token
*   string itself is returned in TK.
*
*   ETK indicates the reason the token ended.  It will be set to one
*   of the following:
*
*     ETK_EOL_K  -  The end of line ended the token.  ETK will also
*       be set to this value when the end of line is encountered
*       before any token.
*
*     ETK_SPACE_K  -  One or more spaces, but no comma.
*
*     ETK_COMMA_K  -  A comma, which may be surrounded by 0 or more
*       spaces on either side.
}
procedure token (                      {get next content token from current line}
  out     col: sys_int_machine_t;      {1-N token start column, 0 = end of line}
  in out  tk: univ string_var_arg_t;   {the returned token}
  out     etk: etk_k_t);               {end of token delimiter ID}
  val_param; internal;

type
  parse_k_t = (                        {parsing state}
    parse_bef_k,                       {before start of token}
    parse_tk_k,                        {within token}
    parse_qt_k,                        {in quoted string within token}
    parse_aft_k);                      {in blanks after token}

var
  parse: parse_k_t;                    {current parsing state}
  c: char;                             {current input string character}
  q: char;                             {end of quote character}

label
  reparse, done_char, comma;

begin
  col := 0;                            {init to end of line encountered before token}
  tk.len := 0;                         {init the returned token to empty}
  etk := etk_eol_k;                    {init end of token delimiter ID}
  parse := parse_bef_k;                {init the parsing state}

  while p <= line_p^.cont_p^.len do begin {loop up to end of input string}
    c := line_p^.cont_p^.str[p];       {get this input string character}
reparse:                               {jump here to reparse with new parsing state}
    case parse of                      {what is the parsing state ?}

parse_bef_k: begin                     {in blanks before start of token}
  if c = ',' then goto comma;          {token definitely ends here ?}
  if c <> ' ' then begin               {found start of token ?}
    parse := parse_tk_k;               {indicate now within the token}
    col := p;                          {return the token start column}
    goto reparse;                      {check this char again with new parsing state}
    end;
  end;

parse_tk_k: begin                      {not within any special syntax}
  if c = ',' then goto comma;          {token definitely ends here ?}
  if c = ' ' then begin                {this space ends the token body ?}
    parse := parse_aft_k;              {indicate now after the token}
    etk := etk_space_k;                {indicate a space ended the token}
    goto done_char;                    {done with this input character}
    end;
  string_append1 (tk, c);              {add this char to end of returned token}
  if (c = '''') or (c = '"') then begin {start of quoted string ?}
    parse := parse_qt_k;               {indicate now within quoted string}
    q := c;                            {set end of quote character}
    end;
  if c = '[' then begin                {start of inline function ?}
    parse := parse_qt_k;               {handle just like quoted string}
    q := ']';                          {set end of quote character}
    end;
  end;

parse_qt_k: begin                      {within a quoted string}
  string_append1 (tk, c);              {add this char to end of returned token}
  if c = q then begin                  {this char ends the quoted string ?}
    parse := parse_tk_k;               {back to normal token parsing mode}
    end;
  end;

parse_aft_k: begin                     {in blanks after the token}
  if c = ',' then goto comma;          {token definitely ends here ?}
  if c <> ' ' then return;             {this char is start of next token ?}
  end;
      end;                             {end of parse state cases}

done_char:                             {done with this char, on to next}
    p := p + 1;                        {advance parse index to next char}
    end;                               {back to process char at new parse index}

  return;                              {return with curr state at end of string}

comma:                                 {curr char is comma ending the token}
  if col = 0 then col := p;            {set column in case of empty token}
  etk := etk_comma_k;                  {indicate a comma ended the token}
  p := p + 1;                          {start parsing after the comma next time}
  end;
{
********************************************************************************
*
*   Subroutine APPEND (S, COL)
*
*   Append the string S to the output buffer BUF.  COL is the desired
*   starting column for S in BUF.  However, a blank is appended to BUF
*   if BUF is non-empty and does not already end in a blank.  S may
*   therefore start in BUF after COL, but never before COL.
}
procedure append (                     {append separate string to BUF}
  in      s: univ string_var_arg_t;    {the string to append}
  in      col: sys_int_machine_t);     {desired starting column of S}
  val_param; internal;

var
  lcol: sys_int_machine_t;             {actual desired starting column number}

begin
  lcol := col;                         {init to starting column as passed in}
{
*   Adjust the desired column number to correct for file corruption caused by
*   the Microchip forum editor when CODE tags are used.
}
  if                                   {need to adjust desired column for forum post ?}
      forum and                        {formatting for forum post ?}
      (not oline1) and                 {not first output line ?}
      ( ((buf.len > 0) and (buf.str[1] = ' ')) or {line already starts with a blank ?}
        ((buf.len = 0) and (lcol > 1)) {will start with a blank now ?}
        )
      then begin
    lcol := lcol + 1;                  {add extra blank at start of line}
    end;

  if (buf.len > 0) and then (buf.str[buf.len] <> ' ') then begin {need blank ?}
    string_append1 (buf, ' ');         {add blank separator before string}
    end;

  while buf.len < (lcol - 1) do begin  {add blanks to get to desired start column}
    string_append1 (buf, ' ');         {add one more blank to end of BUF}
    end;

  string_append (buf, s);              {append the new string to the end of BUF}
  end;
{
********************************************************************************
*
*   Subroutine OTOKEN (TK, TY)
*
*   Append the token in TK to the output buffer BUF according to the type
*   of token as indicated by TY.
}
procedure otoken (                     {append token to output buffer}
  in      tk: univ string_var_arg_t;   {the token to append}
  in      ty: tktype_k_t);             {the type of token}
  val_param; internal;

var
  col: sys_int_machine_t;              {column of next output token}

begin
  col := 1;                            {init to write to next available column}

  case ty of                           {what type of token is this ?}
tktype_opc_k: begin                    {token is an opcode}
      if not nopad then col := col_opc;
      end;
tktype_oper_k: begin                   {token is an operand}
      if not nopad then col := col_oper;
      end;
tktype_dirn_k: begin                   {directive to write by nesting level}
      col := asmnest0col + (dirnest * 2); {according to ASM directives nesting level}
      end;
tktype_diro_k: begin                   {directive to write as opcode}
      if not nopad then col := col_opc;
      end;
tktype_prep_k: begin                   {preprocessor command}
      col := 1 + 2 * preind;           {indent according to preproc cmd nesting level}
      end;
    end;                               {end of token type cases}

  append (tk, col);                    {append to BUF, indicate desired start column}
  end;
{
********************************************************************************
*
*   Subroutine OCOMMENT (COL, DELB)
*
*   Add the comment from the current input line to the output buffer.
*   COL is the desired start column for the comment.  DELB TRUE causes
*   leading blanks from the comment text to be deleted, otherwise the
*   comment text is preserved from the input line.
}
procedure ocomment (                   {write comment to output buffer}
  in      col: sys_int_machine_t;      {desired comment start column}
  in      delb: boolean);              {delete leading blanks from comment}
  val_param; internal;

var
  p: string_index_t;                   {index into comment string from input line}

begin
  if line_p^.comm_p = nil then return; {no comment exists here ?}

  p := 1;                              {init comment string parse index}
  if delb then begin                   {delete leading blanks from comment ?}
    while                              {advance P over the leading blanks}
        (p <= line_p^.comm_p^.len) and then
        (line_p^.comm_p^.str[p] = ' ')
      do p := p + 1;
    end;                               {end of delete leading blanks case}
  if p > line_p^.comm_p^.len then return; {no comment left to write ?}

  append (eolcomm, col);               {write comment start sequence to BUF}
  while p <= line_p^.comm_p^.len do begin {scan remainder of comment string}
    string_append1 (buf, line_p^.comm_p^.str[p]); {add this comment char to BUF}
    p := p + 1;                        {advance to next comment char}
    end;                               {back to process this new comment char}
  end;
{
********************************************************************************
*
*   Subroutine PBLOCK_PUSH
*
*   Create a new preprocessor command nesting block and add it to the end of the
*   current list.  The block will be created and all the common fields except
*   the block type will be filled in.
}
procedure pblock_push;                 {push down one processor block nesting level}

var
  pblk_p: precmd_block_p_t;            {pointer to the new block}

begin
  sys_mem_alloc (sizeof(pblk_p^), pblk_p); {allocate memory for the new block}
  pblk_p^.prev_p := pblock_p;          {point back to parent block}
  pblk_p^.indl := preind;              {save parent indentation level}
  pblock_p := pblk_p;                  {make the new block current}

  preindinc := preindinc + 1;          {default to indent after this token}
  end;
{
********************************************************************************
*
*   Subroutine PBLOCK_POP
*
*   Pop back out of the current preprocessor execution block.  The state will be
*   restored to that of the previous execution block, and the current execution
*   block will be deallocated.
}
procedure pblock_pop;                  {pop up one preprocessor execution block}

var
  pblk_p: precmd_block_p_t;            {pointer to the block to remove}

begin
  pblk_p := pblock_p;                  {save pointer to the block to remover}
  if pblk_p = nil then return;
  pblock_p := pblk_p^.prev_p;          {restore to previous execution block}

  preindinc := pblk_p^.indl - preind;  {back to old indentation after this token}
  sys_mem_dealloc (pblk_p);            {deallocate memory of the popped block}
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD (CMD)
*
*   Set up the state for the preprocessor command indicated by the string CMD.
*   CMD is the first token parsed from the current line, and starts with "/".
}
procedure handle_pcmd (                {set up state for writing preprocessor command}
  in      cmd: univ string_var_arg_t); {command name token, first char is "/"}
  val_param; internal;

var
  name: string_var32_t;                {preprocessor command name, upper case, no "/"}
  cmd_p: precmd_p_t;                   {pointer to preprocessor commands list entry}

begin
  name.max := size_char(name.str);     {init local var string}

  string_substr (cmd, 2, cmd.len, name); {extract just the command name without "/"}
  string_upcase (name);
{
*   Set state to default for "normal" commands.
}
  nopad := true;                       {do not tab parameters to specific columns}
  pcmd := true;                        {processing a preprocessor command}
{
*   Find the list entry for this command and leave CMD_P pointing to it.
}
  cmd_p := precmd_p;                   {point to first command in list}
  while true do begin                  {back here each new list entry to scan}
    if cmd_p = nil then return;        {this command is not in list ?}
    if string_equal (cmd_p^.name_p^, name) then exit; {found list entry for this command ?}
    cmd_p := cmd_p^.next_p;            {advance to next list entry}
    end;                               {back to check this new list entry}

  if cmd_p^.handler_p <> nil then cmd_p^.handler_p^ (cmd_p); {run custom handler, if any}
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_TABBED (CMD_P)
*
*   Special handler for preprocessor commands that need to have their parameters
*   aligned in the assembler opcode and parameter columns.
}
procedure handle_pcmd_tabbed (         {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  nopad := (preind <> 0);              {tag to ASM columns if not in nested block}
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_BLOCK (CMD_P)
*
*   Special handler for the BLOCK preprocessor command.
}
procedure handle_pcmd_block (          {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  pblock_push;                         {create new nested block context}
  pblock_p^.blkty := blkty_block_k;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_SUBROUTINE (CMD_P)
*
*   Special handler for the BLOCK preprocessor command.
}
procedure handle_pcmd_subroutine (     {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  pblock_push;                         {create new nested block context}
  pblock_p^.blkty := blkty_subr_k;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_IF (CMD_P)
*
*   Special handler for the IF preprocessor command.
}
procedure handle_pcmd_if (             {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  pblock_push;                         {create new nested block context}
  pblock_p^.blkty := blkty_if_k;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_THEN (CMD_P)
*
*   Special handler for the THEN and ELSE preprocessor commands.
}
procedure handle_pcmd_then (           {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  if (pblock_p = nil) or else (pblock_p^.blkty <> blkty_if_k) then return;

  preind := pblock_p^.indl + 1;
  preindinc := 1;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_ENDBLOCK (CMD_P)
*
*   Special handler for the ENDBLOCK preprocessor command.
}
procedure handle_pcmd_endblock (       {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  if (pblock_p <> nil) and then (pblock_p^.blkty = blkty_block_k) then begin
    pblock_pop;
    end;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_ENDSUB (CMD_P)
*
*   Special handler for the ENDSUB preprocessor command.
}
procedure handle_pcmd_endsub (         {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  if (pblock_p <> nil) and then (pblock_p^.blkty = blkty_subr_k) then begin
    pblock_pop;
    end;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_ENDIF (CMD_P)
*
*   Special handler for the ENDIF preprocessor command.
}
procedure handle_pcmd_endif (          {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  if (pblock_p <> nil) and then (pblock_p^.blkty = blkty_if_k) then begin
    preind := pblock_p^.indl + 1;
    pblock_pop;
    end;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_MACRO (CMD_P)
*
*   Special handler for the MACRO preprocessor command.
}
procedure handle_pcmd_macro (          {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  pblock_push;                         {create new nested macro context}
  pblock_p^.blkty := blkty_macro_k;
  end;
{
********************************************************************************
*
*   Subroutine HANDLE_PCMD_ENDMAC (CMD_P)
*
*   Special handler for the ENDMAC preprocessor command.
}
procedure handle_pcmd_endmac (         {custom preprocessor command handler}
  in      cmd_p: precmd_p_t);          {pointer to commands list entry}
  val_param; internal;

begin
  if (pblock_p <> nil) and then (pblock_p^.blkty = blkty_macro_k) then begin
    pblock_pop;
    end;
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  util_mem_context_get (util_top_mem_context, mem_p); {create private memory context}

  asmdir_p := nil;                     {init list of assembler directives to empty}
  {
  *   MPASM directives.
  }
  asmdir ('__BADRAM',  dirtype_opc_k);
  asmdir ('BANKISEL',  dirtype_opc_k);
  asmdir ('BANKSEL',   dirtype_opc_k);
  asmdir ('CBLOCK',    dirtype_inest_k);
  asmdir ('CODE',      dirtype_opc_k);
  asmdir ('__CONFIG',  dirtype_opc_k);
  asmdir ('CONSTANT',  dirtype_col1_k);
  asmdir ('DA',        dirtype_opc_k);
  asmdir ('DATA',      dirtype_opc_k);
  asmdir ('DB',        dirtype_opc_k);
  asmdir ('DE',        dirtype_opc_k);
  asmdir ('#DEFINE',   dirtype_col1np_k);
  asmdir ('DT',        dirtype_opc_k);
  asmdir ('DW',        dirtype_opc_k);
  asmdir ('ELSE',      dirtype_nest_k);
  asmdir ('END',       dirtype_opc_k);
  asmdir ('ENDC',      dirtype_unest_k);
  asmdir ('ENDIF',     dirtype_unest_k);
  asmdir ('#ENDIF',    dirtype_unest_k);
  asmdir ('ENDM',      dirtype_opc_k);
  asmdir ('ENDW',      dirtype_unest_k);
  asmdir ('EQU',       dirtype_opc_k);
  asmdir ('ERROR',     dirtype_opc_k);
  asmdir ('ERRORLEVEL', dirtype_opc_k);
  asmdir ('EXITM',     dirtype_opc_k);
  asmdir ('EXPAND',    dirtype_opc_k);
  asmdir ('EXTERN',    dirtype_opc_k);
  asmdir ('FILL',      dirtype_opc_k);
  asmdir ('GLOBAL',    dirtype_opc_k);
  asmdir ('IDATA',     dirtype_opc_k);
  asmdir ('__IDLOCS',  dirtype_opc_k);
  asmdir ('IF',        dirtype_inest_k);
  asmdir ('#IF',       dirtype_inest_k);
  asmdir ('IFDEF',     dirtype_inest_k);
  asmdir ('#IFDEF',    dirtype_inest_k);
  asmdir ('IFNDEF',    dirtype_inest_k);
  asmdir ('#IFNDEF',   dirtype_inest_k);
  asmdir ('#INCLUDE',  dirtype_opc_k);
  asmdir ('LIST',      dirtype_opc_k);
  asmdir ('LOCAL',     dirtype_opc_k);
  asmdir ('MACRO',     dirtype_opc_k);
  asmdir ('__MAXRAM',  dirtype_opc_k);
  asmdir ('MESSG',     dirtype_opc_k);
  asmdir ('NOEXPAND',  dirtype_opc_k);
  asmdir ('NOLIST',    dirtype_opc_k);
  asmdir ('ORG',       dirtype_opc_k);
  asmdir ('PAGE',      dirtype_opc_k);
  asmdir ('PAGESEL',   dirtype_opc_k);
  asmdir ('PROCESSOR', dirtype_opc_k);
  asmdir ('RADIX',     dirtype_opc_k);
  asmdir ('RES',       dirtype_opc_k);
  asmdir ('SET',       dirtype_opc_k);
  asmdir ('SPACE',     dirtype_opc_k);
  asmdir ('SUBTITLE',  dirtype_opc_k);
  asmdir ('TITLE',     dirtype_opc_k);
  asmdir ('UDATA',     dirtype_opc_k);
  asmdir ('UDATA_ACS', dirtype_opc_k);
  asmdir ('UDATA_OVR', dirtype_opc_k);
  asmdir ('UDATA_SHR', dirtype_opc_k);
  asmdir ('#UNDEFINE', dirtype_col1np_k);
  asmdir ('VARIABLE',  dirtype_opc_k);
  asmdir ('WHILE',     dirtype_inest_k);
  {
  *   ASM30 directives.
  }
  asmdir ('.ELSE',     dirtype_nest_k);
  asmdir ('.ENDIF',    dirtype_unest_k);
  asmdir ('.ENDM',     dirtype_unest_k);
  asmdir ('.IF',       dirtype_inest_k);
  asmdir ('.IFDEF',    dirtype_inest_k);
  asmdir ('.MACRO',    dirtype_inest_k);

  precmd_p := nil;                     {init list of preprocessor commands to empty}
  precmd ('BLOCK',      addr(handle_pcmd_block));
  precmd ('CALL',       nil);
  precmd ('CONST',      addr(handle_pcmd_tabbed));
  precmd ('DEL',        nil);
  precmd ('ELSE',       addr(handle_pcmd_then));
  precmd ('ENDBLOCK',   addr(handle_pcmd_endblock));
  precmd ('ENDIF',      addr(handle_pcmd_endif));
  precmd ('ENDLOOP',    addr(handle_pcmd_endblock));
  precmd ('ENDMAC',     addr(handle_pcmd_endmac));
  precmd ('ENDSUB',     addr(handle_pcmd_endsub));
  precmd ('FLAG',       addr(handle_pcmd_tabbed));
  precmd ('IF',         addr(handle_pcmd_if));
  precmd ('INANA',      addr(handle_pcmd_tabbed));
  precmd ('INBIT',      addr(handle_pcmd_tabbed));
  precmd ('INCLUDE',    nil);
  precmd ('LOOP',       addr(handle_pcmd_block));
  precmd ('MACRO',      addr(handle_pcmd_macro));
  precmd ('OUTBIT',     addr(handle_pcmd_tabbed));
  precmd ('QUIT',       nil);
  precmd ('QUITMAC',    nil);
  precmd ('REPEAT',     nil);
  precmd ('RETURN',     nil);
  precmd ('SET',        nil);
  precmd ('SHOW',       nil);
  precmd ('STOP',       nil);
  precmd ('SUBROUTINE', addr(handle_pcmd_subroutine));
  precmd ('SYLIST',     nil);
  precmd ('THEN',       addr(handle_pcmd_then));
  precmd ('VAR',        nil);
  precmd ('WRITE',      nil);
  precmd ('WRITEPUSH',  nil);
  precmd ('WRITEPOP',   nil);

  string_vstring (eolcomm, ';', 1);    {set end of line comment start sequence}

  string_cmline_init;                  {init for reading the command line}
{
*   Initialize our state before reading the command line options.
}
  iname_set := false;                  {no input file name specified}
  oname_set := false;                  {no output file name specified}
  col_opc := def_col_opc_k;            {init column for opcodes}
  col_oper := def_col_oper_k;          {init column for operands}
  col_com := def_col_com_k;            {init column for comments}
  forum := false;                      {init to not format for Microchip forum post}
  asmnest0col := 3;                    {init for MPASM, nesting 0 starts in column 3}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if not iname_set then begin        {input file name not set yet ?}
      string_copy (opt, fnam_in);      {set input file name}
      iname_set := true;               {input file name is now set}
      goto next_opt;
      end;
    if not oname_set then begin        {output file name not set yet ?}
      string_copy (opt, fnam_out);     {set output file name}
      oname_set := true;               {output file name is now set}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-IN -OUT -FORUM',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -IN filename
}
1: begin
  if iname_set then begin              {input file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (fnam_in, stat);
  iname_set := true;
  end;
{
*   -OUT filename
}
2: begin
  if oname_set then begin              {output file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (fnam_out, stat);
  oname_set := true;
  end;
{
*   -FORUM
}
3: begin
  forum := true;
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

done_opts:                             {done reading the command line options}
  if not iname_set then begin          {no input file name specified ?}
    sys_message_bomb ('img', 'input_fnam_missing', nil, 0);
    end;
{
********************
*
*   Read the input file into memory.
}
  string_fnam_unextend (fnam_in, '.dspic', parm); {look for ".dspic" suffix}
  if parm.len <> fnam_in.len then begin {processing ASM30 source ?}
    asmnest0col := 1;                  {0-nested directives go in column 1}
    end;

  file_open_read_text (                {open the input file for reading}
    fnam_in, '',                       {input file name}
    conn,                              {returned connection to the file}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  if not oname_set then begin          {no output file name explicitly set ?}
    string_copy (conn.tnam, fnam_out); {write output back to the input file}
    end;

  first_p := nil;                      {init list of input lines to empty}
  last_p := nil;

loop_iline:                            {back here each new input line}
  file_read_text (conn, buf, stat);    {read new input file line into BUF}
  if file_eof(stat) then goto eof_in;  {hit end of input file ?}
  sys_error_abort (stat, '', '', nil, 0);
  string_unpad (buf);                  {delete trailing blanks from input line}
  for p := 1 to buf.len do begin       {replace all control characters with spaces}
    if ord(buf.str[p]) < 32 then buf.str[p] := ' ';
    end;
  string_unpad (buf);                  {delete all resulting trailing spaces}
  if (last_p = nil) and (buf.len = 0)  {ignore blank lines at start of file}
    then goto loop_iline;
{
*   Create and initialize a new descriptor for this input file line, and
*   link the new descriptor to the end of the list.
}
  util_mem_grab (                      {allocate memory for new input line info}
    sizeof(line_p^), mem_p^, false, line_p);
  if last_p = nil
    then begin                         {this is first line in list}
      first_p := line_p;               {set start of list pointer}
      end
    else begin                         {new entry goes at end of existing list}
      last_p^.next_p := line_p;        {link forwards from previous list entry}
      end
    ;
  last_p := line_p;                    {update pointer to last list entry}
  line_p^.next_p := nil;               {init new input line descriptor}
  line_p^.lnum := conn.lnum;
  line_p^.cont_p := nil;
  line_p^.comm_p := nil;
  line_p^.comcol := 0;
{
*   Check for this is a preprocessor comment.  These have "//" as the first
*   non-blank characters.  If so, the line can not contain a assembler end of
*   line comment.
}
  p := 1;                              {init parse index}
  while p <= buf.len do begin          {skip over leading blanks}
    if buf.str[p] <> ' ' then exit;    {found first non-blank ?}
    p := p + 1;
    end;

  if                                   {check for line starts with "//"}
      (p < buf.len) and                {at least 2 chars left on line ?}
      (buf.str[p] = '/') and (buf.str[p+1] = '/') {first non-blanks are comment start ?}
      then begin
    p := buf.len + 1;                  {indicate no end of line comment}
    goto found_comm;
    end;
{
*   Find the start of the end of line comment, if any.  P is the index of the
*   first non-blank character on the line.
}
  parse := parse_norm_k;               {init parsing state}

  while p <= buf.len do begin          {scan from start to end of line}
    c := buf.str[p];                   {get this input string character}
    case parse of                      {what is the current parsing state}

parse_norm_k: begin                    {normal parsing state}
        if c = ';' then goto found_comm; {found comment start ?}
        if (c = '''') or (c = '"') then begin {start of quoted string ?}
          parse := parse_quote_k;      {indicate now in quoted string}
          qchar := c;                  {set end of quoted string character}
          end;
        end;

parse_quote_k: begin                   {currently in a quoted string}
        if c = qchar then begin        {found end of quoted string ?}
          parse := parse_norm_k;       {back to normal parsing state}
          end;
        end;
      end;                             {end of parse state cases}

    p := p + 1;                        {advance to next input string character}
    end;                               {back to check out next input string char}
found_comm:                            {jump here if P is index of comment start}
{
*   P is the BUF index of the start of comment, or it is past the end of
*   BUF if the line contains no comment.
}
  {
  *   Check for old style horizontal divider line and convert to new.  Old
  *   horizontal dividers were comments that started in column 1 and contained
  *   all stars to column 72.  The new style is the same thing to column 80.
  }
  if (p = 1) and (buf.len >= 72) then begin {right start and length of comment ?}
    ii := 2;
    while ii <= buf.len do begin       {scan the whole comment body}
      if buf.str[ii] <> '*' then exit; {not a divider comment ?}
      ii := ii + 1;
      end;
    if ii > buf.len then begin         {is a divider comment ?}
      while buf.len < 80 do begin      {extend divider out to column 80}
        string_append1 (buf, '*');
        end;
      buf.len := min(buf.len, 80);     {truncate at column 80}
      end;
    end;

  if p <= (buf.len - 1) then begin     {this line has a comment ?}
    line_p^.comcol := p;               {save column of comment start}
    string_substr (buf, p+1, buf.len, parm); {extract just the comment text}
    string_alloc (parm.len, mem_p^, false, line_p^.comm_p); {alloc mem for comment}
    string_copy (parm, line_p^.comm_p^); {save comment string for this line}
    buf.len := p - 1;                  {truncate input line buffer before comment}
    string_unpad (buf);                {delete any spaces before the comment}
    end;

  string_alloc (buf.len, mem_p^, false, line_p^.cont_p); {alloc mem for line content}
  string_copy (buf, line_p^.cont_p^);  {save line content for this line}
  goto loop_iline;                     {back to get and process next input file line}

eof_in:                                {end of input file encountered}
  file_close (conn);                   {close connection to the input file}
{
*   The input file has been read and all its information is in the list
*   starting at FIRST_P^.
*
********************
*
*   Process the list of input file lines and write the output file.
}
  file_open_write_text (               {open the output file}
    fnam_out, '',                      {file name}
    conn,                              {returned connection to output file}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  line_p := first_p;                   {init pointer to first input line}
  buf.len := 0;                        {init output line}
  dirnest := 0;                        {init assembler directives nesting level}
  oline1 := true;                      {init to processing first output line}
  nblank := 0;                         {init to no unwritten blank output lines}
  pblock_p := nil;                     {init to not within a preprocessor command block}

loop_newoline:                         {back here each new out line}
  tktype := tktype_first_k;            {init expected type of next token}
  nopad := false;                      {init to allow padding between tokens}
  popcmd := false;                     {don't pop preproc command block after this command}
  if line_p = nil then goto done_out;  {hit end of stored input lines ?}
  p := 1;                              {init input line content parse index}

loop_otk:                              {back here each new token}
  nestinc := 0;                        {init to no change in ASM nest level after token}
  preindinc := 0;                      {init to no change in preproc indent level after token}
  token (col, parm, etk);              {get next input token}
  if col <= 0 then goto done_otk;      {done with all tokens on this line}
  case tktype of                       {what kind of token was expected ?}

tktype_first_k: begin                  {this is the first token on the line ?}
      if parm.str[1] = '/' then begin  {this line contains preprocessor directive ?}
        if (parm.len >= 2) and (parm.str[2] = '/') then begin {preprocessor comment ?}
          string_copy (line_p^.cont_p^, buf); {copy line intact to output buffer}
          goto done_obuf;              {output buffer all set for this line}
          end;
        tktype := tktype_prep_k;
        handle_pcmd (parm);            {perform special handling for this command}
        goto done_tktype;              {all set up for this token type}
        end;
      case directive_type (parm) of    {check for this is an assembler directive}
dirtype_col1_k: begin                  {directive to write in column 1}
          tktype := tktype_dir1_k;
          goto done_tktype;
          end;
dirtype_col1np_k: begin                {write in column 1, no following padding}
          tktype := tktype_dir1_k;
          nopad := true;
          goto done_tktype;
          end;
dirtype_inest_k: begin                 {directive increases nesting level}
          tktype := tktype_dirn_k;
          nestinc := 1;
          goto done_tktype;
          end;
dirtype_nest_k: begin                  {write according to nesting level}
          tktype := tktype_dirn_k;
          goto done_tktype;
          end;
dirtype_unest_k: begin                 {directive decreases nesting level}
          tktype := tktype_dirn_k;
          nestinc := -1;
          goto done_tktype;
          end;
dirtype_opc_k: begin                   {write as an opcode}
          tktype := tktype_diro_k;
          goto done_tktype;
          end;
        end;                           {end of assembler directive type cases}
      if col = 1
        then tktype := tktype_label_k  {in column 1, is a label}
        else tktype := tktype_opc_k;   {after column 1, is an opcode}
      end;

tktype_label_k: begin                  {previous token was a label}
      tktype := tktype_opc_k;          {write next as opcode}
      end;

tktype_opc_k: begin                    {previous token was an opcode}
      tktype := tktype_oper_k;         {write next as operand}
      end;

tktype_oper_k: ;                       {previous was operand, so this is too}

tktype_dir1_k: begin                   {previous was directive in column 1}
      if not nopad then begin          {padding between tokens allowed ?}
        tktype := tktype_opc_k;        {write next as opcode}
        end;
      end;

tktype_dirn_k: ;                       {previous indented by nest level}

tktype_diro_k: begin                   {previous was directive in opcode position}
      tktype := tktype_oper_k;         {write next as operand}
      end;

tktype_prep_k: begin                   {previous was preprocessor directive}
      tktype := tktype_opc_k;          {write next as opcode}
      end;
    end;                               {end of previous token type cases}
done_tktype:                           {TKTYPE is all set for this token}

  otoken (parm, tktype);               {write this token to the output buffer}
  if etk = etk_comma_k then begin      {token end delimiter was comma ?}
    string_append1 (buf, ',');         {write the comma to the output buffer}
    end;

  dirnest := max(0, dirnest + nestinc); {update nesting level as result of token}
  preind := preind + preindinc;
  goto loop_otk;                       {back for next token this input line}

done_otk:                              {content of this input line exhausted}
{
*   Write the comment from this input line, if any, to the output.
}
  if line_p^.comm_p = nil then goto done_ocomm; {no comment on this line ?}

  if line_p^.comcol = 1 then begin     {comment started in column 1 ?}
    ocomment (1, false);               {write the comment at start of line}
    goto done_ocomm;
    end;

  if                                   {align this comment with opcodes ?}
      (tktype = tktype_first_k) and    {no content tokens on this line ?}
      (line_p^.comcol <= (col_opc + col_oper) div 2) {aligned with opcode ?}
      then begin
    ocomment (col_opc, false);         {write in opcode position}
    goto done_ocomm;
    end;

  if                                   {align this comment with operands ?}
      (tktype = tktype_first_k) and    {no content tokens on this line ?}
      (line_p^.comcol <= (col_oper + col_com) div 2) {aligned with operands ?}
      then begin
    ocomment (col_oper, false);        {write in opcode position}
    goto done_ocomm;
    end;

  if tktype = tktype_first_k
    then begin                         {was end of line comment alone on line}
      ocomment (col_com, false);       {write end of line comment, leave formatting}
      end
    else begin
      ocomment (col_com, true);        {end of line comment, strip leading spaces}
      end
    ;
done_ocomm:                            {done writing comment to output buffer}

done_obuf:                             {done setting BUF to this output line}
{
*   The output buffer is all set for this output line.
}
  string_unpad (buf);                  {remove any trailing blanks from this line}

  if buf.len = 0
    then begin                         {this output line is blank}
      nblank := nblank + 1;            {count one more unwritten blank output line}
      end
    else begin                         {this line is non-blank}
      parm.len := 0;                   {make a blank line}
      while nblank > 0 do begin        {loop over each preceeding unwritten blank line}
        file_write_text (parm, conn, stat); {write this blank line}
        sys_error_abort (stat, '', '', nil, 0);
        if forum then begin            {correcting for Microchip forum editor ?}
          file_write_text (parm, conn, stat); {write extra blank line for each real blank}
          sys_error_abort (stat, '', '', nil, 0);
          end;
        nblank := nblank - 1;          {count one less blank line left to write}
        end;
      file_write_text (buf, conn, stat); {write this line to output file}
      sys_error_abort (stat, '', '', nil, 0);
      buf.len := 0;                    {reset output buffer to empty}
      end
    ;
  oline1 := false;                     {now definitely not working on first output line}
  line_p := line_p^.next_p;            {advance to next input line}
  goto loop_newoline;                  {back to do completely new input line}

done_out:                              {the list of input lines has been exhausted}
  file_close (conn);                   {close the output file}
  end.
