// 该作品根据知识共享署名-非商业性使用-相同方式共享 4.0 国际 (CC BY-NC-SA 4.0) 进行许可 https://creativecommons.org/licenses/by-nc-sa/4.0/
// © LuxAlgo

//@version=5
indicator("SuperTrend AI (Clustering) [LuxAlgo]", "LuxAlgo - SuperTrend AI", overlay = true, max_labels_count = 500)
//------------------------------------------------------------------------------
// 设置
//-----------------------------------------------------------------------------{
length = input(10, 'ATR Length') // 输入ATR的长度，默认为10

minMult = input.int(1, 'Factor Range', minval = 0, inline = 'factor') // 输入最小因子范围，默认为1
maxMult = input.int(5, '', minval = 0, inline = 'factor') // 输入最大因子范围，默认为5
step    = input.float(.5, 'Step', minval = 0, step = 0.1) // 输入步长，默认为0.5

// 触发错误
if minMult > maxMult // 如果最小因子大于最大因子，则触发错误
    runtime.error('Minimum factor is greater than maximum factor in the range')

perfAlpha = input.float(10, 'Performance Memory', minval = 2) // 输入性能记忆，默认为10
fromCluster = input.string('Best', 'From Cluster', options = ['Best', 'Average', 'Worst']) // 输入从哪个集群获取数据，默认为'Best'

// 优化
maxIter = input.int(1000, 'Maximum Iteration Steps', minval = 0, group = 'Optimization') // 输入最大迭代步骤，默认为1000
maxData = input.int(10000, 'Historical Bars Calculation', minval = 0, group = 'Optimization') // 输入历史条计算的最大数据，默认为10000

// 样式
bearCss = input(color.red, 'Trailing Stop', inline = 'ts', group = 'Style') // 输入下跌止损的颜色，默认为红色
bullCss = input(color.teal, '', inline = 'ts', group = 'Style') // 输入上涨止损的颜色，默认为青色

amaBearCss = input(color.new(color.red, 50), 'AMA', inline = 'ama', group = 'Style') // 输入下跌AMA的颜色，默认为半透明红色
amaBullCss = input(color.new(color.teal, 50), '', inline = 'ama', group = 'Style') // 输入上涨AMA的颜色，默认为半透明青色

showGradient = input(true, 'Candle Coloring', group = 'Style') // 输入是否显示蜡烛颜色，默认为true
showSignals = input(true, 'Show Signals', group = 'Style') // 输入是否显示信号，默认为true

// 仪表盘
showDash  = input(true, 'Show Dashboard', group = 'Dashboard') // 输入是否显示仪表盘，默认为true
dashLoc  = input.string('Top Right', 'Location', options = ['Top Right', 'Bottom Right', 'Bottom Left'], group = 'Dashboard') // 输入仪表盘位置，默认为右上角
textSize = input.string('Small', 'Size'        , options = ['Tiny', 'Small', 'Normal'], group = 'Dashboard') // 输入文本大小，默认为小

// 添加优化开关
useOptimizedParams = input(false, "Use Genetic Optimization", group = "Optimization")
populationSize = input.int(30, "Population Size", minval = 10, maxval = 100, group = "Optimization")
maxGenerations = input.int(50, "Max Generations", minval = 10, maxval = 200, group = "Optimization")
mutationRate = input.float(0.1, "Mutation Rate", minval = 0.01, maxval = 0.5, group = "Optimization")
crossoverRate = input.float(0.8, "Crossover Rate", minval = 0.1, maxval = 1.0, group = "Optimization")
eliteSize = input.int(3, "Elite Size", minval = 1, maxval = 10, group = "Optimization")

// 适应度函数权重
returnsWeight = input.float(0.4, "Returns Weight", minval = 0.0, maxval = 1.0, group = "Fitness Weights")
drawdownWeight = input.float(0.2, "Drawdown Weight", minval = 0.0, maxval = 1.0, group = "Fitness Weights")
sharpeWeight = input.float(0.2, "Sharpe Ratio Weight", minval = 0.0, maxval = 1.0, group = "Fitness Weights")
winrateWeight = input.float(0.2, "Win Rate Weight", minval = 0.0, maxval = 1.0, group = "Fitness Weights")

