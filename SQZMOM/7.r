//@version=5
strategy("Enhanced Squeeze Momentum Strategy", overlay=true, max_bars_back=500, initial_capital=10000, default_qty_type=strategy.percent_of_equity, default_qty_value=100, commission_type=strategy.commission.percent, commission_value=0.1)
// === 缓存和指标变量 === //
var float[] signalBuffer = array.new_float(0)    // @缓存 - 信号缓存数组
var float[] volumeBuffer = array.new_float(0)    // @缓存 - 成交量缓存数组
var float[] emaBuffer = array.new_float(0)       // @缓存 - EMA缓存数组
var float fastEMA = 0.0                          // @指标 - 快速EMA
var float slowEMA = 0.0                          // @指标 - 慢速EMA
var float superSlowEMA = 0.0                     // @指标 - 超慢EMA
var float atr = 0.0                              // @指标 - ATR值
var float sma = 0.0                              // @指标 - SMA值
var float stdev = 0.0                            // @指标 - 标准差值

// === 参数组常量设置 === //
string g_basic = '基础参数'            // @参数组 - 基础参数组
string g_adaptive = '自适应设置'       // @参数组 - 自适应设置组
string g_filter = '过滤器设置'         // @参数组 - 过滤器设置组
string g_visual = '视觉效果'           // @参数组 - 视觉效果组
string g_stats = '统计信息'            // @参数组 - 统计信息组
string g_quality = '信号质量设置'      // @参数组 - 信号质量组
string g_profit = '盈利设置'           // @参数组 - 盈利设置组
string g_mtf = '多重时间框架'          // @参数组 - 多重时间框架组
string g_keylevels = '关键价位'        // @参数组 - 关键价位组
string g_pin_continuity = '插针连续性' // @参数组 - 插针连续性组
string g_advanced_stats = '高级统计'   // @参数组 - 高级统计组

// === 信号管理器 === //
var float prevSignal = 0.0        // @信号 - 前一信号值
var float currentSignal = 0.0     // @信号 - 当前信号值
var int barsSinceSignal = 0       // @计数 - 信号触发后经过K线数
var float signalQuality = 0.0     // @质量 - 信号质量得分
var float signalStrength = 0.0    // @强度 - 信号强度值
var bool isConfirmed = false      // @状态 - 信号是否确认
var float[] signalHistory = array.new_float(0)  // @历史 - 信号历史数组

// === 交易状态跟踪 === //
var int position = 0                // @状态 - 当前持仓状态 (1:多头, -1:空头, 0:空仓)
var float entryPrice = 0.0         // @价格 - 入场价格
var float lastExitPrice = 0.0      // @价格 - 上次出场价格
var float currentProfit = 0.0      // @盈亏 - 当前盈亏
var float maxProfit = 0.0          // @盈亏 - 最大盈利
var float maxLoss = 0.0            // @盈亏 - 最大亏损
var int barsInTrade = 0            // @周期 - 持仓K线数
var bool isInTrade = false         // @状态 - 是否在交易中

// === 价格跟踪系统 === //
var float lastPrice = na         // @价格 - 最新触发价格
var float prevPrice = na         // @价格 - 前一触发价格
var float highestPrice = na      // @价格 - 最高价格记录
var float lowestPrice = na       // @价格 - 最低价格记录
var float lastLongPrice = na     // @价格 - 最后多头入场价格
var float lastShortPrice = na    // @价格 - 最后空头入场价格
var float stopLossLevel = na     // @价格 - 止损价位
var float takeProfitLevel = na   // @价格 - 止盈价位
var float currentAtr = 0.0       // @波动 - 当前ATR值
var float volatility = 0.0       // @波动 - 波动率

// === 视觉设置 === //
var color textColor = color.new(color.white, 0)     // @颜色 - 文字颜色
var int transparency = 20                           // @透明度 - 全局透明度
var color bcolor = na                              // @颜色 - 柱状图颜色
var color scolor = na                              // @颜色 - 形状颜色

// === 交易条件变量 === //
var bool longCondition = false       // @条件 - 做多条件
var bool shortCondition = false      // @条件 - 做空条件
var bool exitLong = false           // @条件 - 平多条件
var bool exitShort = false          // @条件 - 平空条件
var bool isVolatile = false         // @条件 - 高波动状态
var bool isTrending = false         // @条件 - 趋势状态
var bool isSqueezing = false        // @条件 - 挤压状态
var bool hasSignal = false          // @条件 - 有效信号

// === 性能统计变量 === //
var float winRate = 0.0             // @统计 - 胜率
var float avgGain = 0.0             // @统计 - 平均收益
var float maxDrawdown = 0.0         // @风险 - 最大回撤
var float profitFactor = 0.0        // @统计 - 盈亏比
var float avgWinSize = 0.0          // @统计 - 平均盈利大小
var float avgLossSize = 0.0         // @统计 - 平均亏损大小
var int winningTrades = 0           // @统计 - 盈利交易数
var int losingTrades = 0            // @统计 - 亏损交易数
var float peakEquity = 0.0          // @统计 - 峰值权益

// === 计数器状态 === //
var int signalCount = 0             // @计数 - 信号触发次数
var int winCount = 0                // @计数 - 成功信号次数
// === 缓存系统初始化 === //
var float signalAtr = 0.0                        // @缓存 - ATR值
var float signalSma = 0.0                        // @缓存 - SMA值
var float signalStdev = 0.0                      // @缓存 - 标准差值
// === 基础参数设置 === //
int baseLength = input.int(20, title="基础周期", minval=1, group=g_basic)
float baseMult = input.float(2.0, title="基础乘数", minval=0.1, group=g_basic)
int signalLength = input.int(10, title="信号平滑周期", minval=1, group=g_basic)
float momentumThreshold = input.float(0.5, title="动量阈值", minval=0.1, group=g_basic)


