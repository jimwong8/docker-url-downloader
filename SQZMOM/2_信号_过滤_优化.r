//@version=5
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
indicator(title="Squeeze Momentum Indicator [LazyBear] with Adaptive Filters", shorttitle="SQZMOM_LB_Adaptive", overlay=false)

// === 基础参数设置 ===
// 布林带基础参数
baseLength = input.int(20, title="Base Length", minval=1)  // 添加最小值限制
baseMult = input.float(2.0, title="Base MultFactor", minval=0.1)  // 添加最小值限制

// 自适应参数设置
useAdaptive = input.bool(true, title="使用自适应参数")
volatilityWindow = input.int(100, title="波动率计算周期", minval=1)
atrMultiplier = input.float(1.5, title="ATR调整系数", minval=0.1)
minLength = input.int(10, title="最小周期", minval=1)
maxLength = input.int(50, title="最大周期", minval=10)

// === 自适应函数定义 ===
getTimeframeMultiplier() =>
    tf = timeframe.in_seconds(timeframe.period) / 60  // 转换为分钟
    math.max(1.0, math.sqrt(tf / 15))  // 确保最小值为1.0

getVolatilityAdjustment() =>
    float atr = ta.atr(20)  // 使用固定周期计算ATR
    float avgAtr = ta.sma(atr, 20)
    float volatilityRatio = atr / avgAtr
    math.max(0.5, math.min(2.0, volatilityRatio))  // 限制在0.5-2.0之间

// 计算自适应参数
calcAdaptiveParams() =>
    tfMult = getTimeframeMultiplier()
    volAdj = getVolatilityAdjustment()
    
    // 调整计算周期
    adaptiveLength = math.round(baseLength * tfMult * volAdj)
    adaptiveLength := math.max(minLength, math.min(maxLength, adaptiveLength))
    
    // 调整乘数
    adaptiveMult = baseMult * math.sqrt(volAdj)
    adaptiveMult := math.max(0.1, adaptiveMult)  // 确保乘数大于0
    
    [adaptiveLength, adaptiveMult]

// 获取最终使用的参数
length = useAdaptive ? math.max(minLength, int(math.round(baseLength * getTimeframeMultiplier()))) : baseLength
mult = useAdaptive ? math.max(0.1, baseMult * math.sqrt(getVolatilityAdjustment())) : baseMult
lengthKC = length
multKC = mult * 0.75

// 其他参数设置保持不变
signalLength = input.int(10, title="Signal Smoothing Length")
volumeThreshold = input.float(1.5, title="Volume Threshold Multiplier")
momentumThreshold = input.float(0.5, title="Momentum Threshold")

// 趋势过滤参数 - 自适应
fastLength = useAdaptive ? int(20 * math.sqrt(timeframe.in_seconds(timeframe.period) / 900)) : 20
slowLength = useAdaptive ? int(50 * math.sqrt(timeframe.in_seconds(timeframe.period) / 900)) : 50
superSlowLength = useAdaptive ? int(200 * math.sqrt(timeframe.in_seconds(timeframe.period) / 900)) : 200

// === 趋势过滤 ===
fastEMA = ta.ema(close, 20)
slowEMA = ta.ema(close, 50)
superSlowEMA = ta.ema(close, 200)

// 趋势方向 - 使用自适应判断标准
trendStrength = useAdaptive ? math.abs(fastEMA - slowEMA) / ta.atr(20) : 1.0  // 使用固定周期的ATR
strongUpTrend = fastEMA > slowEMA and slowEMA > superSlowEMA and close > fastEMA and trendStrength > 0.5
strongDownTrend = fastEMA < slowEMA and slowEMA < superSlowEMA and close < fastEMA and trendStrength > 0.5

// 成交量过滤参数
volMALength = length  // 使用自适应周期
volMultiplier = input.float(2.0, title="Volume Multiplier")

// 假突破过滤参数
breakoutBars = input.int(3, title="Breakout Confirmation Bars")
momentumConfirmation = input.float(1.0, title="Momentum Confirmation Factor")

// 其他设置
useTrueRange = input.bool(true, title="Use TrueRange (KC)")
showSignals = input.bool(true, title="Show Signal Labels")
alertsOn = input.bool(true, title="Enable Alerts")

// === 函数定义 ===
calcBollingerBands(float src, int len, float mult) =>
    basis = ta.sma(src, len)
    dev = mult * ta.stdev(src, len)
    [basis, basis + dev, basis - dev]

