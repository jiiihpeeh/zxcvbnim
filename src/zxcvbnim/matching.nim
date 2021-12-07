import
    #nimpcre,
    re,
    tables,
    unicode,
    sugar,
    algorithm,
    sequtils,
    strutils,
    sets,
    scoring,
    math,
    options,
    reportobjects


const L33T_TABLE: Table[string, seq[string]] = {
    "a": @["4", "@"],
    "b": @["8"],
    "c": @["(", "{", "[", "<"],
    "e": @["3"],
    "g": @["6", "9"],
    "i": @["1", "!", "|"],
    "l": @["1", "|", "7"],
    "o": @["0"],
    "s": @["$", "5"],
    "t": @["+", "7"],
    "x": @["%"],
    "z": @["2"],
}.toTable

let REGEXEN = {
    "recent_year": re("""19\d\d|200\d|201\d|202\d""")}.toTable

const
    DATE_MAX_YEAR: int = 2050
    DATE_MIN_YEAR: int = 1000
    DATE_SPLITS: Table[int, seq[array[2, int]]] = {
        4: @[       # for length-4 strings, eg 1191 or 9111, two ways to split:
        [1, 2],     # 1 1 91 (2nd split starts at index 1, 3rd at index 2)
        [2, 3],     # 91 1 1
    ],
        5: @[
            [1, 3], # 1 11 91
            [2, 3], # 11 1 91
        ],
        6: @[
            [1, 2], # 1 1 1991
            [2, 4], # 11 11 91
            [4, 5], # 1991 1 1
        ],
        7: @[
            [1, 3], # 1 11 1991
            [2, 3], # 11 1 1991
            [4, 5], # 1991 1 11
            [4, 6], # 1991 11 1
        ],
        8: @[
            [2, 4], # 11 11 1991
            [4, 6], # 1991 11 11
        ],
    }.toTable

func sortMatch(matches: seq[Report]): seq[Report] {.inline.} =
    matches.sortedByIt(it.j).sortedByIt(it.i)

#[ unicode interval of a string
    template grab(s: string, a: int, b : int): string=
    s.runeSubStr(a, b - a + 1) ]#


proc dictionaryMatch*[T](password: string, rankedDictionaries: T): seq[Report] =
    var matches: seq[Report]
    let
        length = password.len
        passwordLower = $password.toLower()
    for dictionaryName, rankedDict in rankedDictionaries.pairs():
        for i in 0..<length:
            for j in countup(i, length - 1):
                if rankedDict.hasKey(passwordLower[i..j]):
                    let
                        word = passwordLower[i..j]
                        rank = rankedDict[word]
                    var report = Report(
                        kind: Dictionary,
                        pattern: "dictionary",
                        i: i,
                        j: j,
                        token: password[i..j],
                        matchedWord: word,
                        rank: rank,
                        baseGuesses: rank,
                        dictionaryName: dictionaryName,
                        reversed: false,
                        l33t: false,
                        )
                    report.uppercaseVariations = uppercaseVariations(report)
                    #report.l33t_variations = l33t_variations(report)
                    report.guesses = estimateGuesses(report.token, password,
                            dictionary_guesses(report))
                    report.guessesLog10 = log10(report.guesses)
                    matches.add(report)
    return matches.sortMatch()

proc reverseDictionaryMatch*[T](password: string, rankedDictionaries: T): seq[Report] =
    let reversedPassword = reversed(password)
    var matches: seq[Report]
    matches = dictionaryMatch(reversedPassword, rankedDictionaries)
    for match in 0..<matches.len:
        matches[match].token = join(reversed(matches[match].token), "")
        matches[match].reversed = true
        matches[match].guesses = 2 * matches[match].guesses
        matches[match].guessesLog10 = log10(matches[match].guesses)
        let
            tempi = matches[match].i
            tempj = matches[match].j
        matches[match].i = password.len - 1 - tempj
        matches[match].j = password.len - 1 - tempi
    return matches.sortMatch()


proc relevantL33tSubTable(password: string,
                        table: LTT): LTT =
    var passwordChars: seq[string]
    newSeq(passwordChars, 0)
    for letter in runes(password):
        passwordChars.add($letter)

    var subtable = initTable[string, seq[string]]()
    for k, v in table.pairs:
        var relevantSubs = newSeq[string]()
        for j in v:
            if password_chars.contains(j):
                relevantSubs.add(j)
        if relevantSubs.len > 0:
            subtable[k] = relevantSubs
    return subtable


