//@version=5
// @author LazyBear with Enhanced Features
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
indicator(title="Enhanced Squeeze Momentum with Statistics", shorttitle="ESM_Stats", overlay=false)

// === 参数组设置 ===
g_basic = "基础参数"
g_adaptive = "自适应设置"
g_filter = "过滤器设置"
g_visual = "视觉效果"
g_stats = "统计信息"
g_quality = "信号质量设置"
g_profit = "盈利设置"
g_mtf = "多重时间框架"
g_keylevels = "关键价位"
g_pin_continuity = "插针连续性"
g_advanced_stats = "高级统计"

// === 视觉效果设置 ===
colorScheme = input.string("Default", title="颜色方案", options=["Default", "Monochrome", "Neon"], group=g_visual)
showLabels = input.bool(true, title="显示标签", group=g_visual)
showCrosses = input.bool(true, title="显示挤压标记", group=g_visual)
labelSize = input.string("Small", title="标签大小", options=["Tiny", "Small", "Normal"], group=g_visual)

// === 颜色方案定义 ===
getColorScheme() =>
    if colorScheme == "Default"
        [color.lime, color.green, color.red, color.maroon, color.blue, color.black, color.gray]
    else if colorScheme == "Monochrome"
        [color.white, color.gray, color.silver, color.gray, color.white, color.black, color.gray]
    else
        [#00ff00, #00cc00, #ff0000, #cc0000, #0000ff, #000000, #666666]

[c_up_strong, c_up_weak, c_down_strong, c_down_weak, c_neutral, c_squeeze, c_text] = getColorScheme()

// === 基础参数设置 ===
baseLength = input.int(20, title="基础周期", minval=1, group=g_basic)
baseMult = input.float(2.0, title="基础乘数", minval=0.1, group=g_basic)
signalLength = input.int(10, title="信号平滑周期", minval=1, group=g_basic)
momentumThreshold = input.float(0.5, title="动量阈值", minval=0.1, group=g_basic)

// === 盈利参数设置 ===
profitBars = input.int(3, title="盈利确认K线数", minval=1, maxval=10, group=g_profit)
profitThreshold = input.float(0.3, title="盈利阈值百分比", minval=0.1, maxval=5.0, group=g_profit)

// === 自适应参数设置 ===
useAdaptive = input.bool(true, title="启用自适应参数", group=g_adaptive)
volatilityWindow = input.int(100, title="波动率周期", minval=1, group=g_adaptive)
minLength = input.int(10, title="最小周期", minval=1, group=g_adaptive)
maxLength = input.int(50, title="最大周期", minval=10, group=g_adaptive)

// === 过滤器设置 ===
filterMode = input.string("All", title="过滤模式", options=["All", "Trend", "Volume", "Momentum"], group=g_filter)
trendFilter = input.bool(true, title="趋势过滤", group=g_filter)
volumeFilter = input.bool(false, title="成交量过滤", group=g_filter)
momentumFilter = input.bool(true, title="动量过滤", group=g_filter)
breakoutFilter = input.bool(false, title="假突破过滤", group=g_filter)

// === 信号质量设置 ===
qualityThreshold = input.float(50, title="信号质量阈值", minval=0, maxval=100, group=g_quality)
trendConsistencyPeriod = input.int(15, title="趋势持续性周期", minval=5, maxval=50, group=g_quality)
volumeConsistencyBars = input.int(2, title="成交量一致性K线数", minval=2, maxval=10, group=g_quality)
momentumConfirmationBars = input.int(2, title="动量确认K线数", minval=1, maxval=10, group=g_quality)

// === 统计设置增强 ===
showStats = input.bool(true, title="显示统计信息", group=g_stats)
showDetailedStats = input.bool(false, title="显示详细统计", group=g_stats)
statsPeriod = input.int(100, title="统计周期", minval=10, group=g_stats)
statsPosition = input.string("Top Right", title="统计信息位置", options=["Top Right", "Top Left", "Bottom Right", "Bottom Left"], group=g_stats)
statsTransparency = input.int(20, title="统计背景透明度", minval=0, maxval=100, group=g_stats)

// === 自适应函数定义 ===
getTimeframeMultiplier() =>
    float tf = timeframe.in_seconds(timeframe.period) / 60
    math.max(1.0, math.sqrt(tf / 15))

getVolatilityAdjustment() =>
    float atr = ta.atr(20)
    float avgAtr = ta.sma(atr, 20)
    float volatilityRatio = atr / avgAtr
    math.max(0.5, math.min(2.0, volatilityRatio))

// === 变量初始化 ===
// 缓存计算结果
var float prevClose = 0.0
var float prevVal = 0.0
var float prevVolume = 0.0
var float prevEMA = 0.0
var float prevSMA = 0.0

// 统计数据结构
var float maxConsecutiveWins = 0.0
var float maxConsecutiveLosses = 0.0
var float currentWinStreak = 0.0
var float currentLoseStreak = 0.0
var float avgProfitPct = 0.0
var float avgLossPct = 0.0
var int totalTrades = 0
var float maxDrawdown = 0.0
var float peakBalance = 100.0
var float currentDrawdown = 0.0
var int totalLongs = 0
var int totalShorts = 0
var int successfulLongs = 0
var int successfulShorts = 0
var float lastLongPrice = 0.0
var float lastShortPrice = 0.0
var int barsAfterLong = 0
var int barsAfterShort = 0

// 计算胜率函数
calcWinRate(int successes, int total) =>
    total > 0 ? float(successes) / float(total) * 100.0 : 0.0

// === 主要计算 ===
// 更新缓存值
prevClose := nz(close[1], close)
prevVolume := nz(volume[1], volume)

// 获取自适应参数
length = useAdaptive ? math.max(minLength, int(math.round(baseLength * getTimeframeMultiplier()))) : baseLength
mult = useAdaptive ? math.max(0.1, baseMult * math.sqrt(getVolatilityAdjustment())) : baseMult
lengthKC = length
multKC = mult * 0.75

// 布林带和肯特通道计算
source = close
basis = ta.sma(source, length)
dev = mult * ta.stdev(source, length)
upperBB = basis + dev
lowerBB = basis - dev

ma = ta.sma(source, lengthKC)
rangema = ta.sma(ta.tr, lengthKC)
upperKC = ma + rangema * multKC
lowerKC = ma - rangema * multKC

sqzOn = (lowerBB > lowerKC) and (upperBB < upperKC)
sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
noSqz = (sqzOn == false) and (sqzOff == false)

// === 动量计算 ===
// 改进动量计算方法
getMomentumValue() =>
    float highest = ta.highest(high, length)
    float lowest = ta.lowest(low, length)
    float avgPrice = math.avg(highest, lowest)
    float midPrice = math.avg(avgPrice, ta.sma(close, length))
    float momentum = source - midPrice
    float normalizedMomentum = momentum / ta.stdev(momentum, length)  
    normalizedMomentum * 80  // 从100改为80，减少灵敏度

// 计算动量值
val = getMomentumValue()
prevVal := nz(val[1], val)
scaledVal = val * math.max(1.0, math.log(math.abs(val)))  // 非线性缩放，保持方向性但增强幅度差异

// === 趋势过滤 ===
fastEMA = ta.ema(close, 20)
slowEMA = ta.ema(close, 50)
superSlowEMA = ta.ema(close, 200)
prevEMA := nz(fastEMA[1], fastEMA)

// === 趋势过滤增强 ===
// 趋势持续性检查
trendCrossover = ta.crossover(fastEMA, slowEMA)
trendCrossunder = ta.crossunder(fastEMA, slowEMA)
trendDuration = ta.barssince(trendCrossover)
reverseTrendDuration = ta.barssince(trendCrossunder)
bool trendConsistency = (trendDuration >= 0 and trendDuration <= trendConsistencyPeriod) or 
                       (reverseTrendDuration >= 0 and reverseTrendDuration <= trendConsistencyPeriod)

// 趋势强度评估
float trendSlope = (fastEMA - fastEMA[10]) / fastEMA[10] * 100
float slopeAcceleration = trendSlope - (trendSlope[1])
bool trendAccelerating = slopeAcceleration > 0

// 趋势方向 - 使用增强的判断标准
trendStrength = useAdaptive ? math.abs(fastEMA - slowEMA) / ta.atr(20) : 1.0
strongUpTrend = fastEMA > slowEMA and close > fastEMA and trendStrength > 0.25 and trendConsistency
strongDownTrend = fastEMA < slowEMA and close < fastEMA and trendStrength > 0.25 and trendConsistency

// === 成交量过滤 ===
volMA = ta.sma(volume, length)
prevSMA := nz(volMA[1], volMA)

// === 成交量过滤增强 ===
// 成交量一致性检查
volumeSum = math.sum(volume > volMA * 1.3 ? 1 : 0, volumeConsistencyBars)
volumeConsistency = volumeSum >= volumeConsistencyBars * 0.6

// 成交量趋势
volumeSlope = (volume - volume[3]) / volume[3] * 100
volumeTrend = ta.ema(volumeSlope, 5)
volumeTrendUp = volumeTrend > 0

// 增强的成交量条件
strongVolume = volume > volMA * 1.3 and volumeConsistency
volumeIncreasing = volume > prevVolume and volumeTrendUp

// === 动量信号增强 ===
// 动态阈值计算 - 考虑市场波动
float volatilityFactor = ta.atr(10) / ta.atr(30)
dynThreshold = ta.stdev(val, length) * 1.5 * volatilityFactor

// 动量趋势
momentumTrend = ta.ema(val, momentumConfirmationBars)
momentumAcceleration = momentumTrend - momentumTrend[3]

// 增强的动量条件
momentumUp = val > dynThreshold and momentumTrend > 0 and momentumAcceleration > 0
momentumDown = val < -dynThreshold and momentumTrend < 0 and momentumAcceleration < 0

// === 假突破过滤增强 ===
// 价格确认
priceConfirmation = close > ta.highest(high[1], 3)
priceRejection = close < ta.lowest(low[1], 3)

// 增强的突破条件
strongMomentum = math.abs(val) > ta.stdev(math.abs(val), signalLength) * 0.8
sustainedBreakout = ta.barssince(sqzOff) <= 5 and strongMomentum

// === 信号质量评分 ===
// 计算各个组成部分的得分
float trendScore = math.min(1.0, trendStrength * 2)
float volumeScore = volumeSum / float(volumeConsistencyBars)
float momentumScore = math.min(1.0, math.abs(val) / dynThreshold)

// 计算综合得分
float signalQuality = (trendScore + volumeScore + momentumScore) / 3.0 * 100

// === 信号生成增强 ===
getFilteredSignal(bool baseSignal, bool trendOk, bool volOk, bool momOk) =>
    if filterMode == "All"
        baseSignal and (not trendFilter or trendOk) and (not volumeFilter or volOk) and (not momentumFilter or momOk) and signalQuality > qualityThreshold
    else if filterMode == "Trend"
        baseSignal and trendOk and signalQuality > qualityThreshold * 0.8
    else if filterMode == "Volume"
        baseSignal and volOk and signalQuality > qualityThreshold * 0.8
    else
        baseSignal and momOk and signalQuality > qualityThreshold * 0.8

// 生成信号
longSignal = getFilteredSignal(sqzOff and momentumUp and priceConfirmation, strongUpTrend, strongVolume and volumeIncreasing, sustainedBreakout)
shortSignal = getFilteredSignal(sqzOff and momentumDown and priceRejection, strongDownTrend, strongVolume and volumeIncreasing, sustainedBreakout)
squeezeStartSignal = sqzOn and not sqzOn[1]
squeezeEndSignal = sqzOff and not sqzOff[1]

// === 统计更新逻辑 ===
if longSignal
    totalLongs := totalLongs + 1
    lastLongPrice := close
    barsAfterLong := 0

if shortSignal
    totalShorts := totalShorts + 1
    lastShortPrice := close
    barsAfterShort := 0

// 跟踪多头信号
if lastLongPrice > 0
    barsAfterLong := barsAfterLong + 1
    if barsAfterLong == profitBars
        float longProfit = (close - lastLongPrice) / lastLongPrice * 100
        bool isWin = longProfit > profitThreshold
        if isWin
            successfulLongs := successfulLongs + 1
            currentWinStreak := currentWinStreak + 1
            currentLoseStreak := 0
            maxConsecutiveWins := math.max(maxConsecutiveWins, currentWinStreak)
            avgProfitPct := (avgProfitPct * (successfulLongs + successfulShorts - 1) + longProfit) / (successfulLongs + successfulShorts)
        else
            currentLoseStreak := currentLoseStreak + 1
            currentWinStreak := 0
            maxConsecutiveLosses := math.max(maxConsecutiveLosses, currentLoseStreak)
            avgLossPct := (avgLossPct * (totalTrades - successfulLongs - successfulShorts) + longProfit) / (totalTrades - successfulLongs - successfulShorts + 1)
        
        // 更新回撤统计
        if longProfit > 0
            peakBalance := math.max(peakBalance, peakBalance * (1 + longProfit/100))
        else
            float currentBalance = peakBalance * (1 + longProfit/100)
            currentDrawdown := (peakBalance - currentBalance) / peakBalance * 100
            maxDrawdown := math.max(maxDrawdown, currentDrawdown)
        
        totalTrades := totalTrades + 1
        lastLongPrice := 0.0

// 跟踪空头信号
if lastShortPrice > 0
    barsAfterShort := barsAfterShort + 1
    if barsAfterShort == profitBars
        float shortProfit = (lastShortPrice - close) / lastShortPrice * 100
        bool isWin = shortProfit > profitThreshold
        if isWin
            successfulShorts := successfulShorts + 1
            currentWinStreak := currentWinStreak + 1
            currentLoseStreak := 0
            maxConsecutiveWins := math.max(maxConsecutiveWins, currentWinStreak)
            avgProfitPct := (avgProfitPct * (successfulLongs + successfulShorts - 1) + shortProfit) / (successfulLongs + successfulShorts)
        else
            currentLoseStreak := currentLoseStreak + 1
            currentWinStreak := 0
            maxConsecutiveLosses := math.max(maxConsecutiveLosses, currentLoseStreak)
            avgLossPct := (avgLossPct * (totalTrades - successfulLongs - successfulShorts) + shortProfit) / (totalTrades - successfulLongs - successfulShorts + 1)
        
        // 更新回撤统计
        if shortProfit > 0
            peakBalance := math.max(peakBalance, peakBalance * (1 + shortProfit/100))
        else
            float currentBalance = peakBalance * (1 + shortProfit/100)
            currentDrawdown := (peakBalance - currentBalance) / peakBalance * 100
            maxDrawdown := math.max(maxDrawdown, currentDrawdown)
        
        totalTrades := totalTrades + 1
        lastShortPrice := 0.0

// === 显示设置 ===
// 改进颜色渐变
getBarColor(float value, float prevValue) =>
    if value > 0
        value > prevValue ? color.new(c_up_strong, 0) : color.new(c_up_weak, 20)
    else
        value < prevValue ? color.new(c_down_strong, 0) : color.new(c_down_weak, 20)

bcolor = getBarColor(val, prevVal)
scolor = noSqz ? c_neutral : sqzOn ? c_squeeze : c_text

// === 绘制主图 ===
hline(0, color=color.gray, linestyle=hline.style_dotted)
plot(dynThreshold, title="Upper Threshold", color=color.new(color.green, 50), style=plot.style_line, linewidth=1)
plot(-dynThreshold, title="Lower Threshold", color=color.new(color.red, 50), style=plot.style_line, linewidth=1)
plot(series=scaledVal, title="Momentum", color=bcolor, style=plot.style_columns, linewidth=4)
plotshape(series=0, title="Squeeze", color=scolor, style=shape.cross, size=size.small, display=showCrosses ? display.all : display.none)

// === 统计信息显示优化 ===
if showStats
    var label statsLabel = na
    label.delete(statsLabel[1])
    
    // 计算统计数据
    longWinRate = calcWinRate(successfulLongs, totalLongs)
    shortWinRate = calcWinRate(successfulShorts, totalShorts)
    totalWinRate = calcWinRate(successfulLongs + successfulShorts, totalTrades)
    
    // 构建基础统计信息
    longText = "多头胜率: " + str.tostring(longWinRate, "#.1") + "%"
    shortText = "空头胜率: " + str.tostring(shortWinRate, "#.1") + "%"
    totalText = "总胜率: " + str.tostring(totalWinRate, "#.1") + "%"
    qualityText = "信号质量: " + str.tostring(signalQuality, "#.1") + "%"
    
    // 构建详细统计信息
    detailedStats = ""
    if showDetailedStats
        profitFactorText = "盈亏比: " + str.tostring(math.abs(avgProfitPct/avgLossPct), "#.2")
        maxWinsText = "最大连胜: " + str.tostring(maxConsecutiveWins, "#")
        maxLossesText = "最大连亏: " + str.tostring(maxConsecutiveLosses, "#")
        drawdownText = "最大回撤: " + str.tostring(maxDrawdown, "#.1") + "%"
        detailedStats := "\n" + profitFactorText + "\n" + maxWinsText + "\n" + maxLossesText + "\n" + drawdownText
    
    // 合并所有统计信息
    statsText = longText + "\n" + shortText + "\n" + totalText + "\n" + qualityText + detailedStats
    
    // 确定标签位置
    var int x_pos = 0
    var float y_pos = 0.0
    if statsPosition == "Top Right"
        x_pos := bar_index
        y_pos := ta.highest(high, 50)
    else if statsPosition == "Top Left"
        x_pos := bar_index - 50
        y_pos := ta.highest(high, 50)
    else if statsPosition == "Bottom Right"
        x_pos := bar_index
        y_pos := ta.lowest(low, 50)
    else
        x_pos := bar_index - 50
        y_pos := ta.lowest(low, 50)
    
    // 创建统计标签
    statsLabel := label.new(x=x_pos, y=y_pos, text=statsText, color=color.new(color.blue, statsTransparency), style=label.style_label_left, textcolor=c_text, size=size.small)

// === 信号标签显示 ===
if showLabels
    var labelStyle = labelSize == "Tiny" ? size.tiny : labelSize == "Small" ? size.small : size.normal
    
    if longSignal and not longSignal[1]
        label.new(bar_index, low, text="做多\n" + str.tostring(signalQuality, "#.1") + "%", color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle)
    
    if shortSignal and not shortSignal[1]
        label.new(bar_index, high, text="做空\n" + str.tostring(signalQuality, "#.1") + "%", color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    
    if squeezeStartSignal
        label.new(bar_index, low, text="挤压", color=c_squeeze, textcolor=color.white, size=labelStyle)
    
    if squeezeEndSignal
        label.new(bar_index, high, text="突破", color=c_neutral, textcolor=color.yellow, size=labelStyle)

// === 警报设置 ===
alertcondition(longSignal and signalQuality > qualityThreshold, title="做多信号", message="强势做多信号出现")
alertcondition(shortSignal and signalQuality > qualityThreshold, title="做空信号", message="强势做空信号出现")
alertcondition(squeezeStartSignal, title="挤压开始", message="价格开始挤压")
alertcondition(squeezeEndSignal, title="挤压结束", message="价格突破挤压区间")

// === 插针形态分析增强 ===
// 多重时间框架参数
higherTF = input.string("240", title="更高时间框架", options=["60", "120", "240", "D"], group=g_mtf)
useHigherTF = input.bool(true, title="启用多重时间框架确认", group=g_mtf)

// 关键价位参数
usePivots = input.bool(true, title="使用支撑阻力位", group=g_keylevels)
pivotPeriod = input.int(20, title="关键价位周期", minval=10, group=g_keylevels)
pivotDeviation = input.float(0.5, title="价位偏差百分比", minval=0.1, maxval=2.0, group=g_keylevels)

// 计算关键价位
getPivotLevels() =>
    float pivot = (high + low + close) / 3
    float r1 = pivot * 2 - low
    float s1 = pivot * 2 - high
    float r2 = pivot + (high - low)
    float s2 = pivot - (high - low)
    [pivot, r1, s1, r2, s2]

[pivot, r1, s1, r2, s2] = getPivotLevels()

// 检查价格是否接近关键价位
isNearKeyLevel(float price, float level) =>
    float deviation = level * pivotDeviation / 100
    math.abs(price - level) <= deviation

// 获取更高时间框架数据
htf_close = request.security(syminfo.tickerid, higherTF, close)
htf_high = request.security(syminfo.tickerid, higherTF, high)
htf_low = request.security(syminfo.tickerid, higherTF, low)
htf_volume = request.security(syminfo.tickerid, higherTF, volume)

// 增强的插针形态识别
getEnhancedPinSignal(bool isPin, float shadowSize, float bodySize, bool isLong) =>
    // 基本条件
    bool basicCondition = isPin and shadowSize > ta.atr(10) * 0.5
    
    // 多重时间框架确认
    bool htfConfirmation = true
    if useHigherTF
        float htf_range = htf_high - htf_low
        float htf_threshold = htf_range * 0.3
        htfConfirmation := isLong ? close > htf_close - htf_threshold : close < htf_close + htf_threshold
    
    // 关键价位确认
    bool keyLevelConfirmation = false
    if usePivots
        keyLevelConfirmation := isNearKeyLevel(close, pivot) or 
                               isNearKeyLevel(close, isLong ? s1 : r1) or 
                               isNearKeyLevel(close, isLong ? s2 : r2)
    
    // 成交量确认增强
    float volMA = ta.sma(volume, 20)
    bool volumeSpike = volume > volMA * 1.5 and volume > volume[1] * 1.2
    
    // 趋势确认
    bool trendConfirmation = isLong ? close < ta.sma(close, 20) : close > ta.sma(close, 20)
    
    // 计算信号强度
    float signalStrength = 0.0
    if basicCondition
        signalStrength := math.min(1.0, (shadowSize / ta.atr(10)) * 
                                       (volumeSpike ? 1.2 : 1.0) * 
                                       (keyLevelConfirmation ? 1.3 : 1.0) * 
                                       (htfConfirmation ? 1.2 : 0.8))
    
    [basicCondition and htfConfirmation and (keyLevelConfirmation or volumeSpike), signalStrength]

// 应用增强的插针信号
[upperPinSignal, upperPinStrength] = getEnhancedPinSignal(isUpperPin, upperShadow, math.abs(close - open), false)
[lowerPinSignal, lowerPinStrength] = getEnhancedPinSignal(isLowerPin, lowerShadow, math.abs(close - open), true)

// 更新信号生成逻辑
longSignal := longSignal or (lowerPinSignal and lowerPinStrength > 1.2)
shortSignal := shortSignal or (upperPinSignal and upperPinStrength > 1.2)

// 更新信号质量评分
pinScore := math.max(upperPinStrength, lowerPinStrength)
signalQuality := (trendScore + volumeScore + momentumScore + pinScore) / 4.0 * 100

// 显示插针信号
if showLabels and (upperPinSignal or lowerPinSignal)
    var labelStyle = labelSize == "Tiny" ? size.tiny : labelSize == "Small" ? size.small : size.normal
    if upperPinSignal
        label.new(bar_index, high, text="上插针\n" + str.tostring(upperPinStrength * 100, "#.1") + "%", 
                 color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    if lowerPinSignal
        label.new(bar_index, low, text="下插针\n" + str.tostring(lowerPinStrength * 100, "#.1") + "%", 
                 color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle)

// === 插针形态连续性分析 ===
pinContinuityBars = input.int(5, title="插针连续性检查周期", minval=3, maxval=10, group=g_pin_continuity)
pinContinuityThreshold = input.float(0.7, title="连续性阈值", minval=0.5, maxval=1.0, group=g_pin_continuity)

// 跟踪连续插针
var int consecutiveUpperPins = 0
var int consecutiveLowerPins = 0
var float[] upperPinPrices = array.new_float(pinContinuityBars)
var float[] lowerPinPrices = array.new_float(pinContinuityBars)

// 更新插针价格数组
updatePinPrices(float[] prices, float newPrice) =>
    array.shift(prices)
    array.push(prices, newPrice)

// 计算插针趋势强度
getPinTrendStrength(float[] prices) =>
    float sumDiff = 0.0
    float prevPrice = array.get(prices, 0)
    for i = 1 to array.size(prices) - 1
        float currentPrice = array.get(prices, i)
        sumDiff += currentPrice - prevPrice
        prevPrice := currentPrice
    sumDiff

// 增强的插针形态分析
if upperPinSignal
    consecutiveUpperPins := consecutiveUpperPins + 1
    consecutiveLowerPins := 0
    updatePinPrices(upperPinPrices, high)
else if lowerPinSignal
    consecutiveLowerPins := consecutiveLowerPins + 1
    consecutiveUpperPins := 0
    updatePinPrices(lowerPinPrices, low)
else
    consecutiveUpperPins := 0
    consecutiveLowerPins := 0

// 计算插针趋势
float upperPinTrend = getPinTrendStrength(upperPinPrices)
float lowerPinTrend = getPinTrendStrength(lowerPinPrices)

// 插针连续性确认
bool upperPinContinuity = consecutiveUpperPins >= 2 and upperPinTrend < 0
bool lowerPinContinuity = consecutiveLowerPins >= 2 and lowerPinTrend > 0

// === 统计指标增强 ===
showAdvancedStats = input.bool(false, title="显示高级统计", group=g_advanced_stats)

// 计算新的统计指标
var float avgPinStrength = 0.0
var float maxPinStrength = 0.0
var int totalPinSignals = 0
var float successfulPinRate = 0.0

// 更新插针统计
if upperPinSignal or lowerPinSignal
    float currentPinStrength = math.max(upperPinStrength, lowerPinStrength)
    avgPinStrength := (avgPinStrength * totalPinSignals + currentPinStrength) / (totalPinSignals + 1)
    maxPinStrength := math.max(maxPinStrength, currentPinStrength)
    totalPinSignals := totalPinSignals + 1

// 更新信号生成逻辑
longSignal := longSignal or (lowerPinSignal and lowerPinStrength > 1.2 and lowerPinContinuity)
shortSignal := shortSignal or (upperPinSignal and upperPinStrength > 1.2 and upperPinContinuity)

// 更新信号质量评分
float pinContinuityScore = 0.0
if upperPinSignal and upperPinContinuity
    pinContinuityScore := math.min(1.0, float(consecutiveUpperPins) / pinContinuityBars)
else if lowerPinSignal and lowerPinContinuity
    pinContinuityScore := math.min(1.0, float(consecutiveLowerPins) / pinContinuityBars)

pinScore := math.max(upperPinStrength, lowerPinStrength) * (1 + pinContinuityScore * 0.5)
signalQuality := (trendScore + volumeScore + momentumScore + pinScore) / 4.0 * 100

// 更新统计显示
if showStats and showAdvancedStats
    // 添加插针统计信息
    string pinStats = "\n=== 插针统计 ===\n" +
                     "平均强度: " + str.tostring(avgPinStrength * 100, "#.1") + "%\n" +
                     "最大强度: " + str.tostring(maxPinStrength * 100, "#.1") + "%\n" +
                     "总信号数: " + str.tostring(totalPinSignals) + "\n" +
                     "连续性得分: " + str.tostring(pinContinuityScore * 100, "#.1") + "%"
    
    statsText := statsText + pinStats

// 显示插针信号增强
if showLabels and (upperPinSignal or lowerPinSignal)
    var labelStyle = labelSize == "Tiny" ? size.tiny : labelSize == "Small" ? size.small : size.normal
    string continuityInfo = ""
    
    if upperPinSignal
        continuityInfo := upperPinContinuity ? "\n连续性: " + str.tostring(consecutiveUpperPins) : ""
        label.new(bar_index, high, 
                 text="上插针" + continuityInfo + "\n强度: " + str.tostring(upperPinStrength * 100, "#.1") + "%", 
                 color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    
    if lowerPinSignal
        continuityInfo := lowerPinContinuity ? "\n连续性: " + str.tostring(consecutiveLowerPins) : ""
        label.new(bar_index, low, 
                 text="下插针" + continuityInfo + "\n强度: " + str.tostring(lowerPinStrength * 100, "#.1") + "%", 
                 color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle) 