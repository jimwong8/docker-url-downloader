//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study(shorttitle = "SQZMOM_LB", title="Squeeze Momentum Indicator [LazyBear]", overlay=false)  // 定义研究指标，设置标题，不覆盖主图

// 设置布林带参数
length = input(20, title="BB Length")  // 布林带计算周期，默认20
mult = input(2.0,title="BB MultFactor")  // 布林带标准差倍数，默认2.0

// 设置肯特通道参数
lengthKC=input(20, title="KC Length")  // 肯特通道计算周期，默认20
multKC = input(1.5, title="KC MultFactor")  // 肯特通道乘数，默认1.5

useTrueRange = input(true, title="Use TrueRange (KC)", type=bool)  // 是否使用真实波幅，默认true

// 将功能模块化
//@function 计算布林带
calcBollingerBands(src, len, mult) =>
    basis = sma(src, len)
    dev = mult * stdev(src, len)
    [basis, basis + dev, basis - dev]

//@function 计算肯特通道
calcKeltnerChannel(src, len, mult, useTR) =>
    ma = sma(src, len)
    range = useTR ? tr : (high - low)
    rangema = sma(range, len)
    [ma, ma + rangema * mult, ma - rangema * mult]

//@function 计算挤压状态
calcSqueezeState(lowerBB, upperBB, lowerKC, upperKC) =>
    sqzOn = (lowerBB > lowerKC) and (upperBB < upperKC)
    sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
    noSqz = (sqzOn == false) and (sqzOff == false)
    [sqzOn, sqzOff, noSqz]

// 计算布林带
source = close  // 使用收盘价作为数据源
basis = sma(source, length)  // 计算布林带中轨（简单移动平均线）
dev = multKC * stdev(source, length)  // 计算标准差
upperBB = basis + dev  // 计算布林带上轨
lowerBB = basis - dev  // 计算布林带下轨

// 计算肯特通道
ma = sma(source, lengthKC)  // 计算肯特通道中轨
range = useTrueRange ? tr : (high - low)  // 根据设置选择使用真实波幅或高低差
rangema = sma(range, lengthKC)  // 计算波幅的移动平均
upperKC = ma + rangema * multKC  // 计算肯特通道上轨
lowerKC = ma - rangema * multKC  // 计算肯特通道下轨

// 判断挤压状态
sqzOn  = (lowerBB > lowerKC) and (upperBB < upperKC)  // 布林带在肯特通道内，表示挤压开始
sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)  // 布林带在肯特通道外，表示挤压结束
noSqz  = (sqzOn == false) and (sqzOff == false)  // 既不是挤压开始也不是挤压结束状态

// 计算动量值
val = linreg(source  -  avg(avg(highest(high, lengthKC), lowest(low, lengthKC)),sma(close,lengthKC)), 
            lengthKC,0)  // 使用线性回归计算动量值

// 设置显示颜色
bcolor = iff( val > 0,  // 如果动量值大于0
            iff( val > nz(val[1]), lime, green),  // 如果动量值上升，显示亮绿色，否则显示绿色
            iff( val < nz(val[1]), red, maroon))  // 如果动量值下降，显示红色，否则显示暗红色
scolor = noSqz ? blue : sqzOn ? black : gray  // 设置挤压状态的显示颜色

// 绘制图形
plot(val, color=bcolor, style=histogram, linewidth=4)  // 绘制动量柱状图
plot(0, color=scolor, style=cross, linewidth=2)  // 绘制挤压状态指示线 

// 添加信号强度指示
signalStrength = abs(val) / stdev(abs(val), 20)  // 计算信号强度
plotSignalStrength = plot(signalStrength, "Signal Strength", color=gray)  // 显示信号强度

// 添加趋势方向指示
trendDirection = sma(close, 50)  // 使用50周期均线判断趋势
isUpTrend = close > trendDirection
plotchar(isUpTrend, "Trend", "▲", location.top, isUpTrend ? green : red)

// 添加成交量确认
volConfirmation = volume > sma(volume, 20)  // 成交量确认
plotshape(sqzOff and volConfirmation, "Volume Confirmed", shape.circle)

// 添加信号标签
if (sqzOn and not sqzOn[1])
    label.new(bar_index, high, "挤压开始", color=color.yellow)
if (sqzOff and not sqzOff[1])
    label.new(bar_index, low, "挤压结束", color=color.white) 