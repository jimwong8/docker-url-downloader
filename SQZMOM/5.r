//@version=5
// @author LazyBear with Enhanced Features
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
indicator(title="Enhanced Squeeze Momentum with Statistics", shorttitle="ESM_Stats", overlay=false)

// === 性能优化：缓存计算结果 ===
var float prevClose = 0.0
var float prevVal = 0.0
var float prevVolume = 0.0
var float prevEMA = 0.0
var float prevSMA = 0.0

// === 参数组设置 ===
g_basic = "基础参数"
g_adaptive = "自适应设置"
g_filter = "过滤器设置"
g_visual = "视觉效果"
g_stats = "统计信息"

// === 基础参数设置 ===
baseLength = input.int(20, title="基础周期", minval=1, group=g_basic)
baseMult = input.float(2.0, title="基础乘数", minval=0.1, group=g_basic)
signalLength = input.int(10, title="信号平滑周期", minval=1, group=g_basic)
momentumThreshold = input.float(0.5, title="动量阈值", minval=0.1, group=g_basic)

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

// === 视觉效果设置 ===
colorScheme = input.string("Default", title="颜色方案", options=["Default", "Monochrome", "Neon"], group=g_visual)
showLabels = input.bool(true, title="显示标签", group=g_visual)
showCrosses = input.bool(true, title="显示挤压标记", group=g_visual)
labelSize = input.string("Small", title="标签大小", options=["Tiny", "Small", "Normal"], group=g_visual)

// === 统计设置 ===
showStats = input.bool(true, title="显示统计信息", group=g_stats)
statsPeriod = input.int(100, title="统计周期", minval=10, group=g_stats)
profitFactor = input.float(1.5, title="盈利因子", minval=1.0, group=g_stats)

