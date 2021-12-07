import
    strutils,
    terminal,
    zxcvbnim,
    os

var terminate = false
proc ctrlC() {.noconv.} =
    write(stderr, "\nTo exit press RETURN\n")
    terminate = true

const helpMsg = """
$1 OPTION    Passtimator – PasswordEstimator
    zxcvbn clone written in NIM
-stdin , -s read from stdin (echo "SuP3rs3cure_pAssw0rd!" | $1 --stdin)
-n print only the guess count
-h print this thingy and have a life
"""

proc printHelp() =
    echo helpMsg % [getAppFilename()]


var
    password: string
    json: bool = true
    prompt: bool = true
for arg in commandLineParams():
    case arg:
    of "--stdin", "-s":
        password = readAll(stdin).strip()
        prompt = false
    of "-n":
        json = false
    of "-h":
        printHelp()
        quit(0)
    else:
        write(stderr, "Wut?\n")
        printHelp()
        quit(1)

if prompt:
    setControlCHook(ctrlC)
    password = readPasswordFromStdin(prompt = "Password: ")
    unsetControlCHook()
if terminate:
    quit(2)

if password.len > 0:
    if json:
        echo zxcvbnimPrettyReport(password)
    else:
        echo zxcvbnimEstimate(password)
else:
    printHelp()
 