func enumerateL33tSubs(table: LTT): ELST =
    var tkeys = collect(newSeq):
        for i in table.keys: i
    var
        subs: SubType
        deduped: SubType
        subExtension: SubSubType
        subAlternative: SubSubType
        dupL33tIndex: int
        assoc: AssocType
        members = initHashSet[AssocType]()
        subDict = initTable[string, string]()
        nextSubs: SubType
        firstKey: string
    newSeq(subs, 1)

    func dedup(subs: SubType): SubType =
        newSeq(deduped, 0)
        members.clear()
        for sub in subs:
            newSeq(assoc, 0)
            assoc.add(sub)
            assoc = assoc.sortedByIt(it[0])
            if members.missingOrExcl(assoc):
                members.incl(assoc)
                deduped.add(sub)

        return deduped

    func helper(subs: var SubType): SubType =
        firstKey = $tkeys.pop()
        newSeq(nextSubs, 0)
        for l33tChr in table[firstKey]:
            for sub in subs:
                dupL33tIndex = -1
                for i in 0..<sub.len:
                    if $sub[i][0] == l33tChr:
                        dupL33tIndex = i
                        break

                if dupL33tIndex == -1:
                    subExtension = sub
                    subExtension.add([l33tChr, firstKey])
                    nextSubs.add(subExtension)
                else:
                    subAlternative = sub
                    subAlternative.delete(dupL33tIndex)
                    subAlternative.add([l33tChr, firstKey])
                    nextSubs.add(sub)
                    nextSubs.add(subAlternative)
        subs = dedup(nextSubs)
        return subs

    while tkeys.len > 0:
        subs = helper(subs)
    var subDicts: ELST = @[]
    for sub in subs:
        subDict.clear()
        for v in sub:
            subDict[v[0]] = v[1]
        subDicts.add(subDict)
    return subDicts

func translate(instr: string, chrMap: Table[string,
        string]): string {.inline.} =
    var charSeq: seq[string] = @[]
    for letter in runes(instr):
        if chrMap.hasKey($letter):
            charSeq.add(chrMap[$letter])
        else:
            charSeq.add($letter)
    return join(charSeq, "")

proc l33tMatch*[T](password: string, rankedDictionaries: T,
                l33tTable: LTT = L33T_TABLE): seq[Report] =
    var
        matches: seq[Report]
        matchSub: Table[string, string]

    for sub in enumerateL33tSubs(relevantL33tSubtable(password, l33tTable)):
        if sub.len == 0:
            break

        let subbedPassword = translate(password, sub)
        for match in dictionaryMatch(subbedPassword, rankedDictionaries):
            matchSub = initTable[string, string]()
            let token = password[match.i..match.j]
            if token.toLower() == match.matchedWord:
                # only return the matches that contain an actual substitution
                continue
            # subset of mappings in sub that are in use for this match
            if token.runeLen > 1:
                for subbedChr, chr in sub.pairs():

                    if token.contains(subbedChr):
                        matchSub[subbedChr] = chr
                let subDisplay = collect(newSeq):
                    for k, v in matchSub.pairs():
                        "$1 -> $2" % [$k, $v]

                let l33tMatch = Report(
                        kind: Dictionary,
                        matchedWord: match.matchedWord,
                        dictionaryName: match.dictionaryName,
                        rank: match.rank,
                        reversed: match.reversed,
                        i: match.i,
                        j: match.j,
                        guessesLog10: match.guessesLog10,
                        guesses: match.guesses,
                        pattern: match.pattern,
                        l33t: true,
                        token: token,
                        sub: matchSub,
                        baseGuesses: match.rank,
                        subDisplay: join(subDisplay, ", "))
                l33tMatch.uppercase_variations = uppercaseVariations(l33tMatch)
                l33tMatch.l33t_variations = l33t_variations(match, matchSub)
                l33tMatch.guesses = estimateGuesses(l33tMatch.token, password,
                        dictionary_guesses(l33tMatch))
                l33tMatch.guessesLog10 = log10(l33tMatch.guesses)
                matches.add(l33tMatch)
    return matches.sortMatch()


func reduceToRepeatUnit(repstr: string): string {.inline.} =
    var seekStr = repstr
    if seekStr.len < 2:
        return seekStr
    elif seekStr.toHashSet().len() == 1:
        return seekStr[0..0]
    else:
        var count = 2
        while true:
            if seekStr[0..<(seekStr.len div count)].repeat(count) == seekStr:
                seekStr = seekStr[0..<(seekStr.len div count)]
                count = 2
            else:
                count.inc
                if count >= seekStr.len:
                    break
        return seekStr