//-----------------------------------------------------------------------------}
// 用户定义类型
//-----------------------------------------------------------------------------{
type supertrend // 定义supertrend类型
    float upper = hl2 // 上轨
    float lower = hl2 // 下轨
    float output // 输出值
    float perf = 0 // 性能
    float factor // 因子
    int trend = 0 // 趋势

type vector // 定义向量类型
    array<float> out // 存储浮点数的数组

// 添加遗传算法相关类型定义
type chromosome
    int atr_length = 10
    int min_mult = 1
    int max_mult = 5
    float step = 0.5
    float perf_alpha = 10.0
    float fitness = 0.0

//-----------------------------------------------------------------------------}
// 超级趋势
//-----------------------------------------------------------------------------{
var holder = array.new<supertrend>(0) // 创建supertrend类型的数组
var factors = array.new<float>(0) // 创建因子数组

// 填充supertrend类型数组
if barstate.isfirst // 如果是第一根K线
    for i = 0 to int((maxMult - minMult) / step) // 遍历因子范围
        factors.push(minMult + i * step) // 将因子添加到数组中
        holder.push(supertrend.new()) // 创建新的supertrend并添加到holder中

atr = ta.atr(length) // 计算ATR值

// 计算多个因子的超级趋势
k = 0 // 初始化索引
for factor in factors // 遍历因子
    get_spt = holder.get(k) // 获取当前supertrend

    up = hl2 + atr * factor // 计算上轨
    dn = hl2 - atr * factor // 计算下轨
    
    get_spt.trend := close > get_spt.upper ? 1 : close < get_spt.lower ? 0 : get_spt.trend // 更新趋势
    get_spt.upper := close[1] < get_spt.upper ? math.min(up, get_spt.upper) : up // 更新上轨
    get_spt.lower := close[1] > get_spt.lower ? math.max(dn, get_spt.lower) : dn // 更新下轨
    
    diff = nz(math.sign(close[1] - get_spt.output)) // 计算差异
    get_spt.perf += 2/(perfAlpha+1) * (nz(close - close[1]) * diff - get_spt.perf) // 更新性能
    get_spt.output := get_spt.trend == 1 ? get_spt.lower : get_spt.upper // 更新输出
    get_spt.factor := factor // 更新因子
    k += 1 // 索引加1

//-----------------------------------------------------------------------------}
// K-means聚类
//-----------------------------------------------------------------------------{
factor_array = array.new<float>(0) // 创建因子数组
data = array.new<float>(0) // 创建数据数组

// 填充数据数组
if last_bar_index - bar_index <= maxData // 如果当前条数小于最大数据
    for element in holder // 遍历holder中的每个元素
        data.push(element.perf) // 将性能添加到数据数组
        factor_array.push(element.factor) // 将因子添加到因子数组

// 初始化质心使用四分位数
centroids = array.new<float>(0) // 创建质心数组
centroids.push(data.percentile_linear_interpolation(25)) // 添加25%分位数
centroids.push(data.percentile_linear_interpolation(50)) // 添加50%分位数
centroids.push(data.percentile_linear_interpolation(75)) // 添加75%分位数

// 初始化聚类
var array<vector> factors_clusters = na // 创建因子聚类数组
var array<vector> perfclusters = na // 创建性能聚类数组

