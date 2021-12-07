import
    tables,
    math,
    options,
    strutils,
    reportobjects,
    camelsnake,
    sequtils

func guessesToScore(guesses: float): int =
    let delta = 5.0

    if guesses < 1e3 + delta:
        # risky password: "too guessable"
        return 0
    elif guesses < 1e6 + delta:
        # modest protection from throttled online attacks: "very guessable"
        return 1
    elif guesses < 1e8 + delta:
        # modest protection from unthrottled online attacks: "somewhat
        # guessable"
        return 2
    elif guesses < 1e10 + delta:
        # modest protection from offline attacks: "safely unguessable"
        # assuming a salted, slow hash function like bcrypt, scrypt, PBKDF2,
        # argon, etc
        return 3
    else:
        # strong protection from offline attacks under same scenario: "very
        # unguessable"
        return 4


func displayTime(seconds: float): string =
    var
        base: int
        displayStr: string
        displayNum: Option[int]
    let
        minute: float = 60
        hour = minute * 60
        day = hour * 24
        month = day * 31
        year = month * 12
        century = year * 100
    if seconds < 1:
        displayNum = none(int)
        displayStr = "less than a second"
    elif seconds < minute:
        base = int(round(seconds))
        displayNum = some(base)
        displayStr = "$1 second" % [$base]
    elif seconds < hour:
        base = int(round(seconds / minute))
        displayNum = some(base)
        displayStr = "$1 minute" % [$base]
    elif seconds < day:
        base = int(round(seconds / hour))
        displayNum = some(base)
        displayStr = "$1 hour" % [$base]
    elif seconds < month:
        base = int(round(seconds / day))
        displayNum = some(base)
        displayStr = "$1 day" % [$base]
    elif seconds < year:
        base = int(round(seconds / month))
        displayNum = some(base)
        displayStr = "$1 month" % [$base]
    elif seconds < century:
        base = int(round(seconds / year))
        displayNum = some(base)
        displayStr = "$1 year" % [$base]
    else:
        displayNum = none(int)
        displayStr = "centuries"

    if displayNum.isSome() and displayNum.get != 1:
        displayStr &= "s"

    return displayStr


proc estimate_attack_times*(guesses: float, jsonCase: reportCase): Estimates =
    var
        crackTimesSeconds: OrderedTable[string, float]
        crackKeys = @[
            "online_throttling_100_per_hour",
            "online_no_throttling_10_per_second",
            "offline_slow_hashing_1e4_per_second",
            "offline_fast_hashing_1e10_per_second"]
    let crackValues = [guesses * 36.0, guesses/10.0,
                        guesses/1e4, guesses/1e10]
    if jsonCase == Camel:
        crackKeys = crackKeys.mapIt(it.snakeToCamel())
    for kv in zip(crackKeys, crackValues):
        let (key, value) = kv
        crackTimesSeconds[key] = value

    var crackTimesDisplay = initOrderedTable[string, string]()
    for scenario, seconds in crackTimesSeconds.pairs():
        crackTimesDisplay[scenario] = displayTime(seconds)

    let
        estimates = Estimates(crackTimesSeconds: crackTimesSeconds,
        crackTimesDisplay: crackTimesDisplay,
        score: guessesToScore(guesses))
    return estimates
