import
    #nimpcre,
    tables,
    math,
    re,
    unicode,
    typetraits,
    strutils,
    options,
    algorithm,
    jsony,
    sets,
    macros,
    reportobjects


const
    BRUTEFORCE_CARDINALITY* = 10
    MIN_GUESSES_BEFORE_GROWING_SEQUENCE * = 10000
    MIN_SUBMATCH_GUESSES_SINGLE_CHAR* = 10
    MIN_SUBMATCH_GUESSES_MULTI_CHAR* = 50
    MIN_YEAR_SPACE* = 20
    REFERENCE_YEAR* = 2017


func fact(n: int): float{.inline.} =
    if n > 20:
        var res: float = 1
        for i in 1..n:
            res *= float(i)
        return res
    else:
        return float(fac(n))

func nCk*(n: int, k: int): float{.inline.} =
    #n!/(k!(n-k)!)
    #"""http://blog.plover.com/math/choose.html"""
    if k > n:
        return 0'f
    if k == 0:
        return 1'f
    var
        nn = float(n)
        r: float = 1
        count = 1.0
        kk = float(k) + 1.0
    while count < kk:
        r *= nn
        r /= count
        nn -= 1
        count += 1.0
    return r

func estimateGuesses*(token: string,
password: string, guesses: float): float =
    var minGuesses: float
    minGuesses = 1
    if token.runelen < password.runeLen:
        case token.runeLen
        of 1:
            minGuesses = float(MIN_SUBMATCH_GUESSES_SINGLE_CHAR)
        else:
            minGuesses = float(MIN_SUBMATCH_GUESSES_MULTI_CHAR)
    return max(guesses, minGuesses)

template guessUnicode(token: string, uniWeight: float): float =
    if uniWeight == 0.0:
        float(token.runeLen)
    else:
        float(token.runeLen) + float(token.len - token.runeLen) * uniWeight


proc bruteForceGuesses*[T](token: T, uniWeight: float = 0): float =
    var
        guesses = pow(float(BRUTEFORCE_CARDINALITY), guessUnicode(token, uniWeight))
        #guesses = pow(float(BRUTEFORCE_CARDINALITY) , float(token.runeLen) )
        minGuesses: float
    # small detail: make bruteforce matches at minimum one guess bigger than
    # smallest allowed submatch guesses, such that non-bruteforce submatches
    # over the same [i..j] take precedence.
    case token.runeLen
    of 1:
        minGuesses = float(MIN_SUBMATCH_GUESSES_SINGLE_CHAR + 1)
    else:
        minGuesses = float(MIN_SUBMATCH_GUESSES_MULTI_CHAR + 1)
    return max(guesses, minGuesses)