if last_bar_index - bar_index <= maxData // 如果当前条数小于最大数据
    for _ = 0 to maxIter // 遍历最大迭代次数
        factors_clusters := array.from(vector.new(array.new<float>(0)), vector.new(array.new<float>(0)), vector.new(array.new<float>(0))) // 初始化因子聚类
        perfclusters := array.from(vector.new(array.new<float>(0)), vector.new(array.new<float>(0)), vector.new(array.new<float>(0))) // 初始化性能聚类
        
        // 将值分配到聚类
        i = 0 // 初始化索引
        for value in data // 遍历数据
            dist = array.new<float>(0) // 创建距离数组
            for centroid in centroids // 遍历质心
                dist.push(math.abs(value - centroid)) // 计算距离并添加到数组

            idx = dist.indexof(dist.min()) // 获取最小距离的索引
            perfclusters.get(idx).out.push(value) // 将值添加到对应的性能聚类
            factors_clusters.get(idx).out.push(factor_array.get(i)) // 将因子添加到对应的因子聚类
            i += 1 // 索引加1

        // 更新质心
        new_centroids = array.new<float>(0) // 创建新的质心数组
        for cluster_ in perfclusters // 遍历性能聚类
            new_centroids.push(cluster_.out.avg()) // 计算并添加新的质心

        // 测试质心是否改变
        if new_centroids.get(0) == centroids.get(0) and new_centroids.get(1) == centroids.get(1) and new_centroids.get(2) == centroids.get(2) // 如果质心没有改变
            break // 退出循环

        centroids := new_centroids // 更新质心

//-----------------------------------------------------------------------------}
// 信号和跟踪止损
//-----------------------------------------------------------------------------{
// 获取相关的超级趋势
var float target_factor = na // 目标因子
var float perf_idx = na // 性能索引
var float perf_ama = na // 性能AMA

var from = switch fromCluster // 根据选择的集群类型设置from
    'Best' => 2 // 最佳
    'Average' => 1 // 平均
    'Worst' => 0 // 最差

// 性能索引分母
den = ta.ema(math.abs(close - close[1]), int(perfAlpha)) // 计算性能索引的分母

if not na(perfclusters) // 如果性能聚类不为na
    // 获取目标聚类内的平均因子 
    target_factor := nz(factors_clusters.get(from).out.avg(), target_factor) // 获取目标因子的平均值
    
    // 获取目标聚类的性能索引 
    perf_idx := math.max(nz(perfclusters.get(from).out.avg()), 0) / den // 计算性能索引

// 获取新的超级趋势
var upper = hl2 // 初始化上轨
var lower = hl2 // 初始化下轨
var os = 0 // 初始化状态

up = hl2 + atr * target_factor // 计算新的上轨
dn = hl2 - atr * target_factor // 计算新的下轨
upper := close[1] < upper ? math.min(up, upper) : up // 更新上轨
lower := close[1] > lower ? math.max(dn, lower) : dn // 更新下轨
os := close > upper ? 1 : close < lower ? 0 : os // 更新状态
ts = os ? lower : upper // 设置跟踪止损

// 获取跟踪止损自适应MA
if na(ts[1]) and not na(ts) // 如果前一个止损为na且当前止损不为na
    perf_ama := ts // 设置性能AMA为当前止损
else
    perf_ama += perf_idx * (ts - perf_ama) // 更新性能AMA

//-----------------------------------------------------------------------------}
// 仪表盘
//-----------------------------------------------------------------------------{
var table_position = dashLoc == 'Bottom Left' ? position.bottom_left // 设置仪表盘位置
  : dashLoc == 'Top Right' ? position.top_right 
  : position.bottom_right

var table_size = textSize == 'Tiny' ? size.tiny // 设置仪表盘文本大小
  : textSize == 'Small' ? size.small 
  : size.normal

var tb = table.new(table_position, 4, 4 // 创建新的表格
  , bgcolor = #1e222d // 设置背景颜色
  , border_color = #373a46 // 设置边框颜色
  , border_width = 1 // 设置边框宽度
  , frame_color = #373a46 // 设置框架颜色
  , frame_width = 1) // 设置框架宽度