// === 流动性监控变量 === //
var float volumeMA = 0.0      // @均线 - 成交量移动平均
var float volumeStdev = 0.0   // @波动 - 成交量标准差
var bool highLiquidity = false // @状态 - 高流动性标记

// === 视觉效果参数 === //
string colorScheme = input.string(defval='Default', title='颜色方案', options=['Default', 'Monochrome', 'Neon'], group=g_visual)

bool showLabels = input.bool(defval=true, title='显示标签', group=g_visual)
bool showCrosses = input.bool(defval=true, title='显示挤压标记', group=g_visual)

// === 颜色变量初始化 === //
var color bullColor = na   // @颜色 - 多头颜色
var color bearColor = na   // @颜色 - 空头颜色

// 初始化颜色
bullColor := color.green  // 多头颜色
bearColor := color.red    // 空头颜色
string labelSize = input.string(defval='Small', title='标签大小', options=['Tiny', 'Small', 'Normal'], group=g_visual)

// === 盈利参数设置 === //
int profitBars = input.int(defval=3, title='盈利确认K线数', minval=1, maxval=10, group=g_profit)
float profitThreshold = input.float(defval=0.3, title='盈利阈值百分比', minval=0.1, maxval=5.0, group=g_profit)

// === 自适应参数设置 === //
bool useAdaptive = input.bool(defval=true, title='启用自适应参数', group=g_adaptive)

// === 过滤器参数设置 === //
float volMultiplier = input.float(defval=2.0, title='成交量倍数', minval=1.0, maxval=5.0, group=g_filter)
int minTrendPeriod = input.int(defval=5, title='最小趋势周期', minval=1, maxval=20, group=g_filter)
bool useVolFilter = input.bool(defval=true, title='启用成交量过滤', group=g_filter)
// === 自适应周期参数 === //
int volatilityWindow = input.int(defval=100, title='波动率周期', minval=1, group=g_adaptive)
int minLength = input.int(defval=10, title='最小周期', minval=1, group=g_adaptive)
int maxLength = input.int(defval=50, title='最大周期', minval=10, group=g_adaptive)

// === 自适应状态变量 === //
var float adaptiveLength = na    // @周期 - 动态调整后的周期
var float adaptiveMultiplier = na // @乘数 - 动态调整后的乘数

// === 过滤器设置 === //
string filterMode = input.string(defval='All', title='过滤模式', options=['All', 'Trend', 'Volume', 'Momentum'], group=g_filter)
bool trendFilter = input.bool(defval=false, title='趋势过滤', group=g_filter)
bool volumeFilter = input.bool(defval=false, title='成交量过滤', group=g_filter)
bool momentumFilter = input.bool(defval=false, title='动量过滤', group=g_filter)
bool breakoutFilter = input.bool(defval=false, title='假突破过滤', group=g_filter)

// === 过滤器状态变量 === //
var bool isValidTrend = false      // @状态 - 趋势有效性
var bool isValidVolume = false     // @状态 - 成交量有效性
var bool isValidMomentum = false   // @状态 - 动量有效性

// === 信号质量参数 === //
float qualityThreshold = input.float(defval=50, title='信号质量阈值', minval=0, maxval=100, group=g_quality)
int trendConsistencyPeriod = input.int(defval=15, title='趋势持续性周期', minval=5, maxval=50, group=g_quality)

int volumeConsistencyBars = input.int(defval=2, title='成交量一致性K线数', minval=2, maxval=10, group=g_quality)
int momentumConfirmationBars = input.int(defval=2, title='动量确认K线数', minval=1, maxval=10, group=g_quality)

// === 统计显示参数 === //
bool showStats = input.bool(defval=true, title='显示统计信息', group=g_stats)
bool showDetailedStats = input.bool(defval=false, title='显示详细统计', group=g_stats)
int statsPeriod = input.int(defval=100, title='统计周期', minval=10, group=g_stats)
string statsPosition = input.string(defval='Top Right', title='统计信息位置', options=['Top Right', 'Top Left', 'Bottom Right', 'Bottom Left'], group=g_stats)
int statsTransparency = input.int(defval=20, title='统计背景透明度', minval=0, maxval=100, group=g_stats)

// === 时间框架参数 === //
string higherTF = input.string(defval='240', title='更高时间框架', options=['60', '120', '240', 'D'], group=g_mtf)
bool useHigherTF = input.bool(defval=true, title='启用多重时间框架确认', group=g_mtf)

// === 价位分析参数 === //
bool usePivots = input.bool(defval=true, title='使用支撑阻力位', group=g_keylevels)
int pivotPeriod = input.int(defval=20, title='关键价位周期', minval=10, group=g_keylevels)
float pivotDeviation = input.float(defval=0.5, title='价位偏差百分比', minval=0.1, maxval=2.0, group=g_keylevels)

// === 插针分析参数 === //
int pinContinuityBars = input.int(defval=5, title='插针连续性检查周期', minval=3, maxval=10, group=g_pin_continuity)
float pinContinuityThreshold = input.float(defval=0.7, title='连续性阈值', minval=0.5, maxval=1.0, group=g_pin_continuity)

// === 高级数据显示 === //
bool showAdvancedStats = input.bool(defval=false, title='显示高级统计', group=g_advanced_stats)

