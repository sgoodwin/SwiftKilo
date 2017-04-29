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
  var dirty = 0

  init() {
    guard let size = getWindowSize() else { die("window size"); fatalError("window size") }

    self.cursorX = 0
    self.cursorY = 0
    self.renderX = 0
    self.rowOffset = 0
    self.columnOffset = 0

    let row = EditorRow()
    self.row = [ row ]
    self.numRows = 1

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

  mutating func deleteChar() {
    guard cursorY != numRows else { return }
    if cursorY == 0 && cursorX == 0 { return }

    var row = self.row[cursorY]
    if cursorX > 0 {
      row.deleteChar(at: cursorX - 1)
      cursorX -= 1
      self.row[cursorY] = row
    } else {
      var modifiedRow = self.row[cursorY - 1]
      cursorX = modifiedRow.size
      modifiedRow.appendString(row.chars)
      self.row[cursorY - 1] = modifiedRow
      deleteRow(cursorY)
      cursorY -= 1
    }
    dirty += 1
  }

  mutating func insertChar(_ char: CChar) {
    if cursorY == numRows {
      appendRow(chars: nil, linelen: 0)
    }
    var row = self.row[cursorY]
    row.insertChar(char, at: cursorX)
    self.row[cursorY] = row

    cursorX += 1
    dirty += 1
  }

  mutating func deleteRow(_ at: Int) {
    guard at > 0, at < numRows else { return }

    row.remove(at: at)
    numRows -= 1
    dirty += 1
  }

  mutating func appendRow(chars: UnsafeMutablePointer<CChar>?, linelen: Int) {
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
    dirty += 1
  }

  private func rowsToString() -> String {
    return row.map({ String(cString: $0.chars) }).joined(separator: "\n")
  }

  mutating func save() {
    guard filename != "[No Name]" else {
      return
    }

    let buffer = rowsToString()
    let len = buffer.lengthOfBytes(using: .ascii)
    let fd = open(filename, O_RDWR | O_CREAT, 0644)
    if fd != -1 {
      if ftruncate(fd, off_t(len)) != -1 {
        if write(fd, buffer, len) == len {
          close(fd)
          setStatusMessage("\(len) bytes written to disk")
          dirty = 0
          return
        }
      }
      close(fd)
    }
    setStatusMessage("Failed to save: \(strerror(errno))")
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
