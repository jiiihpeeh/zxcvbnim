import
    json,
    jsony,
    tables,
    reportobjects,
    timeEstimates,
    feedback,
    times,
    strformat,
    strutils,
    math,
    unicode,
    camelsnake

var Prepared = parseJson("""{}""")

proc jsonFix(jsn: Report, jsonCase: reportCase): JsonNode{.inline.} =
    var
        jn = %jsn
        delSeq: seq[string]
        repeatMutate: bool
    for k, v in pairs(jn):
        case v.kind
        of JFloat:
            if k != "guesses_log10":
                let
                    orig_num = jn[k].getFloat()
                    number = toBiggestInt(orig_num)
                if number > 0 and abs(orig_num - float(number)) < 1e-5:
                    jn[k] = newJInt(number)
        of JObject:
            let jtbl = jn[k].getFields()
            if jtbl.len == 0:
                delSeq.add(k)
        of JString:
            let jstr = jn[k].getStr()
            if jstr.len == 0:
                delSeq.add(k)
            if k == "kind" and v == newJString("Repeat"):
                repeatMutate = true
        of JNull:
            delSeq.add(k)
        of JBool:
            discard
        of JInt:
            discard
        of JArray:
            let jarr = jn[k].getElems()
            if jarr.len == 0:
                delSeq.add(k)
    for i in delSeq:
        jn.delete(i)
    if repeatMutate:
        jn.add("base_guesses", jn["base_guesses_repeat"])
        delete(jn, "base_guesses_repeat")
    delete(jn, "kind")
    if jsonCase == Camel:
        jn = toCamel(jn)
    return jn

template feedbacker(giveFeedback: bool, Prepared: JsonNode) =
    if giveFeedback:
        let feedb = get_feedback(score = r.guesses,
            sequences = objseq, threshold = threshold, )
        Prepared.add("feedback", %(feedb))


template estimator(getEstimates: bool, Prepared: JsonNode) =
    if getEstimates:
        let estims: Estimates = estimate_attack_times(r.guesses, jsonCase)
        for k, v in estims.fieldpairs():
            Prepared.add(k, toJson(v).parseJson())


proc jsonFormatter*[T](r: T, password: string,
            giveFeedback: bool = true, threshold: float = 1e20,
            getEstimates: bool = true, jsonCase: reportCase): JsonNode{.inline.} =
    func getGuesses(): JsonNode =
        let
            number = toBiggestInt(r.guesses)
        if number > 0 and abs(r.guesses - float(number)) < 1e-5:
            return newJInt(number)
        else:
            return newJFloat(r.guesses)

    func timeCalc(): JsonNode =
        let
            s = int(r.duration)
            subs = int(round((r.duration - float(s)) * 1e8))
            hours = s div 3600
            mins = (s - hours * 3600) div 60
            secs = s - (hours * 3600 - mins * 60)
        return newJString(join([$hours, fmt"{mins:02}",
                fmt"{secs:02}"], ":") & "." & fmt"{subs:08}")

    var
        serj: seq[JsonNode]
        objseq = r.sequence.fromJson(seq[Report])
        count = 0
    for j in r.seqtypes:
        if j == "repeat" and objseq[count].baseMatches != "[]":
            let emObj = objseq[count].baseMatches.fromJson(seq[Report])
            var jarr: seq[JsonNode]
            for ij in emObj:
                jarr.add(jsonFix(ij, jsonCase))
            var jsonReport = jsonFix(objseq[count], Snake)
            jsonReport["base_matches"] = %(jarr)
            serj.add(jsonReport)
        else:
            serj.add(jsonFix(objseq[count], jsonCase))
        count.inc

    Prepared.add("password", newJString(password))
    Prepared.add("guesses", getGuesses())
    Prepared.add("guesses_log10", newJFloat(r.guesses_log10))
    Prepared.add("sequence", %(serj))
    Prepared.add("calc_time", timeCalc())
    estimator(getEstimates, Prepared)
    feedbacker(giveFeedback, Prepared)
    if jsonCase == Camel:
        Prepared = toCamel(Prepared)
    return Prepared

template prettyOrNot(output: JsonNode, prettify: bool): string =
    if prettify == true:
        pretty(output)
    else:
        toJson(output)



proc getSerializedResult*[T](r: T, password: string,
            prettify: bool = false, giveFeedback: bool = true,
            threshold: float = 1e20, getEstimates: bool = true,
                    jsonCase: reportCase): string =
    let output = jsonFormatter(r, password,
            giveFeedback, threshold, getEstimates, jsonCase)
    result = prettyOrNot(output, prettify)