// === 颜色方案定义 === //
getColorScheme() =>
    if colorScheme == 'Default'
        [color.lime, color.green, color.red, color.maroon, color.blue, color.black, color.gray]
    else if colorScheme == 'Monochrome'
        [color.white, color.gray, color.silver, color.gray, color.white, color.black, color.gray]
    else
        [#00ff00, #00cc00, #ff0000, #cc0000, #0000ff, #000000, #666666]

[c_up_strong, c_up_weak, c_down_strong, c_down_weak, c_neutral, c_squeeze, c_text] = getColorScheme()

// === 辅助函数定义 ===
// 计算胜率函数
calcWinRate(int successes, int total) =>
    total > 0 ? successes / total * 100.0 : 0.0

// 更新插针价格数组
updatePinPrices(float[] prices, price) =>
    array.shift(prices)
    array.push(prices, price)

// 计算插针趋势强度
getPinTrendStrength(float[] prices) =>
    float sumDiff = 0.0
    float localPrevPrice = array.get(prices, 0)
    for i = 1 to array.size(prices) - 1
        float currentPrice = array.get(prices, i)
        sumDiff += currentPrice - localPrevPrice
        localPrevPrice := currentPrice
    sumDiff

// 计算关键价位
getPivotLevels() =>
    float pivot = (high + low + close) / 3
    float r1 = pivot * 2 - low
    float s1 = pivot * 2 - high
    float r2 = pivot + (high - low)
    float s2 = pivot - (high - low)
    [pivot, r1, s1, r2, s2]

// 检查价格是否接近关键价位
isNearKeyLevel(price, level) =>
    float deviation = level * pivotDeviation / 100
    math.abs(price - level) <= deviation

// === 自适应函数系统 === //
getTimeframeMultiplier() =>
    float tf = timeframe.in_seconds(timeframe.period) / 60
    math.max(1.0, math.sqrt(tf / 15))

getVolatilityAdjustment() =>
    float localAtr = ta.atr(20)
    float avgAtr = ta.sma(localAtr, 20)
    float volatilityRatio = localAtr / avgAtr
    float result = math.max(0.5, math.min(2.0, volatilityRatio))
    result  // 返回波动率调整因子

bgcolor(color.new(color.blue, 85))  // 高亮显示自适应函数系统

// === 系统初始化 === //
// 交易状态变量
var float prevClose = 0.0     // @缓存 - 上一期收盘价
var float prevVal = 0.0       // @缓存 - 上一期计算值
var float prevVolume = 0.0    // @缓存 - 上一期成交量
var float prevEMA = 0.0       // @缓存 - 上一期EMA值

// 交易标记变量
var bool longTrade = false    // @状态 - 多头交易标记
var bool shortTrade = false   // @状态 - 空头交易标记

// 交易计数变量
var int longCount = 0         // @计数 - 多头交易次数
var int shortCount = 0        // @计数 - 空头交易次数

// === 变量更新系统 === //
// 更新基础数据
prevClose := nz(close[1], close)           // 更新收盘价
prevVolume := nz(volume[1], volume)        // 更新成交量
prevEMA := nz(fastEMA[1], fastEMA)         // 更新均线

// 更新交易状态
longTrade := longCondition ? true : (longTrade and not exitLong)    // 更新多头状态
shortTrade := shortCondition ? true : (shortTrade and not exitShort) // 更新空头状态

// 更新计数器
longCount := longCondition ? longCount + 1 : longCount              // 更新多头计数
shortCount := shortCondition ? shortCount + 1 : shortCount          // 更新空头计数

bgcolor(color.new(color.blue, 85))   // 高亮显示初始化系统

// 统计数据结构
// === 交易统计系统 === //
var float maxConsecutiveWins = 0.0     // @统计 - 最大连续盈利次数
var float maxConsecutiveLosses = 0.0   // @统计 - 最大连续亏损次数
var float currentWinStreak = 0.0       // @统计 - 当前连续盈利次数
var float currentLoseStreak = 0.0      // @统计 - 当前连续亏损次数
var float avgProfitPct = 0.0          // @统计 - 平均盈利百分比
var float avgLossPct = 0.0            // @统计 - 平均亏损百分比
var int totalTrades = 0               // @统计 - 总交易次数
var string detailedStats = ""         // @统计 - 详细统计信息
var string pinStats = ""              // @统计 - 插针统计信息
bgcolor(color.new(color.yellow, 85))   // 高亮显示交易统计系统
// === 关键性能指标 === //
// === 性能监控指标 === //
var float peakBalance = 100.0      // @指标 - 账户峰值（历史最高余额）
var float currentBalance = 100.0    // @指标 - 当前账户余额
var float currentDrawdown = 0.0     // @指标 - 当前回撤水平
var float currentRiskScore = 0.0    // @指标 - 当前风险分数

// === 交易计数器 === //
var int totalLongs = 0          // @计数 - 多头交易总数
var int totalShorts = 0         // @计数 - 空头交易总数
var int successfulLongs = 0     // @计数 - 成功的多头交易
var int successfulShorts = 0    // @计数 - 成功的空头交易

// === 交易状态系统 === //
// 状态标记
var bool inLongTrade = false     // @状态 - 是否持有多头
var bool inShortTrade = false    // @状态 - 是否持有空头

// 价格记录

// 状态更新
inLongTrade := longCondition ? true : (exitLong ? false : inLongTrade)
inShortTrade := shortCondition ? true : (exitShort ? false : inShortTrade)

// 时间跟踪
var int barsAfterLong = 0        // @计数 - 多头入场后K线数
var int barsAfterShort = 0       // @计数 - 空头入场后K线数

// 重置变量
lastLongPrice := longCondition ? close : lastLongPrice    // 更新多头入场价格
lastShortPrice := shortCondition ? close : lastShortPrice // 更新空头入场价格
barsAfterLong := longCondition ? 0 : barsAfterLong + 1   // 更新多头K线计数
barsAfterShort := shortCondition ? 0 : barsAfterShort + 1 // 更新空头K线计数

bgcolor(color.new(color.blue, 85))  // 高亮显示交易跟踪系统

// === 插针信号监控系统 === //
var float avgPinStrength = 0.0      // @指标 - 平均插针强度
var float maxPinStrength = 0.0      // @指标 - 最大插针强度
var int totalPinSignals = 0         // @计数 - 总插针信号数
var float successfulPinRate = 0.0   // @指标 - 插针信号成功率

// === 插针连续性跟踪 === //
var int consecutiveUpperPins = 0     // @计数 - 连续上插针数
var int consecutiveLowerPins = 0     // @计数 - 连续下插针数
var float[] upperPinPrices = array.new_float(pinContinuityBars)  // @数组 - 上插针价格历史
var float[] lowerPinPrices = array.new_float(pinContinuityBars)  // @数组 - 下插针价格历史
bgcolor(color.new(color.blue, 85))  // 高亮显示插针监控系统

// === ATR与均线监控系统 === //
var float atr10 = ta.atr(10)     // @短期ATR - 10周期，快速反应市场波动
var float atr20 = ta.atr(20)     // @中期ATR - 20周期，平衡市场波动判断
var float atr30 = ta.atr(30)     // @长期ATR - 30周期，长期波动基准
var float sma20 = ta.sma(close, 20)  // @均线 - 20周期均线
var float sma50 = ta.sma(close, 50)  // @均线 - 50周期均线
var float vol_sma = ta.sma(volume, baseLength)  // @均线 - 成交量均线
bgcolor(color.new(color.blue, 85))  // 高亮显示ATR计算系统

// === 主要计算 ===
// 更新缓存值
prevClose := nz(close[1], close)
prevVolume := nz(volume[1], volume)

// 获取自适应参数
int currentLength = useAdaptive ? math.max(minLength, int(math.round(baseLength * getTimeframeMultiplier()))) : baseLength
mult = useAdaptive ? math.max(0.1, baseMult * math.sqrt(getVolatilityAdjustment())) : baseMult
lengthKC = currentLength
multKC = mult * 0.75

// 布林带和肯特通道计算
// === K线特征计算系统 === //
float source = close               // @价格 - 使用收盘价作为数据源
float basis = ta.sma(source, currentLength)  // @均线 - 中心移动平均线
float dev = mult * ta.stdev(source, currentLength)  // @波动 - 标准差乘数

// 布林带计算
float upperBB = basis + dev        // @带线 - 布林带上轨
float lowerBB = basis - dev        // @带线 - 布林带下轨

// 肯特通道计算
float ma = ta.sma(source, lengthKC)           // @均线 - 肯特通道中线
float rangema = ta.sma(ta.tr, lengthKC)       // @波幅 - 真实波幅平均
float upperKC = ma + rangema * multKC         // @通道 - 肯特通道上轨
float lowerKC = ma - rangema * multKC         // @通道 - 肯特通道下轨

bgcolor(color.new(color.blue, 85))  // 高亮显示K线特征系统

// === 压缩状态监控系统 === //
bool sqzOn = (lowerBB > lowerKC) and (upperBB < upperKC)   // @状态 - 处于压缩状态
bool sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)  // @状态 - 脱离压缩状态
bool noSqz = (sqzOn == false) and (sqzOff == false)        // @状态 - 非压缩状态

