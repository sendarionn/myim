public enum DictionaryTSVFieldCodec {
    private static let escapedPrefix = "@myim-escaped:"

    public static func encode(_ value: String) -> String {
        guard value.hasPrefix(escapedPrefix)
                || value.contains("\n")
                || value.contains("\r")
                || value.contains("\t") else {
            return value
        }

        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(character)
            }
        }
        return escapedPrefix + escaped
    }

    public static func decode(_ value: String) -> String {
        guard value.hasPrefix(escapedPrefix) else { return value }

        let escaped = value.dropFirst(escapedPrefix.count)
        var decoded = ""
        var isEscaping = false
        for character in escaped {
            if isEscaping {
                switch character {
                case "n": decoded.append("\n")
                case "r": decoded.append("\r")
                case "t": decoded.append("\t")
                case "\\": decoded.append("\\")
                default:
                    decoded.append("\\")
                    decoded.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                decoded.append(character)
            }
        }
        if isEscaping {
            decoded.append("\\")
        }
        return decoded
    }
}