let SHIFTED_RX = re("""[~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?]""")

proc spatialMatchHelper[T, U](password: string,
    graph: T, graphName: string, kbC: U): seq[Report] =
    var
        matches: seq[Report]
        i = 0
        j: int
        shiftedCount: int
        turns: int
        lastDirection: Option[int]
        curDirection: Option[int]
        foundDirection: Option[int]
        prevChar: string
        adjacents: seq[Option[string]]
        found: bool
        curChar: string
    while i < password.len - 1:
        j = i + 1
        lastDirection = none(int) # == None
        turns = 0
        let shiftfind = findBounds(password[i..i], SHIFTED_RX)
        if @["qwerty", "dvorak"].contains(graphName) and (shiftFind.first != -1):
            # initial character is shifted
            shiftedCount = 1
        else:
            shiftedCount = 0

        while true:
            prevChar = password[j - 1..j - 1]
            found = false
            foundDirection = some(-1)
            curDirection = some(-1)

            if graph.hasKey(prevChar):
                adjacents = graph[prevChar]
            else:
                adjacents = @[]
            # consider growing pattern by one character if j hasn"t gone
            # over the edge.
            if j < password.len:
                curChar = password[j..j]
                for adj in adjacents:
                    if curDirection.isSome:
                        curDirection = some(curDirection.get + 1)

                    if adj.isSome and adj.get.contains(curChar):
                        found = true
                        foundDirection = curDirection
                        if adj.get.len > 1 and curChar[0] == adj.get[1]:
                            # index 1 in the adjacency means the key is shifted,
                            # 0 means unshifted: A vs a, % vs 5, etc.
                            # for example, "q" is adjacent to the entry "2@".
                            # @ is shifted w/ index 1, 2 is unshifted.
                            shiftedCount += 1
                        if lastDirection != foundDirection:
                            # adding a turn is correct even in the initial case
                            # when lastDirection is null:
                            # every spatial pattern starts with a turn.
                            turns += 1
                            lastDirection = foundDirection
                        break
            # if the current pattern continued, extend j and try to grow again
            if found:
                j += 1
            # otherwise push the pattern discovered so far, if any...
            else:
                if j - i > 2: # don"t consider length 1 or 2 chains.
                    var report = Report(
                        kind: Spatial,
                        pattern: "spatial",
                        i: i,
                        j: j - 1,
                        token: password[i..j - 1],
                        graph: graphName,
                        turns: turns,
                        shiftedCount: shiftedCount)
                    report.guesses = estimateGuesses(report.token, password,
                            spatialGuesses(report, kbC))
                    report.guessesLog10 = log10(report.guesses)
                    matches.add(report)
                # ...and then start a new search for the rest of the password.
                i = j
                break
    return matches

proc spatialMatch*[T, U, V](password: string,
        rankedDictionaries: T, graphs: U, kbC: V): seq[Report] =
    var
        matches: seq[Report] = @[]
    for graphName, graph in graphs.pairs():
        matches &= spatialMatchHelper(password, graph, graphName, kbC)
    return matches.sortMatch()

const MAX_DELTA: int = 5

proc sequenceMatch*(password: string): seq[Report] =
    # Identifies sequences by looking for repeated differences in unicode codepoint.
    # this allows skipping, such as 9753, and also matches some extended unicode sequences
    # such as Greek and Cyrillic alphabets.
    #
    # for example, consider the input "abcdb975zy"
    #
    # password: a   b   c   d   b    9   7   5   z   y
    # index:    0   1   2   3   4    5   6   7   8   9
    # delta:      1   1   1  -2  -41  -2  -2  69   1
    #
    # expected result:
    # [(i, j, delta), ...] = [(0, 3, 1), (5, 7, -2), (8, 9, 1)]
    if password.len == 1:
        return @[]
    let
        lower {.global.} = re"^[a-z]+$"
        upper {.global.} = re"^[A-Z]+$"
        digits {.global.} = re"^\d+$"
    var
        matches: seq[Report]
        token: string
        sequenceName: string
        sequenceSpace: int
    proc update(i: int, j: int, delta: int) =
        if ((j - i) > 1) or (abs(delta) == 1):
            if 0 < abs(delta) and abs(delta) <= MAX_DELTA:
                token = password[i..j]
                if findBounds(token, lower).first != -1:
                    sequenceName = "lower"
                    sequenceSpace = 26
                elif findBounds(token, upper).first != -1:
                    sequenceName = "upper"
                    sequenceSpace = 26
                elif findBounds(token, digits).first != -1:
                    sequenceName = "digits"
                    sequenceSpace = 10
                else:
                    sequenceName = "unicode"
                    sequenceSpace = 26
                var report = Report(
                    kind: Sequence,
                    pattern: "sequence",
                    i: i,
                    j: j,
                    token: password[i..j],
                    sequenceName: sequenceName,
                    sequenceSpace: sequenceSpace,
                    ascending: delta > 0
                )
                report.guesses = estimateGuesses(report.token, password,
                        sequenceGuesses(report))
                report.guessesLog10 = log10(report.guesses)
                matches.add(report)

    var
        i = 0
        j: int
        deltaInit = false
        lastDelta: int
        delta: int

    for k in 1..<password.len:
        delta = ord(password[k]) - ord(password[k - 1])
        if deltaInit == false:
            lastDelta = delta
            deltaInit = true

        if delta == lastDelta:
            continue
        j = k - 1
        update(i, j, lastDelta)
        i = j
        lastDelta = delta
    update(i, password.len - 1, lastDelta)
    return matches