if showDash // 如果显示仪表盘
    if barstate.isfirst // 如果是第一根K线
        tb.cell(0, 0, 'Cluster', text_color = color.white, text_size = table_size) // 设置表格单元格内容
        tb.cell(0, 1, 'Best', text_color = color.white, text_size = table_size)
        tb.cell(0, 2, 'Average', text_color = color.white, text_size = table_size)
        tb.cell(0, 3, 'Worst', text_color = color.white, text_size = table_size)
    
        tb.cell(1, 0, 'Size', text_color = color.white, text_size = table_size)
        tb.cell(2, 0, 'Centroid Dispersion', text_color = color.white, text_size = table_size)
        tb.cell(3, 0, 'Factors', text_color = color.white, text_size = table_size)
    
    if barstate.islast // 如果是最后一根K线
        topN = perfclusters.get(2).out.size() // 获取最佳聚类的大小
        midN = perfclusters.get(1).out.size() // 获取平均聚类的大小
        btmN = perfclusters.get(0).out.size() // 获取最差聚类的大小

        // 大小
        tb.cell(1, 1, str.tostring(topN), text_color = color.white, text_size = table_size) // 设置最佳聚类大小
        tb.cell(1, 2, str.tostring(midN), text_color = color.white, text_size = table_size) // 设置平均聚类大小
        tb.cell(1, 3, str.tostring(btmN), text_color = color.white, text_size = table_size) // 设置最差聚类大小
        
        // 内容
        tb.cell(3, 1, str.tostring(factors_clusters.get(2).out), text_color = color.white, text_size = table_size, text_halign = text.align_left) // 设置最佳聚类因子
        tb.cell(3, 2, str.tostring(factors_clusters.get(1).out), text_color = color.white, text_size = table_size, text_halign = text.align_left) // 设置平均聚类因子
        tb.cell(3, 3, str.tostring(factors_clusters.get(0).out), text_color = color.white, text_size = table_size, text_halign = text.align_left) // 设置最差聚类因子

        // 计算质心周围的离散度
        i = 0 // 初始化索引
        for cluster_ in perfclusters // 遍历性能聚类
            disp = 0. // 初始化离散度
            if cluster_.out.size() > 1 // 如果聚类大小大于1
                for value in cluster_.out // 遍历聚类中的每个值
                    disp += math.abs(value - centroids.get(i)) // 计算离散度
            
            disp /= switch i // 根据索引计算离散度
                0 => btmN
                1 => midN
                2 => topN

            i += 1 // 索引加1
            tb.cell(2, 4 - i, str.tostring(disp, '#.####'), text_color = color.white, text_size = table_size) // 设置离散度

//-----------------------------------------------------------------------------}
// 绘图
//-----------------------------------------------------------------------------{
css = os ? bullCss : bearCss // 根据状态选择颜色

plot(ts, 'Trailing Stop', os != os[1] ? na : css) // 绘制跟踪止损

plot(perf_ama, 'Trailing Stop AMA', // 绘制跟踪止损自适应MA
  ta.cross(close, perf_ama) ? na
  : close > perf_ama ? amaBullCss : amaBearCss)

// 蜡烛颜色
barcolor(showGradient ? color.from_gradient(perf_idx, 0, 1, color.new(css, 80), css) : na) // 根据性能索引设置蜡烛颜色

// 信号
n = bar_index // 当前K线索引

if showSignals // 如果显示信号
    if os > os[1] // 如果状态上升
        label.new(n, ts, str.tostring(int(perf_idx * 10)) // 创建新的标签
          , color = bullCss // 设置标签颜色
          , style = label.style_label_up // 设置标签样式
          , textcolor = color.white // 设置文本颜色
          , size = size.tiny) // 设置文本大小

    if os < os[1] // 如果状态下降
        label.new(n, ts, str.tostring(int(perf_idx * 10)) // 创建新的标签
          , color = bearCss // 设置标签颜色
          , style = label.style_label_down // 设置标签样式
          , textcolor = color.white // 设置文本颜色
          , size = size.tiny) // 设置文本大小

//-----------------------------------------------------------------------------}

// 遗传算法函数
calculate_fitness(chromosome ch, float[] returns) =>
    float total_return = 0.0
    float max_drawdown = 0.0
    float peak = returns[0]
    float sharpe = 0.0
    int wins = 0
    
    for i = 1 to array.size(returns) - 1
        // 计算收益
        total_return += returns[i] - returns[i-1]
        
        // 计算最大回撤
        peak := math.max(peak, returns[i])
        max_drawdown := math.max(max_drawdown, peak - returns[i])
        
        // 计算胜率
        if returns[i] > returns[i-1]
            wins += 1
            
    float win_rate = float(wins) / float(array.size(returns) - 1)
    float returns_std = ta.stdev(returns, array.size(returns))
    sharpe := returns_std != 0 ? total_return / returns_std : 0
    
    // 计算适应度
    float fitness = returnsWeight * total_return + 
                   drawdownWeight * (1.0 / (1.0 + max_drawdown)) +
                   sharpeWeight * sharpe +
                   winrateWeight * win_rate
    fitness

