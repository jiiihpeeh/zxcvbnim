import
    json,
    sequtils,
    strutils,
    unicode

func snakeToCamel*(s: string): string{.inline.} =
    var cs = s
    if s.contains("_"):
        let
            ss = s.split("_")
        if ss.len > 1:
            cs = ss[0] & foldl(ss[1..<ss.len], a & b.capitalize(), "")
    return cs

proc toCamel*[T](preparedNode: T): JsonNode =
    var cNode = parseJson("{}")
    for k, v in preparedNode.pairs():
        cNode.add(snakeToCamel(k), v)
    return cNode