# ------------------------------------------------------------------------------
# search --- most guessable match sequence -------------------------------------
# ------------------------------------------------------------------------------
#
# takes a sequence of overlapping matches, returns the non-overlapping sequence with
# minimum guesses. the following is a O(l_max * (n + m)) dynamic programming algorithm
# for a length-n password with m candidate matches. l_max is the maximum optimal
# sequence length spanning each prefix of the password. In practice it rarely exceeds 5 and the
# search terminates rapidly.
#
# the optimal "minimum guesses" sequence is here defined to be the sequence that
# minimizes the following function:
#
#    g = l! * Product(m.guesses for m in sequence) + D^(l - 1)
#
# where l is the length of the sequence.
#
# the factorial term is the number of ways to order l patterns.
#
# the D^(l-1) term is another length penalty, roughly capturing the idea that an
# attacker will try lower-length sequences first before trying length-l sequences.
#
# for example, consider a sequence that is date-repeat-dictionary.
#  - an attacker would need to try other date-repeat-dictionary combinations,
#    hence the product term.
#  - an attacker would need to try repeat-date-dictionary, dictionary-repeat-date,
#    ..., hence the factorial term.
#  - an attacker would also likely try length-1 (dictionary) and length-2 (dictionary-date)
#    sequences before length-3. assuming at minimum D guesses per pattern type,
#    D^(l-1) approximates Sum(D^i for i in [1..l-1]
#
# ------------------------------------------------------------------------------
#Parameter uniWeight: extra weight for only unicode characters. Use somewhere between 0 and 1.
#Defaults to 0. Eg. 0.5 gives 1.5 characters for Ä or Ö etc instead of 1.
proc mostGuessableMatchSequence*(password: string, matches: seq[Report],
    excludeAdditive = false, uniWeight: float = 0.0): MGMS =
    var
        n = password.len
    type
        matchData = tuple[i: int, j: int, token: string, pattern: string,
                guesses: float, idx: int]
        floatTable = Table[int, float]
        seqOptitableGpi = seq[floatTable]
        matchTable = Table[int, matchData]
        seqOptitableM = seq[matchTable]
        opti = tuple[m: seqOptitableM, g: seqOptitableGpi, pi: seqOptitableGpi]
    # partition matches into sublists according to ending index j

    var
        guesses: float
        matchesByJ = initTable[int, seq[matchData]]()
        matchSeq: seq[matchData] = @[]
        mSeq: seqOptitableM
        piSeq: seqOptitableGpi
        gSeq: seqOptitableGpi
        bruteSeq: seq[Report] = @[]
        seqTypes: seq[string]
    newSeq(mSeq, n)
    newSeq(piSeq, n)
    newSeq(gSeq, n)
    var
        optimal: opti = (m: mSeq, g: gSeq, pi: piSeq)
    var
        iidx: int = 0
    for sm in matches:
        let up: matchData = (sm.i, sm.j, sm.token, sm.pattern, sm.guesses, iidx)
        matchSeq.add(up)
        iidx.inc

    # small detail: for deterministic output, sort each sublist by i.
    matchSeq = matchSeq.sortedByIt(it.i)
    for ms in matchSeq:
        if not matchesByJ.hasKey(ms.j):
            matchesByJ[ms.j] = @[]
        matchesByJ[ms.j].add(ms)
        #This is the Python construct for type opti|mal
        #[optimal = {
        # optimal.m[k][l] holds final match in the best length-l match sequence
        # covering the password prefix up to k, inclusive.
        # if there is no length-l sequence that scores better (fewer guesses)
        # than a shorter match sequence spanning the same prefix,
        # optimal.m[k][l] is undefined.
        "m": [{} for _ in range(n)],

        # same structure as optimal.m -- holds the product term Prod(m.guesses
        # for m in sequence). optimal.pi allows for fast (non-looping) updates
        # to the minimization function.
        "pi": [{} for _ in range(n)],

        # same structure as optimal.m -- holds the overall metric.
        "g": [{} for _ in range(n)],
    } ]#
    # helper: considers whether a length-l sequence ending at match m is better
    # (fewer guesses) than previously encountered sequences, updating state if
    # so.
    func makeBruteForceMatch(i: int, j: int): matchData =
        var sm = Report(
            pattern: "bruteforce",
            token: password[i..j],
            i: i,
            j: j,
            kind: Bruteforce
        )
        sm.guesses = estimateGuesses(sm.token, password, bruteForceGuesses(
                sm.token, uniWeight))
        sm.guessesLog10 = log10(sm.guesses)
        bruteSeq.add(sm)
        return (sm.i, sm.j, sm.token, sm.pattern, sm.guesses, matches.len +
                bruteSeq.len - 1)
    func update(m: matchData, l: int) =
        var
            k = float(m.j)
            pi = m.guesses #estimateGuesses(m, password)
        if l > 1:
            # we"re considering a length-l sequence ending with match m:
            # obtain the product term in the minimization function by
            # multiplying m"s guesses by the product of the length-(l-1)
            # sequence ending just before m, at m.i - 1.
            pi = pi * float(optimal.pi[m.i - 1][l - 1])
        # calculate the minimization func
        var
            #g = float(fac(l)) * pi
            g = fact(l) * pi
        if not excludeAdditive:
            g += pow(float(MIN_GUESSES_BEFORE_GROWING_SEQUENCE), float(l - 1))

        # update state if new best.
        # first see if any competing sequences covering this prefix, with l or
        # fewer matches, fare better than this sequence. if so, skip it and
        # return.
        let optig = optimal.g[int(k)]
        for competingI, competingS in optig.pairs():
            if competingI < l:
                continue
            if competingS <= g:
                return

        # this sequence might be part of the final optimal sequence.
        let
            ki = int(k)
            li = int(l)
        optimal.g[ki][li] = g
        optimal.m[ki][li] = m
        optimal.pi[ki][li] = pi

    # helper: evaluate bruteforce matches ending at k.
    proc bruteForceUpdate(k: int) =
        # see if a single bruteforce match spanning the k-prefix is optimal.
        var m = makeBruteForceMatch(0, k)
        update(m, 1)
        for i in 1..k:
            # generate k bruteforce matches, spanning from (i=1, j=k) up to
            # (i=k, j=k). see if adding these new matches    to any of the
            # sequences in optimal[i-1] leads to new bests.
            m = makeBruteForceMatch(i, k)
            let optiM = optimal.m[i - 1]
            for l, lastM in optiM.pairs():
                # corner: an optimal sequence will never have two adjacent
                # bruteforce matches. it is strictly better to have a single
                # bruteforce match spanning the same region: same contribution
                # to the guess product with a lower length.
                # --> safe to skip those cases.
                if lastM.pattern == "bruteforce":
                    continue

                # try adding m to this length-l sequence.
                update(m, l + 1)

    # helper: make bruteforce match objects spanning i to j, inclusive.


    # helper: step backwards through optimal.m starting at the end,
    # constructing the final optimal match sequence.
    proc unwind(n: int): seq[int] =
        var
            optimalMatchSequence: seq[int]
            k = n - 1
            # find the final best sequence length and score
            l = 0
            g = Inf
            m: matchData

        newSeq(optimalMatchSequence, 0)
        for candidateL, candidateG in optimal.g[k].pairs():
            if candidateG < g:
                l = candidateL
                g = candidateG

        while k >= 0:
            m = optimal.m[k][l]
            optimalMatchSequence.insert(m.idx, 0)
            k = m.i - 1
            l -= 1
        return optimalMatchSequence

    proc collectReports(seqInts: seq[int]): string =
        var sequenceOut: seq[Report] = @[]
        for i in seqInts:
            if i >= matches.len:
                sequenceOut.add(bruteSeq[i - matches.len])
                seqTypes.add("bruteforce")
            else:
                try:
                    sequenceOut.add(matches[i])
                    seqTypes.add(matches[i].pattern)

                except:
                    discard
        return sequenceOut.toJson()

    for k in 0..<n:
        if matchesByJ.hasKey(k):
            for m in matchesByJ[k]:
                if m.i > 0:
                    let optm = optimal.m[m.i - 1]
                    for l in optm.keys():
                        update(m, l + 1)
                else:
                    update(m, 1)
        bruteForceUpdate(k)

    let
        optimalMatchSequence = unwind(n)
        optL = optimalMatchSequence.len

    if password.len == 0:
        guesses = 1
    else:
        guesses = optimal.g[n - 1][optL]

    let mps = MGMS(password: password, guesses: guesses,
    guessesLog10: log10(guesses).float(),
    sequence: collectReports(optimalMatchSequence),
    seqTypes: seqTypes)
    return mps

