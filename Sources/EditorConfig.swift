import Darwin

struct EditorConfig {
  var cursorX: Int
  var cursorY: Int
  let rows: Int
  let columns: Int
  var originalTermios = termios()

  init() {
    guard let size = getWindowSize() else { die("window size"); fatalError("window size") }

    self.cursorX = 0
    self.cursorY = 0

    self.rows = size.rows
    self.columns = size.columns
  }
}

fileprivate func getWindowSize() -> (rows: Int, columns: Int)? {
  var size = winsize()

  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == -1 || size.ws_col == 0 {
    return nil
  } else {
    return (rows: Int(size.ws_row), columns: Int(size.ws_col))
  }
}
