import os, strutils
proc getExternpath*(file:string):string{.compiletime.}=
    if fileExists("../resources/DictFreq.json.snappy"):
        return joinPath("resources", file)
    else:
        let path = staticExec("nimble path zxcvbnim").strip()
        return joinPath(path,  "resources", file)