#report.baseGuesses, report.repeatCount
func repeatGuesses*[T, U](baseGuesses: T, repeatCount: U): float {.inline.} =
    #try:
    return float(baseGuesses) * float(repeatCount)
#[     except FieldDefect:
    #should not happen but complains at runtime
    return 1.0 ]#

proc sequenceGuesses*[T](match: T): float {.inline.} =
    let
        firstChr = match.token[0..0]
        redgt {.global.} = re"[0-9]"
    var
        baseGuesses: int
    # lower guesses for obvious starting points
    if @["a", "A", "z", "Z", "0", "1", "9"].contains(firstChr):
        baseGuesses = 4
    else:
        if findBounds(firstChr, redgt).first != -1:
            baseGuesses = 10 # digits
        else:
            # could give a higher base for uppercase,
            # assigning 26 to both upper and lower sequences is more
            # conservative.
            baseGuesses = 26
    if match.ascending == false:
        baseGuesses *= 2
    return float(baseGuesses * match.token.len)

func regexGuesses*[T](match: T): float =
    let charClassBases = {
        "alpha_lower": 26,
        "alpha_upper": 26,
        "alpha": 52,
        "alphanumeric": 62,
        "digits": 10,
        "symbols": 33,
    }.toTable
    var
        yearSpace: int
    #return 5
    let regexname = match.regexName
    if charClassBases.hasKey(regexname):
        return pow(float(charClassBases[match.regexName]), float(
                match.token.runeLen))
    elif match.regexName == "recent_year":
        # conservative estimate of year space: num years from REFERENCE_YEAR.
        # if year is close to REFERENCE_YEAR, estimate a year space of
        # MIN_YEAR_SPACE.
        yearSpace = abs(parseInt(match.regexMatch) - REFERENCE_YEAR)
        yearSpace = max(yearSpace, MIN_YEAR_SPACE)
        return float(yearSpace)

