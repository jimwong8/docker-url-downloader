//@version=5
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
indicator(title="Squeeze Momentum Indicator [LazyBear] with Filtered Signals", shorttitle="SQZMOM_LB_Filtered", overlay=false)

// === 输入参数设置 ===
// 布林带参数
length = input.int(20, title="BB Length")  // 布林带计算周期，默认20
mult = input.float(2.0,title="BB MultFactor")  // 布林带标准差倍数，默认2.0

// 肯特通道参数
lengthKC = input.int(20, title="KC Length")  // 肯特通道计算周期，默认20
multKC = input.float(1.5, title="KC MultFactor")  // 肯特通道乘数，默认1.5

// 信号参数
signalLength = input.int(10, title="Signal Smoothing Length")  // 信号平滑周期
volumeThreshold = input.float(1.5, title="Volume Threshold Multiplier")  // 成交量阈值倍数
momentumThreshold = input.float(0.5, title="Momentum Threshold")  // 动量阈值

// 趋势过滤参数
fastMA = input.int(20, "快速均线周期")
slowMA = input.int(50, "慢速均线周期")
superSlowMA = input.int(200, "超慢速均线周期")

// 成交量过滤参数
volMALength = input.int(20, "成交量均线周期")
volMultiplier = input.float(2.0, "成交量倍数阈值")

// 假突破过滤参数
breakoutBars = input.int(3, "突破确认周期")
momentumConfirmation = input.float(1.0, "动量确认倍数")

// 其他设置
useTrueRange = input.bool(true, title="Use TrueRange (KC)")  // 是否使用真实波幅
showSignals = input.bool(true, title="Show Signal Labels")  // 是否显示信号标签
alertsOn = input.bool(true, title="Enable Alerts")  // 是否启用提醒

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

// 计算动量值和缩放
val = ta.linreg(source - math.avg(math.avg(ta.highest(high, lengthKC), ta.lowest(low, lengthKC)), ta.sma(close, lengthKC)), lengthKC, 0)
scaledVal = val * 100

// === 趋势过滤 ===
fastEMA = ta.ema(close, fastMA)
slowEMA = ta.ema(close, slowMA)
superSlowEMA = ta.ema(close, superSlowMA)

// 趋势方向
strongUpTrend = fastEMA > slowEMA and slowEMA > superSlowEMA and close > fastEMA
strongDownTrend = fastEMA < slowEMA and slowEMA < superSlowEMA and close < fastEMA

// === 成交量过滤 ===
volMA = ta.sma(volume, volMALength)
strongVolume = volume > volMA * volMultiplier
volumeIncreasing = ta.rising(volume, 3)  // 成交量连续3根上升

// === 假突破过滤 ===
// 动量确认
strongMomentum = math.abs(val) > ta.stdev(math.abs(val), signalLength) * momentumConfirmation
// 突破持续性确认
sustainedBreakout = ta.barssince(sqzOff) <= breakoutBars and strongMomentum

// === 信号计算 ===
// 动量信号
momentumUp = val > momentumThreshold and val > val[1]  // 上升动量信号
momentumDown = val < -momentumThreshold and val < val[1]  // 下降动量信号

// === 信号生成 ===
// 做多信号（增加过滤条件）
longSignal = sqzOff and momentumUp and strongUpTrend and strongVolume and volumeIncreasing and sustainedBreakout

// 做空信号（增加过滤条件）
shortSignal = sqzOff and momentumDown and strongDownTrend and strongVolume and volumeIncreasing and sustainedBreakout

// 挤压信号保持不变
squeezeStartSignal = sqzOn and not sqzOn[1]
squeezeEndSignal = sqzOff and not sqzOff[1]

// === 显示设置 ===
// 颜色设置
bcolor = val > 0 ? (val > nz(val[1]) ? color.lime : color.green) : (val < nz(val[1]) ? color.red : color.maroon)
scolor = noSqz ? color.blue : sqzOn ? color.black : color.gray

// 绘制主图
hline(0, color=color.gray, linestyle=hline.style_dotted)  // 添加零线
plot(series=scaledVal, title="Momentum", color=bcolor, style=plot.style_columns, linewidth=4)  // 使用放大后的值绘制柱状图
plotshape(series=0, title="Squeeze", color=scolor, style=shape.cross, size=size.small)  // 将 cross 大小改为 small

// 信号强度指示器
signalStrength = math.abs(val) / ta.stdev(math.abs(val), signalLength)
plot(signalStrength, title="Signal Strength", color=color.gray, style=plot.style_line)

// === 信号标签显示 ===
if showSignals
    // 检查前一个信号状态，避免重复标签
    bool prevLongSignal = nz(longSignal[1], false)
    bool prevShortSignal = nz(shortSignal[1], false)
    bool prevSqueezeStartSignal = nz(squeezeStartSignal[1], false)
    bool prevSqueezeEndSignal = nz(squeezeEndSignal[1], false)

    // 只在信号首次出现时显示标签
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