// 压缩状态持续性
var int sqzDuration = 0
sqzDuration := sqzOn ? sqzDuration + 1 : 0  // 跟踪压缩持续时间
bool isLongSqueeze = sqzDuration >= 5        // 判断是否为长期压缩

bgcolor(color.new(color.red, 85))  // 高亮显示压缩监控系统

// === 动量计算 ===
// 改进动量计算方法
getMomentumValue() =>
    float highest = ta.highest(high, currentLength)
    float lowest = ta.lowest(low, currentLength)
    float avgPrice = math.avg(highest, lowest)
    float midPrice = math.avg(avgPrice, ta.sma(close, currentLength))
    float momentum = source - midPrice
    float normalizedMomentum = momentum / ta.stdev(momentum, currentLength)
    float result = normalizedMomentum * 80  // 从100改为80，减少灵敏度
    result  // 显式返回结果

// === 动量计算系统 === //
float val = getMomentumValue()            // @动量 - 获取当前动量值
prevVal := nz(val[1], val)               // @动量 - 缓存上一期动量值
float scaledVal = val * math.max(1.0, math.log(math.abs(val)))  // @动量 - 非线性缩放值
bgcolor(color.new(color.blue, 85))      // 高亮显示动量计算系统

// === 动量排名系统 === //
float momentum_rank = ta.percentrank(val, currentLength)  // @排名 - 动量值的百分比排名
bool isHighMomentum = momentum_rank > 80                 // @状态 - 是否为高动量
bool isLowMomentum = momentum_rank < 20                  // @状态 - 是否为低动量

// 动量过滤
bool validMomentum = not (momentum_rank > 40 and momentum_rank < 60)  // @过滤 - 排除中性区域
bgcolor(color.new(color.purple, 85))  // 高亮显示动量排名系统

// === 趋势过滤系统 === //
fastEMA := ta.ema(close, 20)       // @均线 - 快速EMA(20)用于短期趋势
slowEMA := ta.ema(close, 50)       // @均线 - 慢速EMA(50)用于中期趋势
superSlowEMA := ta.ema(close, 200) // @均线 - 超慢EMA(200)用于长期趋势
prevEMA := nz(fastEMA[1], fastEMA) // @均线 - 上一期快速EMA，用于计算变化
bgcolor(color.new(color.blue, 85))      // 高亮显示趋势过滤系统

// === 趋势持续性监控系统 === //
// 趋势交叉信号检测
bool trendCrossover = ta.crossover(fastEMA, slowEMA)      // @信号 - 快速均线上穿慢速均线
bool trendCrossunder = ta.crossunder(fastEMA, slowEMA)    // @信号 - 快速均线下穿慢速均线

// 趋势持续时间跟踪
int trendDuration = ta.barssince(trendCrossover)         // @时长 - 上升趋势持续K线数
int reverseTrendDuration = ta.barssince(trendCrossunder)  // @时长 - 下降趋势持续K线数

