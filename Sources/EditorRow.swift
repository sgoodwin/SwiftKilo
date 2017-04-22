import Darwin

struct EditorRow {
  var size = 0
  var chars = [CChar]()
  var render = [CChar]()
  var renderSize = 0

  mutating func updateRow() {
    render = convert(chars)
    renderSize = render.count
  }

  func cursorXtoRenderX(_ cursorX: Int) -> Int {
    return convert(Array(chars[0..<cursorX])).count
  }

  private func convert(_ chars: [CChar]) -> [CChar] {
    return chars.flatMap { character -> [CChar] in 
      switch character {
      case "\t":
        return Array(repeating: " ", count: tabWidth)
      default:
        return [character]
      }
    }
  }

  mutating func insertChar(_ char: CChar, at: Int) {
    var index = at
    if index < 0 || index > self.size {
      index = self.size
    }

    chars.insert(char, at: index)
    size += 1
    updateRow()
  }
}
