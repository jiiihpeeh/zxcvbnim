import buildFrequencyLists
import buildAdjacencyGraphs
import os
import strutils
import rdstdin
import sequtils
import osproc
import times
from math import round

const 
    usage = """
$1 OPTIONS
-d, --dictionary        directory (default: dictionaryData).   Generate a dictionary file.
-k, --keyboard                                                 Generate  a keyboard and constant files.
-y                                                             Overwrite files
-a, --all                                                      Enable all modes
-o, --out               directory (default : output)           Output directory
-h, --help                                                     Print this help

Run everything in default mode: $1 -a

Custom example: $1 -d customDics/ -o newOutput/ -y
Dictionary and keyboard related files are in JSON format and will be 
written if those do not exists once the procedure is called (such as $1 -a -y)
"""
#-l, --library                                                  Enable dynamic library for faster loading.
    opts = {poUsePath, poDaemon, poStdErrToStdOut}
    
let 
    originalDir = getCurrentDir()
var
    dictionary : bool
    keyboard : bool
    library : bool
    overwriteOrRun = false
    outDir : string = joinPath(originalDir, "output")
    dictDir : string = joinPath(originalDir, "dictionaryData")


template giveDir(count: int, default: string): string=
    var p = default
    if count <= paramCount():
        if not paramStr(count + 1).startsWith("-"): 
            p = paramStr(count + 1)
    p


proc helpMsg()=
    write(stdout, usage % [paramStr(0)])

template filesIn(directory: string):auto=
    toSeq(walkDir(directory, relative=true)) 

func hasProcessedData(outDir : string): bool=
    var filesState = true
    let dataFiles = ["DictFreq.json", "Graph.json", "KeyboardConst.json"]
    for f in dataFiles:
        if not fileExists(joinPath(outDir,f)):
            filesState = false
            break
    return filesState

for count in 0..paramCount():
    let arg = paramStr(count)
    case arg:
    of  "--keyboard", "-k":
        keyboard = true
    of "-d", "--dictionary":
        dictionary = true
        dictDir = giveDir(count, dictDir)
    of "-l", "--library":
        library = true
    of "-a", "--all":
        keyboard = true 
        dictionary = true
        library = true
    of "-o", "--out":
        outDir = giveDir(count, outDir)
    of "-y":
        overwriteOrRun = true
    of "-h", "--help":
        helpMsg()
        quit(0)
    else:
        discard
if not (keyboard or dictionary or library):
    write(stdout, "Nothing to do.\n")
    helpMsg()
    quit(0)

if dirExists(outDir) and overwriteOrRun == false and  filesIn(outDir).len > 0:
    let 
        guess = "Directory $1 exists. Overwrite? (Y/n): " % [outDir]
        ans = readLineFromStdin(guess)
    if not ["y", "yes"].contains(ans.strip().toLower()):
        write(stderr,"Will exit now.\n")
        quit(3)
    else:
        overwriteOrRun = true
elif dirExists(outDir):
    overwriteOrRun = true
else:
    try:
        createDir(outDir)
        overwriteOrRun = true
    except:
        write(stderr,"Can not continue.\n")
        helpMsg()
        quit(1)

if overwriteOrRun:
    write(stdout,"Selected a directory: $1.\n" % [outDir])
else:
    helpMsg()
    quit(0)
    

template withTimer(body: untyped) =
    var startTime = epochTime()
    body
    write(stdout,"Done (in $1 s).\n" % [$round(epochTime() - startTime, 5)])

if dictionary and dirExists(dictDir) and filesIn(dictDir).len > 0:
    withTimer:
        write(stdout,"Processing a dictionary.\n")
        frequencyWrite(dictDir, outDir)

if keyboard:
    withTimer:
        write(stdout,"Processing keyboard layouts.\n")
        buildAdjacencyGraphs(outDir)
    
#[ if library:
    let 
        sourceFile = "zxcvbnimData.nim"
        executable = findExe("nim")
        procArgs  = ["c", "--app:lib", "-d:release", "--gc:none", sourceFile]
    if executable.len == 0:
        write(stderr,"Compiler not found in PATH or directory .\n")
        quit(2)
    if not fileExists(sourceFile):
        write(stderr,"Source code file not found.\n")
        quit(2)
    if not hasProcessedData(outDir):
        write(stderr,"Data is missing.\n")
        quit(2)
    withTimer:
        copyFileToDir(sourceFile, outDir)
        setCurrentDir(outDir)
        write(stdout,"Compiling a library.\nThis may take a while...\n")
        echo executable & " " & join(procArgs, " ")
        let process =  startProcess(command = executable,
                        args= procArgs, options= opts)
        for line in process.lines:
                echo line
        process.close
        removeFile(sourceFile)
        setCurrentDir(originalDir)
        write(stdout, "Exit code $1\n" % [$process.peekExitCode()])
  ]#