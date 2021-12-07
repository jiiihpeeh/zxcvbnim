import
  zxcvbnim/scoring,
  zxcvbnim/reportobjects,
  zxcvbnim/formjson,
  zxcvbnim/matching,
  times,
  jsony,
  supersnappy,
  tables,
  options
  
const
  DictCompressed = readFile("resources/DictFreq.json.snappy")
  GraphsCompressed = readFile("resources/Graph.json.snappy")
  #Snappy for export/import consistency. Minimal space savings hence deserializion.
  KeyboardConst = uncompress(readFile("resources/KeyboardConst.json.snappy")).fromJson(KbConsts)

type
  zxcvbNim* = object
    password*: string
    dictionaries*: RankedTT
    kbC*: KbConsts
    graphs*: AdjkeyTable
    estimateResult*: MGMS
    format*: reportCase
    dataDir*: string
    initialized: bool
    prettify*: bool
    getEstimates*: bool
    giveFeedback*: bool
    threshold*: float
    serialized: string
    jsonCase*: reportCase

method initData*(self: var zxcvbNim){.base.} =
  if self.initialized == false:
    #let loadedData = loadData()
    self.dictionaries = uncompress(DictCompressed).fromJson(RankedTT)
    self.graphs = uncompress(GraphsCompressed).fromJson(AdjkeyTable)
    self.kbC = KeyboardConst
    if self.threshold == 0.0:
      self.threshold = 1e20
    self.initialized = true

method estimatePassword*(self: var zxcvbNim) {.base.} =
  if self.password.len != 0:
    let startTime = epochTime()
    self.estimateResult = mostGuessableMatchSequence(self.password,
        omniMatch(self.password, self.dictionaries, self.graphs, self.kBc))
    let duration = epochTime() - startTime
    self.estimateResult.duration = duration

method formatReport*(self: var zxcvbNim) {.base.} =
  self.serialized = getSerializedResult(self.estimateResult,
                      self.password, self.prettify, self.giveFeedback,
                      self.threshold, self.getEstimates, self.jsonCase)

method getJson*(self: var zxcvbNim): string{.base.} =
  self.formatReport()
  return self.serialized

method getNumericEstimate*(self: zxcvbNim): float{.base.} =
  return self.estimateResult.guesses

method getResultData*(self: zxcvbNim): auto{.base.} =
  return self.estimateResult


var estimateObject* = zxcvbNim(
        prettify: true,
        giveFeedback: true,
        getEstimates: true,
        threshold: 1e20,
        jsonCase: Snake
  )
estimateObject.initData()

proc zxcvbnimPrettyReport*(password: string): string =
  estimateObject.password = password
  estimateObject.prettify = true
  estimateObject.estimatePassword()
  return estimateObject.getJson()

proc zxcvbnimEstimate*(password: string): float =
  estimateObject.password = password
  estimateObject.estimatePassword()
  return estimateObject.getNumericEstimate()

proc zxcvbnimFullEstimate*(password: string): auto =
  estimateObject.password = password
  estimateObject.estimatePassword()
  return estimateObject.getResultData()

proc zxcvbnimFullEstimateReport*(password: string): auto =
  estimateObject.password = password
  estimateObject.prettify = false
  estimateObject.estimatePassword()
  return (estimateObject.getResultData(), estimateObject.getJson())
