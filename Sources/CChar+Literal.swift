extension CChar: ExpressibleByStringLiteral {
  public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = Character
    public typealias UnicodeScalarLiteralType = UnicodeScalar

    public init(stringLiteral value: String) {
      self.init(value.utf8CString[0])
    }

  public init(extendedGraphemeClusterLiteral value: Character) {
    self.init(stringLiteral: String(value))
  }

  public init(unicodeScalarLiteral value: UnicodeScalar) {
    self.init(stringLiteral: String(value))
  }

}