// 趋势状态检查
bool isInUpTrend = trendDuration >= 0 and trendDuration < reverseTrendDuration
bool isInDownTrend = reverseTrendDuration >= 0 and reverseTrendDuration < trendDuration
bgcolor(color.new(color.blue, 85))  // 高亮显示趋势监控系统
bool trendConsistency = (trendDuration >= 0 and trendDuration <= trendConsistencyPeriod) or (reverseTrendDuration >= 0 and reverseTrendDuration <= trendConsistencyPeriod)

// === 趋势动态评估系统 === //
var float trendSlope = 0.0
var float slopeAcceleration = 0.0
var bool trendAccelerating = false

trendSlope := (fastEMA - fastEMA[10]) / fastEMA[10] * 100  // @斜率 - EMA斜率（百分比）
slopeAcceleration := trendSlope - (trendSlope[1])          // @加速度 - 斜率变化
trendAccelerating := slopeAcceleration > 0                  // @状态 - 趋势是否加速
bgcolor(color.new(color.blue, 85))                             // 高亮显示趋势动态系统

// === 趋势强度判定系统 === //
float trendStrength = useAdaptive ? math.abs(fastEMA - slowEMA) / ta.atr(20) : 1.0  // @强度 - 趋势强度指标

// 趋势状态判断
bool strongUpTrend = fastEMA > slowEMA and close > fastEMA and trendStrength > 0.25 and trendConsistency    // @状态 - 强势上涨
bool strongDownTrend = fastEMA < slowEMA and close < fastEMA and trendStrength > 0.25 and trendConsistency  // @状态 - 强势下跌
bgcolor(color.new(color.blue, 85))  // 高亮显示趋势判定系统

// === 成交量过滤 ===
// 修复: 使用全局声明的 vol_sma
var volMA = 0.0
volMA := vol_sma  // 使用已计算的 SMA

// === 成交量过滤增强 ===
// 成交量一致性检查
var float volumeSum = 0.0
volumeSum := math.sum(volume > volMA * 1.3 ? 1.0 : 0.0, volumeConsistencyBars)
var bool volumeConsistency = false
volumeConsistency := volumeSum >= volumeConsistencyBars * 0.6

// 成交量趋势
var float volumeSlope = 0.0
volumeSlope := (volume - volume[3]) / volume[3] * 100
var float volumeTrend = 0.0
volumeTrend := ta.ema(volumeSlope, 5)
var bool volumeTrendUp = false
volumeTrendUp := volumeTrend > 0

// 增强的成交量条件
var bool strongVolume = false
var bool volumeIncreasing = false

strongVolume := volume > volMA * 1.3 and volumeConsistency
volumeIncreasing := volume > prevVolume and volumeTrendUp

// === 动量信号增强 ===
// 动态阈值计算 - 考虑市场波动
var float volatilityFactor = 0.0
var float dynThreshold = 0.0

volatilityFactor := ta.atr(10) / ta.atr(30)
dynThreshold := ta.stdev(val, currentLength) * 1.5 * volatilityFactor

// 动量趋势
var float momentumTrend = 0.0
var float momentumAcceleration = 0.0

momentumTrend := ta.ema(val, momentumConfirmationBars)
momentumAcceleration := momentumTrend - momentumTrend[3]

// 增强的动量条件
var bool momentumUp = false
var bool momentumDown = false

momentumUp := val > dynThreshold and momentumTrend > 0 and momentumAcceleration > 0
momentumDown := val < -dynThreshold and momentumTrend < 0 and momentumAcceleration < 0

// === 假突破过滤增强 ===
// 价格确认
var bool priceConfirmation = false
var bool priceRejection = false
var bool strongMomentum = false

priceConfirmation := close > ta.highest(high[1], 3)
priceRejection := close < ta.lowest(low[1], 3)

// 增强的突破条件
strongMomentum := math.abs(val) > ta.stdev(math.abs(val), signalLength) * 0.8
var bool sustainedBreakout = false
sustainedBreakout := ta.barssince(sqzOff) <= 5 and strongMomentum

// === 插针形态分析 ===
// 计算影线比例
getShadowRatio(open, high, low, close) =>
    float body = math.abs(close - open)
    float upperShadow = high - math.max(open, close)
    float lowerShadow = math.min(open, close) - low
    float shadowRatio = body > 0 ? (upperShadow + lowerShadow) / body : 0.0
    [shadowRatio, upperShadow, lowerShadow]

// 插针形态识别
[currentShadowRatio, upperShadow, lowerShadow] = getShadowRatio(open, high, low, close)
isUpperPin = upperShadow > lowerShadow * 2 and upperShadow > atr10 * 0.5
isLowerPin = lowerShadow > upperShadow * 2 and lowerShadow > atr10 * 0.5

// 获取更高时间框架数据
htf_close = request.security(syminfo.tickerid, higherTF, close)
htf_high = request.security(syminfo.tickerid, higherTF, high)
htf_low = request.security(syminfo.tickerid, higherTF, low)
htf_volume = request.security(syminfo.tickerid, higherTF, volume)

// 计算关键价位   
[pivot, r1, s1, r2, s2] = getPivotLevels()