proc regexMatch*(password: string, regexen = REGEXEN): seq[Report] =
    var
        matches: seq[Report]
        pos = 0
    for name, regex in regexen.pairs():
        while true:
            let rxMatch = findBounds(password, regex, pos)
            if rxMatch.first == -1:
                break
            pos = rxMatch.last
            var report = Report(
                kind: Regexp,
                pattern: "regex",
                token: reduceToRepeatUnit(password[
                        rxMatch.first..rxMatch.last]),
                j: rxMatch.last,
                i: rxMatch.first,
                regex_name: name,
                regexMatch: password[rxMatch.first..rxMatch.last])

            report.guesses = estimateGuesses(report.token,
                                password, regex_guesses(report))
            report.guessesLog10 = log10(report.guesses)
            matches.add(report)
    return matches.sortMatch()

func mapIntsToDm(ints: seq[int]): DayMonthYear =
    for dm in zip(ints, reversed(ints)):
        if (dm[0] >= 1 and dm[0] <= 31) and (dm[1] >= 1 and dm[1] <= 12):
            return DayMonthYear(day: dm[0], month: dm[1])
    return DayMonthYear(day: 0, month: 0)

func twoToFourDigitYear(year: int): int =
    if year > 99:
        return year
    elif year > 50:
        # 87 -> 1987
        return year + 1900
    else:
        # 15 -> 2015
        return year + 2000

func mapIntsToDmy(ints: seq[int]): DayMonthYear =
    var dm = DayMonthYear()
    # given a 3-tuple, discard if:
    #   middle int is over 31 (for all dmy formats, years are never allowed in
    #   the middle)
    #   middle int is zero
    #   any int is over the max allowable year
    #   any int is over two digits but under the min allowable year
    #   2 ints are over 31, the max allowable day
    #   2 ints are zero
    #   all ints are over 12, the max allowable month
    if ints[1] > 31 or ints[1] <= 0:
        return dm
    var
        over12 = 0
        over31 = 0
        under1 = 0
    for intI in ints:
        if (99 < intI and intI < DATE_MIN_YEAR) or intI > DATE_MAX_YEAR:
            return dm
        if intI > 31:
            over_31 += 1
        if intI > 12:
            over_12 += 1
        if intI <= 0:
            under_1 += 1
    if over31 >= 2 or over12 == 3 or under1 >= 2:
        return dm

    # first look for a four digit year: yyyy + daymonth or daymonth + yyyy
    let
        possibleFourDigitSplits: seq[FourDSplit] = @[(ints[2], ints[0..1]),
                                                     (ints[0], ints[1..2])]
    for info in possibleFourDigitSplits:
        if DATE_MIN_YEAR <= info.y and info.y <= DATE_MAX_YEAR:
            dm = mapIntsToDm(info.rest)
            if dm.month != 0 or dm.day != 0:
                dm.year = info.y
                return dm
            else:
                # for a candidate that includes a four-digit year,
                # when the remaining ints don"t match to a day and month,
                # it is not a date.
                return dm

    # given no four-digit year, two digit years are the most flexible int to
    # match, so try to parse a day-month out of ints[0..1] or ints[1..0]
    for info in possibleFourDigitSplits:
        dm = mapIntsToDm(info.rest)
        if dm.month != 0 or dm.day != 0:
            dm.year = twoToFourDigitYear(info.y)
            return dm