// === 颜色方案定义 ===
getColorScheme() =>
    if colorScheme == "Default"
        [color.lime, color.green, color.red, color.maroon, color.blue, color.black, color.gray]
    else if colorScheme == "Monochrome"
        [color.white, color.gray, color.silver, color.gray, color.white, color.black, color.gray]
    else
        [#00ff00, #00cc00, #ff0000, #cc0000, #0000ff, #000000, #666666]

[c_up_strong, c_up_weak, c_down_strong, c_down_weak, c_neutral, c_squeeze, c_text] = getColorScheme()

// === 自适应函数定义 ===
getTimeframeMultiplier() =>
    float tf = timeframe.in_seconds(timeframe.period) / 60  // 转换为分钟
    math.max(1.0, math.sqrt(tf / 15))  // 确保最小值为1.0

getVolatilityAdjustment() =>
    float atr = ta.atr(20)  // 使用固定周期计算ATR
    float avgAtr = ta.sma(atr, 20)
    float volatilityRatio = atr / avgAtr
    math.max(0.5, math.min(2.0, volatilityRatio))  // 限制在0.5-2.0之间

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
    float normalizedMomentum = momentum / ta.stdev(momentum, length)  // 标准化动量
    normalizedMomentum * 100  // 放大显示效果

// 计算动量值
val = getMomentumValue()
prevVal := nz(val[1], val)
scaledVal = val * math.max(1.0, math.log(math.abs(val)))  // 非线性缩放，保持方向性但增强幅度差异

// === 趋势过滤 ===
fastEMA = ta.ema(close, 20)
slowEMA = ta.ema(close, 50)
superSlowEMA = ta.ema(close, 200)
prevEMA := nz(fastEMA[1], fastEMA)

// 趋势方向 - 使用自适应判断标准
trendStrength = useAdaptive ? math.abs(fastEMA - slowEMA) / ta.atr(20) : 1.0
strongUpTrend = fastEMA > slowEMA and slowEMA > superSlowEMA and close > fastEMA and trendStrength > 0.3
strongDownTrend = fastEMA < slowEMA and slowEMA < superSlowEMA and close < fastEMA and trendStrength > 0.3

// === 成交量过滤 ===
volMA = ta.sma(volume, length)
prevSMA := nz(volMA[1], volMA)
strongVolume = volume > volMA * 1.5
volumeIncreasing = volume > prevVolume

// === 动量信号 ===
// 动态阈值计算
dynThreshold = ta.stdev(val, length) * 1.5
momentumUp = val > dynThreshold
momentumDown = val < -dynThreshold

// === 假突破过滤 ===
strongMomentum = math.abs(val) > ta.stdev(math.abs(val), signalLength) * 0.8
sustainedBreakout = ta.barssince(sqzOff) <= 5

// === 信号生成 ===
getFilteredSignal(bool baseSignal, bool trendOk, bool volOk, bool momOk) =>
    if filterMode == "All"
        baseSignal and (not trendFilter or trendOk) and (not volumeFilter or volOk) and (not momentumFilter or momOk)
    else if filterMode == "Trend"
        baseSignal and trendOk
    else if filterMode == "Volume"
        baseSignal and volOk
    else
        baseSignal and momOk

// 生成信号
longSignal = getFilteredSignal(sqzOff and momentumUp, strongUpTrend, strongVolume and volumeIncreasing, sustainedBreakout)
shortSignal = getFilteredSignal(sqzOff and momentumDown, strongDownTrend, strongVolume and volumeIncreasing, sustainedBreakout)
squeezeStartSignal = sqzOn and not sqzOn[1]
squeezeEndSignal = sqzOff and not sqzOff[1]

// === 信号统计和可靠度计算 ===
var int totalLongs = 0
var int totalShorts = 0
var int successfulLongs = 0
var int successfulShorts = 0

// 计算胜率
calcWinRate(int successes, int total) =>
    total > 0 ? float(successes) / float(total) * 100.0 : 0.0

// 计算信号可靠度
calcSignalReliability(float val, float volStrength, float trendStrength) =>
    float base = math.abs(val) / ta.stdev(math.abs(val), signalLength)
    float volFactor = volStrength > 1.5 ? 1.2 : 1.0
    float trendFactor = trendStrength > 0.7 ? 1.2 : 1.0
    math.min(100.0, base * volFactor * trendFactor)

// 预先计算信号可靠度
float currentReliability = calcSignalReliability(val, volume/volMA, trendStrength)

// 更新统计数据
if longSignal
    totalLongs := totalLongs + 1
    if close > prevClose
        successfulLongs := successfulLongs + 1

if shortSignal
    totalShorts := totalShorts + 1
    if close < prevClose
        successfulShorts := successfulShorts + 1

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

// === 统计信息显示 ===
if showStats
    var label statsLabel = na
    label.delete(statsLabel[1])
    
    longWinRate = calcWinRate(successfulLongs, totalLongs)
    shortWinRate = calcWinRate(successfulShorts, totalShorts)
    
    longText = "多头胜率: " + str.tostring(longWinRate, "#.1") + "%"
    shortText = "空头胜率: " + str.tostring(shortWinRate, "#.1") + "%"
    reliabilityText = "信号可靠度: " + str.tostring(currentReliability, "#.1") + "%"
    statsText = longText + "\n" + shortText + "\n" + reliabilityText
    
    statsLabel := label.new(bar_index, 0, text=statsText, color=color.new(color.blue, 80), style=label.style_label_left, textcolor=c_text, size=size.small)

// === 信号标签显示 ===
if showLabels
    var labelStyle = labelSize == "Tiny" ? size.tiny : labelSize == "Small" ? size.small : size.normal
    
    if longSignal and not longSignal[1]
        label.new(bar_index, 0, text="做多\n" + str.tostring(currentReliability, "#.1") + "%", color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle)
    
    if shortSignal and not shortSignal[1]
        label.new(bar_index, 0, text="做空\n" + str.tostring(currentReliability, "#.1") + "%", color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    
    if squeezeStartSignal
        label.new(bar_index, 0, text="挤压", color=c_squeeze, textcolor=color.white, size=labelStyle)
    
    if squeezeEndSignal
        label.new(bar_index, 0, text="突破", color=c_neutral, textcolor=color.yellow, size=labelStyle)

// === 警报设置 ===
alertcondition(longSignal, title="做多信号", message="强势做多信号出现")
alertcondition(shortSignal, title="做空信号", message="强势做空信号出现")
alertcondition(squeezeStartSignal, title="挤压开始", message="价格开始挤压")
alertcondition(squeezeEndSignal, title="挤压结束", message="价格突破挤压区间") 