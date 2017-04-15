import Darwin

var originalTermios = termios()

  func control(_ key: CChar) -> CChar {
    return key & 0x1f
  }

func die(_ s: String) {
  perror(s)
    exit(1)
}

func disableRawMode() {
  if tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios) == -1 {
    die("tcsetattr")
  }
}

func enableRawMode() {
  if tcgetattr(STDIN_FILENO, &originalTermios) == -1 {
    die("tcgetattr")
  }
  atexit(disableRawMode)

    var raw = originalTermios
    raw.c_iflag &= ~(tcflag_t(ICRNL | IXON))
    raw.c_oflag &= ~(tcflag_t(OPOST))
    raw.c_lflag &= ~(tcflag_t(ECHO | ICANON | IEXTEN | ISIG))
    raw.c_cc.6 = 0 // VMIN
    raw.c_cc.5 = 1 // VTIME

    if tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1 {
      die("tcsetattr")
    }
} 

func main() {
  enableRawMode()

    while true {
      var c:CChar = CChar()

        if read(STDIN_FILENO, &c, 1) == -1 {
          die("read")
        }

      if iscntrl(Int32(c)) == 1 {
        print("control char \(c)", terminator: "\r\n")
      } else {
        print("printable char \(UnicodeScalar(UInt32(c))!.escaped(asASCII: true))", terminator: "\r\n")
      }

      if c == control("q") {
        break
      }
    }
}
main()
