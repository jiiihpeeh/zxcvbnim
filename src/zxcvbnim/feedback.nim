
import
    json,
    tables,
    unicode,
    algorithm,
    reportobjects

proc getDictionaryMatchFeedback[T](match: T, isSoleMatch: bool): Feedback =
    var feedback = Feedback()
    if match.dictionaryName == "passwords":
        if isSoleMatch and not match.l33t and not match.reversed:
            if match.rank <= 10:
                feedback.warning = "This is a top-10 common password."
            elif match.rank <= 100:
                feedback.warning = "This is a top-100 common password."
            else:
                feedback.warning = "This is a very common password."
        elif match.guesses <= 10000:
            feedback.warning = "This is similar to a commonly used password."
    elif match.dictionaryName == "english":
        if isSoleMatch:
            feedback.warning = "A word by itself is easy to guess."
    elif @["surnames", "male_names", "female_names"].contains(
            match.dictionaryName):
        if isSoleMatch:
            feedback.warning = "Names and surnames by themselves are easy to guess."
        else:
            feedback.warning = "Common names and surnames are easy to guess."
    else:
        feedback.warning = ""

    let word = match.token
    if word.toUpper() == word:
        feedback.suggestions.add("All-uppercase is almost as easy to guess as all-lowercase.")
    elif word.toRunes()[0].isUpper():
        feedback.suggestions.add("""Capitalization doesn't help very much.""")

    if match.reversed and match.token.len >= 4:
        feedback.suggestions.add("""Reversed words aren't much harder to guess.""")
    if match.l33t:
        feedback.suggestions.add("""Predictable substitutions like "@" instead of "a" don't help very much.""")
    return feedback

proc getMatchFeedback[T](match: T, isSoleMatch: bool): Feedback =
    var feedback = Feedback()
    if match.pattern == "dictionary":
        return getDictionaryMatchFeedback(match, isSoleMatch)
    elif match.pattern == "spatial":
        if match.turns == 1:
            feedback.warning = "Straight rows of keys are easy to guess."
        else:
            feedback.warning = "Short keyboard patterns are easy to guess."
        feedback.suggestions = @["Use a longer keyboard pattern with more turns."]
        return feedback
    elif match.pattern == "repeat":
        if match.base_token.len == 1:
            feedback.warning = """Repeats like "aaa" are easy to guess."""
        else:
            feedback.warning = """Repeats like "abcabcabc" are only slightly harder to guess than "abc"."""
        feedback.suggestions = @["Use a longer keyboard pattern with more turns."]
        return feedback

    elif match.pattern == "sequence":
        feedback.warning = """Sequences like "abc" or "6543" are easy to guess."""
        feedback.suggestions = @["Avoid sequences."]
        return feedback
    elif match.pattern == "regex":
        if match.regexName == "recent_year":
            feedback.warning = "Recent years are easy to guess."
            feedback.suggestions = @["Avoid recent years.", "Avoid years that are associated with you."]
            return feedback
    elif match.pattern == "date":
        feedback.warning = "Dates are often easy to guess."
        feedback.suggestions = @["Avoid dates and years that are associated with you."]
        return feedback

proc getFeedback*[S](score: S, sequences: seq[Report],
        threshold: float = 1e7): Feedback =
    var feedback = Feedback()
    if sequences.len == 0:
        #feedback.warning = ""
        feedback.suggestions = @["Use a few words, avoid common phrases.", "No need for symbols, digits, or uppercase letters."]
        return feedback
    if score > threshold:
        #feedback.warning = ""
        feedback.suggestions = @[]
        return feedback

    let longestMatch: Report = sequences.sortedByIt(it.token)[0]
    feedback = getMatchFeedback(longestMatch, sequences.len == 1)
    let extraFeedback = "Add another word or two. Uncommon words are better."
    if feedback.suggestions.len > 0:
        feedback.suggestions.insert(extraFeedback, 0)
    else:
        feedback.suggestions = @[extraFeedback]
    return feedback
