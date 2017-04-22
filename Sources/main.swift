import Darwin
import Foundation

// Data

var editorConfig = EditorConfig()
let KiloVersion = "1.0b1"

let arrowRight: Int = 1000
let arrowUp: Int = 1001
let arrowDown: Int = 1002
let arrowLeft: Int = 1003
let pageUp: Int = 1004
let pageDown: Int = 1005
let homeKey: Int = 1006
let endKey: Int = 1007
let deleteKey: Int = 1008

func control(_ key: CChar) -> CChar {
  return key & 0x1f
}

// file i/o

func editorOpen(_ filename: String) {
  guard let fp = fopen(filename, "r") else {
    die("fopen")
    return
  }

  var line: UnsafeMutablePointer<CChar>?
  var linecap: size_t = 0
  var linelen: size_t = 0
  while linelen != -1 {
    linelen = getline(&line, &linecap, fp)
    while linelen > 0 && (line![linelen - 1] == "\n" 
      || line![linelen - 1] == "\r") {
      linelen -= 1
    }
    editorConfig.appendRow(chars: line, linelen: linelen)
  }
  free(line)
  fclose(fp)
}

// Terminal

func die(_ s: String) {
  write(STDOUT_FILENO, "\u{1B}[2J", 4)
  write(STDOUT_FILENO, "\u{1B}[H", 3)

  perror(s)
  exit(1)
}

func disableRawMode() {
  if tcsetattr(STDIN_FILENO, TCSAFLUSH, &editorConfig.originalTermios) == -1 {
    die("tcsetattr")
  }
}

func enableRawMode() {
  if tcgetattr(STDIN_FILENO, &editorConfig.originalTermios) == -1 {
    die("tcgetattr")
  }
  atexit(disableRawMode)

  var raw = editorConfig.originalTermios
  raw.c_iflag &= ~(tcflag_t(ICRNL | IXON))
  raw.c_oflag &= ~(tcflag_t(OPOST))
  raw.c_lflag &= ~(tcflag_t(ECHO | ICANON | IEXTEN | ISIG))
  raw.c_cc.6 = 0 // VMIN
  raw.c_cc.5 = 1 // VTIME

  if tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1 {
    die("tcsetattr")
  }
}

func editorReadKey() -> Int {
  var nread = 0
  var c = CChar()

  while nread != 1 {
    nread = read(STDIN_FILENO, &c, 1)
    if nread == -1 { die("read") }
  }

if c == "\u{1B}" {
  var sequence = [CChar](repeating: " ", count: 3)

  if read(STDIN_FILENO, &sequence[0], 1) != 1 { return Int(c) }
  if read(STDIN_FILENO, &sequence[1], 1) != 1 { return Int(c) }

  if sequence[0] == "[" {
    if sequence[1] >= 0 && sequence[1] <= "9" {
      if read(STDIN_FILENO, &sequence[2], 1) != 1 { return Int(c) }
      if sequence[2] == "~" {
        switch sequence[1] {
          case "1": return homeKey
          case "3": return deleteKey
          case "4": return endKey
          case "5": return pageUp
          case "6": return pageDown
          case "7": return homeKey
          case "8": return endKey
          default: return Int(c)
        }
      }
    }

    switch sequence[1] {
      case "A": return arrowUp
      case "B": return arrowDown
      case "C": return arrowRight
      case "D": return arrowLeft
      case "H": return homeKey
      case "F": return endKey
      default: return Int(c)
    }
  } else if sequence[0] == "O" {
    switch sequence[1] {
      case "H": return homeKey
      case "F": return endKey
      default: return Int(c)
    }
  }

  return Int(c)
}
return Int(c)
}


// Input

func editorMoveCursor(_ key: Int) {
  switch key {
  case arrowLeft:
    if editorConfig.cursorX != 0 {
      editorConfig.cursorX -= 1
    }
  case arrowDown:
    if editorConfig.cursorY < editorConfig.rows {
      editorConfig.cursorY -= 1
    }
  case arrowUp:
    if editorConfig.cursorY != 0 {
      editorConfig.cursorY += 1
    }
  case arrowRight:
    editorConfig.cursorX += 1
  default:
    return
  }
}

func editorProcessKeypress() {
  let c = editorReadKey()

  switch c {
  case Int(control("q")):
    write(STDOUT_FILENO, "\u{1B}[2J", 4)
    write(STDOUT_FILENO, "\u{1B}[H", 3)

    exit(0)
  case arrowUp, arrowDown, arrowLeft, arrowRight:
    editorMoveCursor(c)
  case pageUp, pageDown:
    let times = editorConfig.rows
    for _ in 0..<times {
      editorMoveCursor(c == pageUp ? arrowUp : arrowDown)
    }
  case homeKey:
    editorConfig.cursorX = 0
  case endKey:
    editorConfig.cursorX = editorConfig.columns - 1
  default:
    return
  }
}

// Output

func editorScroll() {
  if editorConfig.cursorY < editorConfig.rowOffset {
    editorConfig.rowOffset = editorConfig.cursorY
  }
  if editorConfig.cursorY >= editorConfig.rowOffset + editorConfig.rows {
    editorConfig.rowOffset = editorConfig.cursorY - editorConfig.rows + 1
  }
  if editorConfig.cursorX < editorConfig.columnOffset {
    editorConfig.columnOffset = editorConfig.cursorX
  }
  if editorConfig.cursorX >= editorConfig.columnOffset + editorConfig.columns {
    editorConfig.columnOffset = editorConfig.cursorX - editorConfig.columns + 1
  }
}

func editorDrawRows(_ buffer: inout String) {
  for y in 0..<editorConfig.rows {
    let filerow = y + editorConfig.rowOffset
    if filerow >= editorConfig.numRows {
      if editorConfig.numRows == 0 && y == (editorConfig.rows / 3) {
        let message = "SwiftKilo editor -- version \(KiloVersion)"
        var length = message.characters.count
        if length > editorConfig.columns { length = editorConfig.columns }
        var padding = (editorConfig.columns - length)/2
        if padding > 0 {
          buffer += "~"
          padding -= 1
        } 
        buffer += String(repeating: " ", count: padding)

        buffer += message.substring(to: message.index(message.startIndex, offsetBy: length))
      } else {
        buffer += "~"
      }
    } else {
      let offset = editorConfig.columnOffset
      let row = editorConfig.row[filerow]
      var length = row.size - offset
      if length < 0 { length = 0 }
      if length > editorConfig.columns { length = editorConfig.columns }
      buffer += String(cString: Array(row.chars[offset..<length]))
    }

    buffer += "\u{1B}[K"

    if y < editorConfig.rows - 1 {
      buffer += "\r\n"
    }
  }
}

func editorRefreshScreen() {
  editorScroll()

  var buffer = ""
  buffer += "\u{1B}[?25l"
  buffer += "\u{1B}[H"

  editorDrawRows(&buffer)

  buffer += "\u{1B}[\((editorConfig.cursorY - editorConfig.rowOffset) + 1);\(editorConfig.cursorX + 1)H"

  buffer += "\u{1B}[?25h"

  write(STDOUT_FILENO, buffer, buffer.utf8CString.count)
}

func main() {
  enableRawMode()
  if CommandLine.argc >= 2 {
    editorOpen(CommandLine.arguments[1])
  }

  while true {
    editorRefreshScreen()
    editorProcessKeypress()
  }
}
main()