// 增强的插针形态识别 - 使用预计算的 SMA
getEnhancedPinSignal(isPin, shadowSize, bodySize, isLong) =>
    // 基本条件
    basicCondition = isPin and shadowSize > atr10 * 0.5  // 使用预计算的 ATR
    
    // 多重时间框架确认
    htfConfirmation = true
    if useHigherTF
        htf_range = htf_high - htf_low
        htf_threshold = htf_range * 0.3
        htfConfirmation := isLong ?    close > htf_close - htf_threshold : close < htf_close + htf_threshold
       
    // 关键价位确认   
    keyLevelConfirmation = false
    if usePivots
        keyLevelConfirmation := isNearKeyLevel(close, pivot) or 
                               isNearKeyLevel(close, isLong ? s1 : r1) or 
                               isNearKeyLevel(close, isLong ? s2 : r2)
    
    // 成交量确认增强 - 使用预计算的 SMA
    volumeSpike = volume > vol_sma * 1.5 and volume > volume[1] * 1.2
    
    // 趋势确认 - 使用预计算的 SMA
    trendConfirmation = isLong ? close < sma20 : close > sma20
    
    // 计算信号强度
    signalStrength := math.min(1.0, (shadowSize / atr10) *
                           (volumeSpike ? 1.2 : 1.0) *
                           (keyLevelConfirmation ? 1.3 : 1.0) *
                           (htfConfirmation ? 1.2 : 0.8))
    if basicCondition
        signalStrength := math.min(1.0, (shadowSize / atr10) * 
                                       (volumeSpike ? 1.2 : 1.0) * 
                                       (keyLevelConfirmation ? 1.3 : 1.0) * 
                                       (htfConfirmation ? 1.2 : 0.8))
    
    [basicCondition and htfConfirmation and (keyLevelConfirmation or volumeSpike), signalStrength]

// 应用增强的插针信号
[upperPinSignal, upperPinStrength] = getEnhancedPinSignal(isUpperPin, upperShadow, math.abs(close - open), false)
[lowerPinSignal, lowerPinStrength] = getEnhancedPinSignal(isLowerPin, lowerShadow, math.abs(close - open), true)

// === 插针连续性分析 ===
// 更新连续插针计数和价格数组
if upperPinSignal
    consecutiveUpperPins := consecutiveUpperPins + 1
    consecutiveLowerPins := 0
    updatePinPrices(upperPinPrices, high)
else if lowerPinSignal
    consecutiveLowerPins := 1
    consecutiveUpperPins := 0
    updatePinPrices(lowerPinPrices, low)
else
    consecutiveUpperPins := 0
    consecutiveLowerPins := 0

// 计算插针趋势
upperPinTrend = getPinTrendStrength(upperPinPrices)
lowerPinTrend = getPinTrendStrength(lowerPinPrices)

// 插针连续性确认
upperPinContinuity = consecutiveUpperPins >= 2 and upperPinTrend < 0
lowerPinContinuity = consecutiveLowerPins >= 2 and lowerPinTrend > 0

// === 信号质量评分 ===
// 计算各个组成部分的得分
trendScore = math.min(1.0, trendStrength * 2)
volumeScore = volumeSum / volumeConsistencyBars
momentumScore = math.min(1.0, math.abs(val) / dynThreshold)

// 计算插针连续性得分
pinContinuityScore = 0.0
if upperPinSignal and upperPinContinuity
    pinContinuityScore := math.min(1.0, consecutiveUpperPins / pinContinuityBars)
else if lowerPinSignal and lowerPinContinuity
    pinContinuityScore := math.min(1.0, consecutiveLowerPins / pinContinuityBars)

// 更新插针得分
pinScore = math.max(upperPinStrength, lowerPinStrength) * (1 + pinContinuityScore * 0.5)

// 计算综合得分
signalQuality := (trendScore + volumeScore + momentumScore + pinScore) / 4.0 * 100

// === 信号生成增强 ===
getFilteredSignal(baseSignal, trendOk, volOk, momOk, float sq) =>
    if filterMode == "All"
        baseSignal and (not trendFilter or trendOk) and (not volumeFilter or volOk) and (not momentumFilter or momOk) and sq > qualityThreshold
    else if filterMode == "Trend"
        baseSignal and trendOk and sq > qualityThreshold * 0.8
    else if filterMode == "Volume"
        baseSignal and volOk and sq > qualityThreshold * 0.8
    else
        baseSignal and momOk and sq > qualityThreshold * 0.8

// 生成信号
longSignal = getFilteredSignal(sqzOff and momentumUp and priceConfirmation, strongUpTrend, strongVolume and volumeIncreasing, sustainedBreakout, signalQuality)
shortSignal = getFilteredSignal(sqzOff and momentumDown and priceRejection, strongDownTrend, strongVolume and volumeIncreasing, sustainedBreakout, signalQuality)
squeezeStartSignal = sqzOn and not sqzOn[1]
squeezeEndSignal = sqzOff and not sqzOff[1]

// 更新插针信号
longSignal := longSignal or (lowerPinSignal and lowerPinStrength > 1.2 and lowerPinContinuity)
shortSignal := shortSignal or (upperPinSignal and upperPinStrength > 1.2 and upperPinContinuity)

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
        longProfit = (close - lastLongPrice) / lastLongPrice * 100
        isWin = longProfit > profitThreshold
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
            currentBalance := peakBalance * (1 + longProfit/100)
            currentDrawdown := (peakBalance - currentBalance) / peakBalance * 100
            maxDrawdown := math.max(maxDrawdown, currentDrawdown)
        
        totalTrades := totalTrades + 1
        lastLongPrice := 0.0

// 跟踪空头信号
if lastShortPrice > 0
    barsAfterShort := barsAfterShort + 1
    if barsAfterShort == profitBars
        shortProfit = (lastShortPrice - close) / lastShortPrice * 100
        isWin = shortProfit > profitThreshold
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
            currentBalance := peakBalance * (1 + shortProfit/100)
            currentDrawdown := (peakBalance - currentBalance) / peakBalance * 100
            maxDrawdown := math.max(maxDrawdown, currentDrawdown)
        
        totalTrades := totalTrades + 1

