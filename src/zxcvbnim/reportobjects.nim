import
    tables,
    options
type
    match_method* = enum
        Dictionary, Date, Sequence, Regexp,
         Repeat, Spatial, Bruteforce
    reportCase* = enum
        Snake, Camel
    Report* = ref object
        pattern*, token*: string
        i*, j*: int
        guesses*: float
        guesses_log10*: float
        case kind*: match_method
        of Dictionary:
            matched_word*, dictionary_name*: string
            rank*: int
            reversed*, l33t*: bool
            sub*: Table[string, string]
            sub_display*: string
            base_guesses*: int
            uppercase_variations*: float
            l33t_variations*: float
        of Date:
            separator*: string
            year*, month*, day*: int
        of Sequence:
            sequence_name*: string
            ascending*: bool
            sequence_space*: int
        of Regexp:
            regex_name*: string
            regex_match*: string
        of Repeat:
            base_guesses_repeat*: float
            base_token*: string
            base_matches*: string
            repeat_count*: int
        of Spatial:
            graph*: string
            turns*, shifted_count*: int
        of Bruteforce:
            discard

    DayMonthYear* = object
        day*, month*, year*: int

    MGMS* = object
        password*: string
        guesses*: float
        guessesLog10*: float
        sequence*: string
        seqtypes*: seq[string]
        duration*: float

    Feedback* = object
        warning*: string
        suggestions*: seq[string]

    Estimates* = object
        crack_times_seconds*: OrderedTable[string, float]
        crack_times_display*: OrderedTable[string, string]
        score*: int


    LTT* = Table[string, seq[string]]
    SubSubType* = seq[array[2, string]]
    SubType* = seq[SubSubType]
    AssocType* = seq[array[2, string]]
    ELST* = seq[Table[string, string]]
    FourDSplit* = tuple[y: int, rest: seq[int]]
    FreqKeyTable* = OrderedTable[string, seq[string]]
    RankedTT* = OrderedTable[string, OrderedTable[string, int]]
    AdjSubkeyTable* = OrderedTable[string, seq[Option[string]]]
    AdjkeyTable* = OrderedTable[string, OrderedTable[string, seq[Option[string]]]]
    KbConsts* = tuple[KEYBOARD_AVERAGE_DEGREE: float,
                    KEYPAD_AVERAGE_DEGREE: float,
                    KEYBOARD_STARTING_POSITIONS: int,
                    KEYPAD_STARTING_POSITIONS: int]