calcKeltnerChannel(float src, int len, float mult, bool useTR) =>
    ma = ta.sma(src, len)
    priceRange = useTR ? ta.tr : (high - low)
    rangeMA = ta.sma(priceRange, len)
    [ma, ma + rangeMA * mult, ma - rangeMA * mult]

calcSqueezeState(float lowerBB, float upperBB, float lowerKC, float upperKC) =>
    sqzOn = (lowerBB > lowerKC) and (upperBB < upperKC)
    sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
    noSqz = (sqzOn == false) and (sqzOff == false)
    [sqzOn, sqzOff, noSqz]

// === 主要计算 ===
source = close
[basis, upperBB, lowerBB] = calcBollingerBands(source, length, mult)
[ma, upperKC, lowerKC] = calcKeltnerChannel(source, lengthKC, multKC, useTrueRange)
[sqzOn, sqzOff, noSqz] = calcSqueezeState(lowerBB, upperBB, lowerKC, upperKC)

// 计算动量值和缩放 - 使用自适应周期
val = ta.linreg(source - math.avg(math.avg(ta.highest(high, length), ta.lowest(low, length)), ta.sma(close, length)), length, 0)
scaledVal = val * 100

// === 成交量过滤 ===
volMA = ta.sma(volume, volMALength)
strongVolume = volume > volMA * volMultiplier
volumeIncreasing = ta.rising(volume, 3)

// === 假突破过滤 ===
strongMomentum = math.abs(val) > ta.stdev(math.abs(val), signalLength) * momentumConfirmation
sustainedBreakout = ta.barssince(sqzOff) <= breakoutBars and strongMomentum

// === 信号计算 ===
momentumUp = val > momentumThreshold and val > val[1]
momentumDown = val < -momentumThreshold and val < val[1]

// === 信号生成 ===
longSignal = sqzOff and momentumUp and strongUpTrend and strongVolume and volumeIncreasing and sustainedBreakout
shortSignal = sqzOff and momentumDown and strongDownTrend and strongVolume and volumeIncreasing and sustainedBreakout
squeezeStartSignal = sqzOn and not sqzOn[1]
squeezeEndSignal = sqzOff and not sqzOff[1]

// === 显示设置 ===
bcolor = val > 0 ? (val > nz(val[1]) ? color.lime : color.green) : (val < nz(val[1]) ? color.red : color.maroon)
scolor = noSqz ? color.blue : sqzOn ? color.black : color.gray

// 绘制主图
hline(0, color=color.gray, linestyle=hline.style_dotted)
plot(series=scaledVal, title="Momentum", color=bcolor, style=plot.style_columns, linewidth=4)
plotshape(series=0, title="Squeeze", color=scolor, style=shape.cross, size=size.small)

// 信号强度指示器
signalStrength = math.abs(val) / ta.stdev(math.abs(val), signalLength)
plot(signalStrength, title="Signal Strength", color=color.gray, style=plot.style_line)

// === 信号标签显示 ===
if showSignals
    bool prevLongSignal = nz(longSignal[1], false)
    bool prevShortSignal = nz(shortSignal[1], false)
    bool prevSqueezeStartSignal = nz(squeezeStartSignal[1], false)
    bool prevSqueezeEndSignal = nz(squeezeEndSignal[1], false)

    if longSignal and not prevLongSignal
        label.new(bar_index, 0, text="做多", color=color.green, style=label.style_label_up, textcolor=color.white, size=size.small)
    if shortSignal and not prevShortSignal
        label.new(bar_index, 0, text="做空", color=color.red, style=label.style_label_down, textcolor=color.white, size=size.small)
    if squeezeStartSignal and not prevSqueezeStartSignal
        label.new(bar_index, 0, text="挤压", color=color.yellow, textcolor=color.black, size=size.small)
    if squeezeEndSignal and not prevSqueezeEndSignal
        label.new(bar_index, 0, text="突破", color=color.white, textcolor=color.black, size=size.small)

// === 警报设置 ===
if alertsOn
    if longSignal
        alert("强势做多信号: 挤压突破+趋势确认+量能确认", freq=alert.freq_once_per_bar)
    if shortSignal
        alert("强势做空信号: 挤压突破+趋势确认+量能确认", freq=alert.freq_once_per_bar)
    if squeezeStartSignal
        alert("挤压开始: 波动率收缩", freq=alert.freq_once_per_bar)
    if squeezeEndSignal
        alert("挤压结束: 可能出现大幅度行情", freq=alert.freq_once_per_bar) 