func dateGuesses*[T](match: T): float{.inline.} =
    let
        yearSpace = max(abs(match.year - REFERENCE_YEAR), MIN_YEAR_SPACE)
    var
        guesses = yearSpace * 365
    if match.separator.len > 0:
        guesses *= 4
    return float(guesses)



proc spatialGuesses*[T, U](match: T, kbC: U): float =
    var
        s: float
        d: float
        guesses: float
        S: int
        U: int
        possibleTurns: int


    if @["qwerty", "dvorak"].contains(match.graph):
        s = float(kbC.KEYBOARD_STARTING_POSITIONS)
        d = kbC.KEYBOARD_AVERAGE_DEGREE
    else:
        s = float(kbC.KEYPAD_STARTING_POSITIONS)
        d = kbC.KEYPAD_AVERAGE_DEGREE
    guesses = 0
    let
        L = match.token.runeLen
        t = match.turns
    # estimate the number of possible patterns w/ length L or less with t turns
    # or less.
    for i in 2..L:
        possibleTurns = min(t, i - 1) + 1
        for j in 1..<possibleTurns:
            guesses += nCk(i - 1, j - 1) * s * pow(d, float(j))
    # add extra guesses for shifted keys. (% instead of 5, A instead of a.)
    # math is similar to extra guesses of l33t substitutions in dictionary
    # matches.
    if match.shiftedCount > 0:
        S = match.shiftedCount
        U = len(match.token) - match.shiftedCount # unshifted count
        if S == 0 or U == 0:
            guesses *= 2
        else:
            var shiftedVariations: float = 0
            for i in 1..min(S, U):
                shiftedVariations += nCk(S + U, i)
            guesses *= shiftedVariations
    return guesses

let
    START_UPPER = re"^[A-Z][^A-Z]+$"
    END_UPPER = re"^[^A-Z]+[A-Z]$"
    ALL_UPPER = re"^[^a-z]+$"
    ALL_LOWER = re"^[^A-Z]+$"

func casesUpperLower(s: string): tuple[u: int, l: int]{.inline.} =
    var
        u = 0
        l = 0
    for i in runes(s):
        if i.isLower():
            l.inc
        elif i.isUpper():
            u.inc
    return (u, l)

func testNrLetters[T, U](s: T, test: U): int{.inline.} =
    var a = 0
    for i in runes(s):
        if $i == $test:
            a += 1
    return a

proc upperCaseVariations*[T](match: T): float{.inline.} =
    let
        word = match.token
    if (findBounds(word, ALL_LOWER) != (-1, 0)) or word.toLower() == word:
        return 1'f
    for regex in @[START_UPPER, END_UPPER, ALL_UPPER]:
        if findBounds(word, regex) != (-1, 0):
            return 2'f
    let
        (U, L) = word.casesUpperLower()
    var
        variations: float = 0
    for i in 1..min(U, L):
        variations += nCk(U + L, i)
    return variations

proc l33tVariations*[T, U](match: T, subtable: U): float {.inline.} =
    #if not match.hasKey("l33t"):
    #    return 1
    var
        variations: float = 1

    for subbed, unsubbed in (subtable).pairs():
        let
            chrs = match.token.toLower()
            S = testNrLetters(chrs, subbed)
            U = testNrLetters(chrs, unsubbed)
        if S == 0 or U == 0:
            # for this sub, password is either fully subbed (444) or fully
            # unsubbed (aaa) treat that as doubling the space (attacker needs
            # to try fully subbed chars in addition to unsubbed.)
            variations *= 2
        else:
            # this case is similar to capitalization:
            # with aa44a, U = 3, S = 2, attacker needs to try unsubbed + one
            # sub + two subs
            let p = min(U, S)
            var possibilities = 0'f
            for i in 1..p:
                possibilities += nCk(U + S, i)
            variations *= possibilities
    return variations

proc dictionaryGuesses*[T](match: T): float{.inline.} =
    # keep these as properties for display purposes
    var
        reversedVariations: float
    case match.reversed
    of true:
        reversedVariations = 2
    else:
        reversedVariations = 1
    if match.l33tVariations < 1: match.l33tVariations = 1
    let
        baseGuesses = match.rank
        upperCaseVariations = match.upperCaseVariations #(match)
        l33tVariations = match.l33tVariations           #(match)
        guessCount = float(baseGuesses) * upperCaseVariations * l33tVariations * reversedVariations
    return guessCount