proc dateMatch*(password: string): seq[Report] =
    # a "date" is recognized as:
    #   any 3-tuple that starts or ends with a 2- or 4-digit year,
    #   with 2 or 0 separator chars (1.1.91 or 1191),
    #   maybe zero-padded (01-01-91 vs 1-1-91),
    #   a month between 1 and 12,
    #   a day between 1 and 31.
    #
    # note: this isn"t true date parsing in that "feb 31st" is allowed,
    # this doesn"t check for leap years, etc.
    #
    # recipe:
    # start with regex to find maybe-dates, then attempt to map the integers
    # onto month-day-year to filter the maybe-dates into dates.
    # finally, remove matches that are substrings of other matches to reduce noise.
    #
    # note: instead of using a lazy or greedy regex to find many dates over the full string,
    # this uses a ^...$ regex against every substring of the password -- less performant but leads
    # to every possible date match.
    var
        matches: seq[Report]
        token: string
        candidates: seq[DayMonthYear]
        bestCandidate: DayMonthYear
        minDistance: int
        distance: int
    let
        maybeDateNoSeparator {.global.} = re"^\d{4,8}$"
        maybeDateWithSeparator {.global.} = re"^(\d{1,4})([\s/\\_.-])(\d{1,2})\2(\d{1,4})$"
        separator {.global.} = re"[\s/\\_.-]"

    # dates without separators are between length 4 "1191" and 8 "11111991"
    for i in 0..<(password.runeLen - 3):
        for j in (i + 3)..<(i + 8):
            if j > (password.runeLen - 1):
                break

            token = password[i..j]
            if findBounds(token, maybeDateNoSeparator).first == - 1:
                continue
            newSeq(candidates, 0)
            for arr in DATE_SPLITS[token.len]:
                let
                    args = @[parseInt(token[0..<(arr[0])]),
                            parseInt(token[(arr[0])..<(arr[1])]),
                            parseInt(token[(arr[1])..<token.len])]

                    dmy = mapIntsToDmy(args)
                if (dmy.year != 0 and dmy.month != 0 and dmy.day != 0):
                    candidates.add(dmy)
            if candidates.len == 0:
                continue
            # at this point: different possible dmy mappings for the same i,j
            # substring. match the candidate date that likely takes the fewest
            # guesses: a year closest to 2000. (scoring.REFERENCE_YEAR).
            #
            # ie, considering "111504", prefer 11-15-04 to 1-1-1504
            # (interpreting "04" as 2004)
            bestCandidate = candidates[0]

            func metric(candidaItem: DayMonthYear): int =
                return abs(candidaItem.year - REFERENCE_YEAR)

            minDistance = metric(candidates[0])
            for candidate in candidates[1..<candidates.len]:
                distance = metric(candidate)
                if distance < minDistance:
                    bestCandidate = candidate
                    minDistance = distance
            var report = Report(
                kind: Date,
                pattern: "date",
                token: token,
                i: i,
                j: j,
                separator: "",
                year: bestCandidate.year,
                month: bestCandidate.month,
                day: bestCandidate.day,
            )
            report.guesses = estimateGuesses(report.token, password,
                    date_guesses(report))
            report.guessesLog10 = log10(report.guesses)
            matches.add(report)

    # dates with separators are between length 6 "1/1/91" and 10 "11/11/1991"
    for i in 0..<(password.runeLen - 5):
        for j in (i + 5)..<(i + 10):
            if j > (password.runeLen - 1):
                break
            token = password[i..j]
            let rxMatch = findBounds(token, maybeDateWithSeparator)
            if rxMatch.first == -1:
                continue
            let dmy = mapIntsToDmy(split(token[rxMatch.first..rxMatch.last],
                                                    separator).mapIt(parseInt(it)))
            if dmy.year == 0 and dmy.month == 0 and dmy.day == 0:
                continue
            var report = Report(
                kind: Date,
                pattern: "date",
                token: token,
                i: i,
                j: j,
                separator: findAll(token[rxMatch.first..rxMatch.last],
                            separator).foldl(a&b),
                year: dmy.year,
                month: dmy.month,
                day: dmy.day,
            )
            report.guesses = estimateGuesses(report.token,
                            password, date_guesses(report))
            report.guessesLog10 = log10(report.guesses)
            matches.add(report)

    # matches now contains all valid date strings in a way that is tricky to
    # capture with regexes only. while thorough, it will contain some
    # unintuitive noise:
    #
    # "2015_06_04", in addition to matching 2015_06_04, will also contain
    # 5(!) other date matches: 15_06_04, 5_06_04, ..., even 2015
    # (matched as 5/1/2020)
    #
    # to reduce noise, remove date matches that are strict substrings of others
    func filterFun(match: Report): bool =
        var isSubmatch = false
        for other in 0..<matches.len:
            if match == matches[other]:
                continue
            if matches[other].i <= match.i and matches[other].j >= match.j:
                isSubmatch = true
                break
        return not isSubmatch
    return filter(matches, filterFun).sortMatch()


