import tables
import strutils
import options
import jsony
import json
import sequtils
from unicode import runelen
import algorithm
import os
import supersnappy


const settingFile = "adjacentSettings.json"

const qwerty = """
`~ 1! 2@ 3# 4$ 5% 6^ 7& 8* 9( 0) -_ =+
    qQ wW eE rR tT yY uU iI oO pP [{ ]} \|
     aA sS dD fF gG hH jJ kK lL ;: ""
      zZ xX cC vV bB nN mM ,< .> /?
"""

const dvorak = """
`~ 1! 2@ 3# 4$ 5% 6^ 7& 8* 9( 0) [{ ]}
    "" ,< .> pP yY fF gG cC rR lL /? =+ \|
     aA oO eE uU iI dD hH tT nN sS -_
      ;: qQ jJ kK xX bB mM wW vV zZ
"""

const keypad = """
  / * -
7 8 9 +
4 5 6
1 2 3
  0 .
"""

const macKeypad = """
  = / *
7 8 9 -
4 5 6 +
1 2 3
  0 .
"""
type 
    coords = seq[array[2,int]]
    AdjkeySubTable = OrderedTable[string, seq[Option[string]]]
    AdjkeyTable = OrderedTable[string,AdjkeySubTable]
    optionSeq = seq[Option[string]]
    KbConsts = tuple
        KEYBOARD_AVERAGE_DEGREE: float 
        KEYPAD_AVERAGE_DEGREE : float
        KEYBOARD_STARTING_POSITIONS: int 
        KEYPAD_STARTING_POSITIONS : int
    SettingsType = seq[tuple[kb:string, cont:string, v:bool]] 

proc defaultSettings():SettingsType=
    let kbSeq : SettingsType =  @[("qwerty", qwerty, true),
                                ("dvorak", dvorak, true),
                                ("keypad", keypad, false),
                                ("mac_keypad", macKeypad, false)]
    writeFile(settingFile, kbSeq.toJson())
    return kbSeq

func getSlantedAdjacentCoords(x: int, y: int):coords=
#[     returns the six adjacent coordinates on a standard keyboard, where each row is slanted to the
    right from the last. adjacencies are clockwise, starting with key to the left, then two keys
    above, then right key, then two keys below. (that is, only near-diagonal keys are adjacent,
    so g"s coordinate is adjacent to those of t,y,b,v, but not those of r,u,n,c.] ]#

    return @[[x - 1, y], [x, y - 1], [x + 1, y - 1], [x + 1, y], [x, y + 1], [x - 1, y + 1]]


func getAlignedAdjacentCoords(x : int, y : int): coords=
    #returns the nine clockwise adjacent coordinates on a keypad, where each row is vert aligned.

    return @[[x - 1, y], [x - 1, y - 1], [x, y - 1], [x + 1, y - 1], [x + 1, y], [x + 1, y + 1],
            [x, y + 1], [x - 1, y + 1]]


proc adjacencyFunc(x:int, y:int, slanted : bool): coords=
    if slanted:
        return getSlantedAdjacentCoords(x,y)
    else:
        return getAlignedAdjacentCoords(x,y)


proc buildGraph(layoutStr : string, slanted : bool): OrderedTable[string, seq[Option[string]]]=
#[  builds an adjacency graph as a dictionary: {character: [adjacent_characters]}.
    adjacent characters occur in a clockwise order.
    for example:
    * on qwerty layout, "g" maps to ["fF", "tT", "yY", "hH", "bB", "vV"]
    * on keypad layout, "7" maps to [none, none, none, "=", "8", "5", "4", none] ]#

    var positionTable = initOrderedTable[array[2,int], string]()  # maps from array (x,y) -> characters at that position.
    let 
        tokens = layoutStr.split()
        tokensF = filter(tokens, proc(x: string): bool = x.runeLen > 0)
        tokenSize = len(tokensF[0])
        xUnit = tokenSize + 1  # x position unit len is token len plus 1 for the following whitespace.
    #assert all(len(token) == tokenSize for token in tokens), "token len mismatch:\n " + layoutStr
    func slanter(y: int, slanted: bool): int=
        var slant = 0
        if slanted:
            slant = y - 1
        return slant

    var y = 1
    for line in layoutStr.split("\n"):
        if line.len == 0:
            continue
        let slant = slanter(y, slanted)
        var collStr = ""
        for token in line.split():
            if token.len == 0:
                collStr &= " "
                continue
            assert token.runeLen == xUnit - 1
            let x = (collStr.runeLen - slant) div xUnit
            let remainder = (collStr.runeLen - slant) mod xUnit
            assert remainder == 0
            collStr &= " " & token
            positionTable[[x, y]] = token 
        y.inc


    var adjacencyGraph = initOrderedTable[string, optionSeq]()
    for xy, characters in positionTable.pairs():
        for character in characters:
            adjacencyGraph[$character] = newSeq[Option[string]](0)
            for coord in adjacencyFunc(xy[0], xy[1], slanted):
                # position in the list indicates direction
                # (for qwerty, 0 is left, 1 is top, 2 is top right, ...)
                # for edge chars like 1 or m, insert none as a placeholder when needed
                # so that each character in the graph has a same-length adjacency list.
                var agInsert = none(string)
                if positionTable.hasKey(coord):
                    agInsert = some(positionTable[coord])
                adjacencyGraph[$character].add(agInsert) 
    return adjacencyGraph

func calcSeqSomeCount(sequence : seq[Option[string]]) : int=
    var sc = 0
    for i in sequence:
        if i.isSome:
            sc.inc
        else:
            discard
    return sc

proc calcAverageDegree(graph : OrderedTable[string, seq[Option[string]]]): float=
    var 
        average : float = 0
        keyCount = 0
    for key, neighbors in pairs(graph):
        average += float(calcSeqSomeCount(neighbors))
        keyCount.inc
    average /= float(keyCount)
    return average

var readSettings : SettingsType
if fileExists(settingFile):
    readSettings = readFile(settingFile).fromJson(SettingsType)
else:
    readSettings = defaultSettings()


proc buildAdjacencyGraphs*(outDir:string): auto=
    let 
        graphOut = joinPath(outDir,"Graph.json")
        constOut = joinPath(outDir,"KeyboardConst.json")
        kbSeq = readSettings
    var 
        resultTable : AdjkeyTable #= initTable()
        jn = parseJson("""{}""")
    for  arg in kbSeq:
        let graphName = arg.kb
        var graph = buildGraph(arg.cont, arg.v)
        var graphKeys : seq[string]
        newSeq(graphKeys,0)
        for i in graph.keys():
            graphKeys.add(i)
        graphKeys = graphKeys.sorted(system.cmp[string])
        var sortedGraph = initOrderedTable[string, seq[Option[string]]]()
        for i in graphKeys:
            if not graph.hasKey(i):
                continue
            sortedGraph[$i] = graph[$i]

        resultTable[graphName] = sortedGraph
        jn.add(graphName, %sortedGraph)
    let gSerialized = jn.toJson()
    #writeFile(graphOut, gSerialized)
    writeFile(graphOut & ".snappy", compress(gSerialized))

    let 
        kbAvg = calcAverageDegree(resultTable["qwerty"])
        kpAvg = calcAverageDegree(resultTable["keypad"])
        kbCount = len(resultTable["qwerty"])
        kpCount = len(resultTable["keypad"])
        calculated : KbConsts = (kbAvg, kpAvg, kbCount, kpCount)
    let cSerialized = calculated.toJson()
    #writeFile(constOut, cSerialized)
    writeFile(constOut & ".snappy", compress(cSerialized))


