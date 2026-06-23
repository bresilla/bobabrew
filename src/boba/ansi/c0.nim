## C0 and C1 control codes, and core escape-sequence introducers.
## Port of `x/ansi/c0.go`, `c1.go`, and the constants from `ansi.go`.

const
  NUL* = '\x00'
  SOH* = '\x01'
  STX* = '\x02'
  ETX* = '\x03'  ## Ctrl+C
  EOT* = '\x04'  ## Ctrl+D
  ENQ* = '\x05'
  ACK* = '\x06'
  BEL* = '\x07'  ## bell
  BS*  = '\x08'  ## backspace
  HT*  = '\x09'  ## horizontal tab
  LF*  = '\x0a'  ## line feed
  VT*  = '\x0b'
  FF*  = '\x0c'
  CR*  = '\x0d'  ## carriage return
  SO*  = '\x0e'
  SI*  = '\x0f'
  CAN* = '\x18'
  SUB* = '\x1a'
  ESC* = '\x1b'  ## escape
  DEL* = '\x7f'

  # C1 (8-bit) and their 7-bit ESC equivalents.
  IND* = "\x1bD"   ## index
  NEL* = "\x1bE"   ## next line
  HTS* = "\x1bH"   ## horizontal tab set
  RI*  = "\x1bM"   ## reverse index
  SS2* = "\x1bN"
  SS3* = "\x1bO"
  DCS* = "\x1bP"   ## device control string
  SOS* = "\x1bX"
  CSI* = "\x1b["   ## control sequence introducer
  ST*  = "\x1b\\"  ## string terminator
  OSC* = "\x1b]"   ## operating system command
  PM*  = "\x1b^"
  APC* = "\x1b_"