proc repeatMatch*[T, U, V](password: string, rankedDictionaries: T,
        graphs: U, kbC: V): seq[Report] =
    proc omniRepeatmatch[T, U, V](password: string,
     rankedDictionaries: T, graphs: U, kbC: V): seq[Report] =
        var
            matches: seq[Report] = dictionaryMatch(password, rankedDictionaries)
        matches &= reverseDictionaryMatch(password, rankedDictionaries)
        matches &= l33tMatch(password, rankedDictionaries)
        matches &= spatialMatch(password, rankedDictionaries, graphs, kbC)
        matches &= repeatMatch(password, rankedDictionaries, graphs, kbC)
        matches &= sequenceMatch(password)
        matches &= regexMatch(password)
        matches &= dateMatch(password)
        return matches

    let
        greedy {.global.} = re"(.+)\1+"
        lazy {.global.} = re"(.+?)\1+"
        lazyAnchored {.global.} = re"^(.+?)\1+$"
    var
        matches: seq[Report]
        lastIndex = 0
        i: int
        j: int
        greedyMatch: tuple[first: int, last: int]
        lazyMatch: tuple[first: int, last: int]
        baseTokenbounds: tuple[first: int, last: int]
        findresult: string
        baseToken: string
        match: array[2, int]

    while lastIndex < password.len:
        greedyMatch = findBounds(password, greedy, lastIndex)
        lazyMatch = findBounds(password, lazy, lastIndex)

        if greedyMatch.first == -1:
            break

        if (greedyMatch.last - greedyMatch.first) > (lazyMatch.last -
                lazyMatch.first):
            # greedy beats lazy for "aabaab"
            #   greedy: [aabaab, aab]
            #   lazy:   [aa,     a]
            match = [greedyMatch.first, greedyMatch.last]
            # greedy"s repeated string might itself be repeated, eg.
            # aabaab in aabaabaabaab.
            # run an anchored lazy match on greedy"s repeated string
            # to find the shortest repeated string

            findresult = password[greedyMatch.first..greedyMatch.last]
            baseTokenbounds = findBounds(findresult, lazyAnchored)
            baseToken = reduceToRepeatUnit(findresult[
                    baseTokenbounds.first..baseTokenbounds.last])
        else:
            match = [lazyMatch.first, lazyMatch.last]
            baseToken = reduceToRepeatUnit(password[match[0]..match[1]])

        i = match[0]
        j = match[1]

        # recursively match and score the base string
        let
            baseAnalysis = mostGuessableMatchSequence(baseToken,
                        omniRepeatmatch(baseToken, rankedDictionaries, graphs, kbC))
            base_matches = baseAnalysis.sequence
            baseGuesses = baseAnalysis.guesses
            repeats = len(password[i..j]) div baseToken.len
        var report = Report(
            kind: Repeat,
            pattern: "repeat",
            i: i,
            j: j,
            token: password[i..j],
            baseToken: baseToken,
            baseGuesses_repeat: baseGuesses,
            base_matches: base_matches,
            repeatCount: repeats)
        report.guesses = estimateGuesses(report.token, password,
                            repeat_guesses(baseGuesses, repeats))

        report.guessesLog10 = log10(report.guesses)
        matches.add(report)
        lastIndex = j + 1
    return matches


proc omnimatch*[T, U, V](password: string, rankedDictionaries: T,
     graphs: U, kbC: V): seq[Report] =
    var
        matches: seq[Report] = dictionaryMatch(password, rankedDictionaries)
    matches &= reverseDictionaryMatch(password, rankedDictionaries)
    matches &= l33tMatch(password, rankedDictionaries)
    matches &= spatialMatch(password, rankedDictionaries, graphs, kbC)
    matches &= repeatMatch(password, rankedDictionaries, graphs, kbC)
    matches &= sequenceMatch(password)
    matches &= regexMatch(password)
    matches &= dateMatch(password)
    return matches