// === 统计信息显示 ===
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
    if showDetailedStats
        string profitFactorText = "盈亏比: " + str.tostring(math.abs(avgProfitPct/avgLossPct), "#.2")
        string maxWinsText = "最大连胜: " + str.tostring(maxConsecutiveWins, "#")
        string maxLossesText = "最大连亏: " + str.tostring(maxConsecutiveLosses, "#")
        string drawdownText = "最大回撤: " + str.tostring(maxDrawdown, "#.1") + "%"
        detailedStats := "\n" + profitFactorText + "\n" + maxWinsText + "\n" + maxLossesText + "\n" + drawdownText
    
    // 更新最后空头价格
    if strategy.position_size < 0
        lastShortPrice := strategy.position_avg_price
    
    // 构建插针统计信息
    pinStats := ""
    if showAdvancedStats
        pinStats := "\n=== 插针统计 ===\n" +
                   "平均强度: " + str.tostring(avgPinStrength * 100, "#.1") + "%\n" +
                   "最大强度: " + str.tostring(maxPinStrength * 100, "#.1") + "%\n" +
                   "总信号数: " + str.tostring(totalPinSignals) + "\n" +
                   "连续性得分: " + str.tostring(pinContinuityScore * 100, "#.1") + "%"
    
    // 合并所有
    statsText = longText + "\n" + shortText + "\n" + totalText + "\n" + qualityText + detailedStats + pinStats
    
    // 确定标签位置
    var int x_pos = 0
    var y_pos = 0.0
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
    
    // 降低多空信号的显示条件
    if longSignal
        label.new(bar_index, low, text="做多\n" + str.tostring(signalQuality, "#.1") + "%", color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle)
    
    if shortSignal
        label.new(bar_index, high, text="做空\n" + str.tostring(signalQuality, "#.1") + "%", color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    
    if squeezeStartSignal
        label.new(bar_index, low, text="挤压", color=c_squeeze, textcolor=color.white, size=labelStyle)
    
    if squeezeEndSignal
        label.new(bar_index, high, text="突破", color=c_neutral, textcolor=color.yellow, size=labelStyle)
    
    // 插针信号
    if upperPinSignal or lowerPinSignal
        continuityInfo = ""
        
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

// === 绘制主图 ===
hline(0, color=color.gray, linestyle=hline.style_dotted)
plot(dynThreshold, title="Upper Threshold", color=color.new(color.green, 50), style=plot.style_line, linewidth=1)
plot(-dynThreshold, title="Lower Threshold", color=color.new(color.red, 50), style=plot.style_line, linewidth=1)
plot(series=scaledVal, title="Momentum", color=bcolor, style=plot.style_columns, linewidth=4)
plotshape(series=0, title="Squeeze", color=scolor, style=shape.cross, size=size.small, display=showCrosses ? display.all : display.none)

// === 警报设置 ===
alertcondition(longSignal and signalQuality > qualityThreshold, title="做多信号", message="强势做多信号出现")
alertcondition(shortSignal and signalQuality > qualityThreshold, title="做空信号", message="强势做空信号出现")
alertcondition(squeezeStartSignal, title="挤压开始", message="价格开始挤压")
alertcondition(squeezeEndSignal, title="挤压结束", message="价格突破挤压区间")
alertcondition(upperPinSignal and upperPinStrength > 1.2, title="上插针信号", message="强势上插针形态出现")
alertcondition(lowerPinSignal and lowerPinStrength > 1.2, title="下插针信号", message="强势下插针形态出现")

// === 扩展功能：自定义策略 ===
var customStrategyScore = 0.0

// 更新策略得分
getCustomScore() =>
    int momScore = ta.mom(close, 10) > ta.sma(ta.mom(close, 10), 5) ? 1 : -1
    int rsiScore = ta.rsi(close, 14) > 50 ? 1 : -1
    int macdScore = val > 0 ? 1 : -1
    (momScore + rsiScore + macdScore) / 3

// 修复: 只在最后一根K线更新customStrategyScore
if barstate.islast
    customStrategyScore := getCustomScore()

// === 自定义指标组合 ===
// MACD设置
[macdLine, signalLine, _] = ta.macd(close, 12, 26, 9)
bool macdCross = ta.crossover(macdLine, signalLine)
bool macdCrossDown = ta.crossunder(macdLine, signalLine)

// 布林带设置
float bbMiddle = ta.sma(close, 20)
float bbDev = ta.stdev(close, 20)
float bbUpper = bbMiddle + bbDev * 2
float bbLower = bbMiddle - bbDev * 2

// RSI超买超卖
float rsi = ta.rsi(close, 14)
bool rsiOverbought = rsi >= 70
bool rsiOversold = rsi <= 30

// === 自定义信号过滤 ===
getSignalScore() =>
    score = 0.0
    
    // 趋势得分
    if strongUpTrend
        score += 2
    if strongDownTrend
        score -= 2
        
    // 动量得分
    if momentumUp
        score += 1.5
    if momentumDown
        score -= 1.5
        
    // 成交量得分
    if volumeIncreasing
        score += 1
        
    // MACD得分
    if macdCross
        score += 1
    if macdCrossDown
        score -= 1
        
    // RSI得分
    if rsiOverbought
        score -= 1
    if rsiOversold
        score += 1
        
    // 布林带得分
    if close > bbUpper
        score -= 0.5
    if close < bbLower
        score += 0.5
        
    score

// === 风险管理 ===
// 计算风险分数
getRiskScore() =>
    float volRisk = volume > volMA * 2 ? 1.0 : 0.0
    float gapRisk = math.abs(open - close[1]) > atr10 ? 1.0 : 0.0
    float trendRisk = math.abs(close - sma50) / sma50 * 100
    float compositeRisk = (volRisk + gapRisk + math.min(trendRisk, 5.0)) / 7.0 * 100
    compositeRisk

// 更新统计数据
var totalRiskScore = 0.0
var int riskCount = 0
var maxRiskScore = 0.0

currentRiskScore = getRiskScore()
totalRiskScore := totalRiskScore + currentRiskScore
riskCount := riskCount + 1
maxRiskScore := math.max(maxRiskScore, currentRiskScore)

// === 性能优化 ===
// 缓存常用计算结果
var cached_bb_width = ta.stdev(close, 20) * 2
var cached_momentum = 0.0

// 定期更新缓存
if barstate.islast
    cached_bb_width := ta.stdev(close, 20) * 2
    cached_momentum := val
// === 终止
// === 更新插针统计 ===
if upperPinSignal or lowerPinSignal
    currentPinStrength = math.max(upperPinStrength, lowerPinStrength)
    avgPinStrength := (avgPinStrength * totalPinSignals + currentPinStrength) / (totalPinSignals + 1)
    maxPinStrength := math.max(maxPinStrength, currentPinStrength)
    totalPinSignals := totalPinSignals + 1

// === 显示设置 ===
// 改进颜色渐变
getBarColor(value, prevValue) =>
    if value > 0
        value > prevValue ? color.new(c_up_strong, 0) : color.new(c_up_weak, 20)
    else
        value < prevValue ? color.new(c_down_strong, 0) : color.new(c_down_weak, 20)

bcolor := getBarColor(val, prevVal)
scolor := noSqz ? c_neutral : sqzOn ? c_squeeze : c_text

// === 统计信息显示 ===
if showStats
    var label statsLabel = na
    label.delete(statsLabel[1])
    
    // 计算统计数据
    longWinRate = calcWinRate(successfulLongs, totalLongs)
    shortWinRate = calcWinRate(successfulShorts, totalShorts)
    totalWinRate = calcWinRate(successfulLongs + successfulShorts, totalTrades)
    
    // 构建基础统计信息
    string longText = "多头胜率: " + str.tostring(longWinRate, "#.1") + "%"
    string shortText = "空头胜率: " + str.tostring(shortWinRate, "#.1") + "%"
    string totalText = "总胜率: " + str.tostring(totalWinRate, "#.1") + "%"
    string qualityText = "信号质量: " + str.tostring(signalQuality, "#.1") + "%"
    
    // 构建详细统计信息
    detailedStats := ""
    if showDetailedStats
        string profitFactorText = "盈亏比: " + str.tostring(math.abs(avgProfitPct/avgLossPct), "#.2")
        string maxWinsText = "最大连胜: " + str.tostring(maxConsecutiveWins, "#")
        string maxLossesText = "最大连亏: " + str.tostring(maxConsecutiveLosses, "#")
        string drawdownText = "最大回撤: " + str.tostring(maxDrawdown, "#.1") + "%"
        detailedStats := "\n" + profitFactorText + "\n" + maxWinsText + "\n" + maxLossesText + "\n" + drawdownText
    
    // 构建插针统计信息
    if showAdvancedStats
        pinStats := "\n=== 插针统计 ===\n" +
                   "平均强度: " + str.tostring(avgPinStrength * 100, "#.1") + "%\n" +
                   "最大强度: " + str.tostring(maxPinStrength * 100, "#.1") + "%\n" +
                   "总信号数: " + str.tostring(totalPinSignals) + "\n" +
                   "连续性得分: " + str.tostring(pinContinuityScore * 100, "#.1") + "%"
    
    // 合并所有统计信息
    statsText = longText + "\n" + shortText + "\n" + totalText + "\n" + qualityText + detailedStats + pinStats
    
    // 确定标签位置
    var int x_pos = 0
    var y_pos = 0.0
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
    string labelStyle = labelSize == "Tiny" ? size.tiny : labelSize == "Small" ? size.small : size.normal
    
    // 降低多空信号的显示条件
    if longSignal
        label.new(bar_index, low, text="做多\n" + str.tostring(signalQuality, "#.1") + "%", color=c_up_strong, style=label.style_label_up, textcolor=color.white, size=labelStyle)
    
    if shortSignal
        label.new(bar_index, high, text="做空\n" + str.tostring(signalQuality, "#.1") + "%", color=c_down_strong, style=label.style_label_down, textcolor=color.white, size=labelStyle)
    
    if squeezeStartSignal
        label.new(bar_index, low, text="挤压", color=c_squeeze, textcolor=color.white, size=labelStyle)
    
    if squeezeEndSignal
        label.new(bar_index, high, text="突破", color=c_neutral, textcolor=color.yellow, size=labelStyle)
    
    // 显示插针信号
    if upperPinSignal or lowerPinSignal
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

// === 绘制主图 ===
hline(0, color=color.gray, linestyle=hline.style_dotted)
plot(dynThreshold, title="Upper Threshold", color=color.new(color.green, 50), style=plot.style_line, linewidth=1)
plot(-dynThreshold, title="Lower Threshold", color=color.new(color.red, 50), style=plot.style_line, linewidth=1)
plot(series=scaledVal, title="Momentum", color=bcolor, style=plot.style_columns, linewidth=4)
plotshape(series=0, title="Squeeze", color=scolor, style=shape.cross, size=size.small, display=showCrosses ? display.all : display.none)

// === 警报设置 ===
alertcondition(longSignal and signalQuality > qualityThreshold, title="做多信号", message="强势做多信号出现")
alertcondition(shortSignal and signalQuality > qualityThreshold, title="做空信号", message="强势做空信号出现")
alertcondition(squeezeStartSignal, title="挤压开始", message="价格开始挤压")
alertcondition(squeezeEndSignal, title="挤压结束", message="价格突破挤压区间")
alertcondition(upperPinSignal and upperPinStrength > 1.2, title="上插针信号", message="强势上插针形态出现")
alertcondition(lowerPinSignal and lowerPinStrength > 1.2, title="下插针信号", message="强势下插针形态出现")

// 修复: 在全局范围更新customStrategyScore
customStrategyScore := getCustomScore()



// 更新统计数据
currentRiskScore := getRiskScore()
totalRiskScore := totalRiskScore + currentRiskScore
riskCount := riskCount + 1
maxRiskScore := math.max(maxRiskScore, currentRiskScore)

// === 性能优化 ===
// 缓存常用计算结果
var cached_bb_width = ta.stdev(close, 20) * 2
var cached_momentum = 0.0

// 定期更新缓存
if barstate.islast
    cached_bb_width := ta.stdev(close, 20) * 2
    cached_momentum := val