initialize_population() =>
    var chromosome[] population = array.new<chromosome>()
    for i = 0 to populationSize - 1
        ch = chromosome.new()
        ch.atr_length := math.random(10, 50)
        ch.min_mult := math.random(1, 3)
        ch.max_mult := math.random(3, 10)
        ch.step := 0.1 + math.random() * 0.9
        ch.perf_alpha := 2 + math.random() * 18
        array.push(population, ch)
    population

select_parent(chromosome[] population) =>
    float total_fitness = 0.0
    for ch in population
        total_fitness += ch.fitness
    
    float r = math.random() * total_fitness
    float current_sum = 0.0
    
    for ch in population
        current_sum += ch.fitness
        if current_sum >= r
            ch
    population[array.size(population) - 1]

crossover(chromosome p1, chromosome p2) =>
    chromosome c1 = chromosome.new()
    chromosome c2 = chromosome.new()
    
    if math.random() > 0.5
        c1.atr_length := p1.atr_length
        c1.min_mult := p1.min_mult
        c1.max_mult := p2.max_mult
        c1.step := p2.step
        c1.perf_alpha := p1.perf_alpha
        
        c2.atr_length := p2.atr_length
        c2.min_mult := p2.min_mult
        c2.max_mult := p1.max_mult
        c2.step := p1.step
        c2.perf_alpha := p2.perf_alpha
    else
        c1.atr_length := p2.atr_length
        c1.min_mult := p1.min_mult
        c1.max_mult := p1.max_mult
        c1.step := p2.step
        c1.perf_alpha := p1.perf_alpha
        
        c2.atr_length := p1.atr_length
        c2.min_mult := p2.min_mult
        c2.max_mult := p2.max_mult
        c2.step := p1.step
        c2.perf_alpha := p2.perf_alpha
    [c1, c2]

mutate(chromosome ch) =>
    if math.random() < mutationRate
        param = math.random(1, 5)
        if param == 1
            ch.atr_length := math.random(10, 50)
        else if param == 2
            ch.min_mult := math.random(1, 3)
        else if param == 3
            ch.max_mult := math.random(3, 10)
        else if param == 4
            ch.step := 0.1 + math.random() * 0.9
        else
            ch.perf_alpha := 2 + math.random() * 18

// 在策略开始时运行优化
var chromosome best_chromosome = na

if useOptimizedParams and barstate.isfirst
    var chromosome[] population = initialize_population()
    var float[] historical_returns = request.security(syminfo.tickerid, timeframe.period, close, 1000)
    
    // 运行遗传算法
    for generation = 1 to maxGenerations
        // 计算适应度
        for ch in population
            ch.fitness := calculate_fitness(ch, historical_returns)
        
        // 排序并保留精英
        array.sort(population, (a, b) => b.fitness - a.fitness)
        var chromosome[] new_population = array.copy(array.slice(population, 0, eliteSize))
        
        // 生成新一代
        while array.size(new_population) < populationSize
            chromosome p1 = select_parent(population)
            chromosome p2 = select_parent(population)
            
            if math.random() < crossoverRate
                [c1, c2] = crossover(p1, p2)
                mutate(c1)
                mutate(c2)
                array.push(new_population, c1)
                if array.size(new_population) < populationSize
                    array.push(new_population, c2)
            else
                array.push(new_population, p1)
                if array.size(new_population) < populationSize
                    array.push(new_population, p2)
        
        population := new_population
    
    best_chromosome := population[0]
    
    // 使用最优参数
    length := best_chromosome.atr_length
    minMult := best_chromosome.min_mult
    maxMult := best_chromosome.max_mult
    step := best_chromosome.step
    perfAlpha := best_chromosome.perf_alpha
