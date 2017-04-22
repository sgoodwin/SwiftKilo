import Darwin
import Foundation

let tabWidth = 9

struct EditorConfig {
  var cursorX: Int
  var cursorY: Int
  var renderX: Int
  var rowOffset: Int
  var columnOffset: Int
  let rows: Int
  let columns: Int
  var originalTermios = termios()
  var row = [EditorRow]()
  var numRows: Int = 0
  var filename: String
  var statusMessage: String
  var statusMessageTime: Date?

  init() {
    guard let size = getWindowSize() else { die("window size"); fatalError("window size") }

    self.cursorX = 0
    self.cursorY = 0
    self.renderX = 0
    self.rowOffset = 0
    self.columnOffset = 0

    self.rows = size.rows - 2
    self.columns = size.columns

    self.filename = "[No Name]"

    self.statusMessage = ""
    self.statusMessageTime = nil
  }

  mutating func setStatusMessage(_ message: String) {
    self.statusMessage = message
    self.statusMessageTime = Date()
  }

  mutating public func appendRow(chars: UnsafeMutablePointer<CChar>?, linelen: Int) {
    guard linelen > 0 else {
      return
    }
    var newRow = EditorRow()
    newRow.size = linelen
    newRow.chars = [CChar](repeating: 0, count: linelen)
    memcpy(&newRow.chars, chars, linelen)
    newRow.updateRow()

    self.row.append(newRow)
    numRows += 1

  }
}

fileprivate func getWindowSize() -> (rows: Int, columns: Int)? {
  var size = winsize()

  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == -1 || size.ws_col == 0 {
    return (rows: 40, columns: 40)
  } else {
    return (rows: Int(size.ws_row), columns: Int(size.ws_col))
  }
}
