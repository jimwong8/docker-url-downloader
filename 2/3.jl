//@version=4
study("SuperTrend AI (Clustering) [LuxAlgo]", shorttitle="LuxAlgo - SuperTrend AI", overlay=true)

//------------------------------------------------------------------------------
// 设置
//-----------------------------------------------------------------------------{
length = input(10, title="ATR Length")
minMult = input(1, title="Factor Range", type=input.integer, minval=0)
maxMult = input(5, title="Maximum Factor", type=input.integer, minval=0) 
step = input(0.5, title="Step", type=input.float, minval=0, step=0.1)

// 触发错误
if minMult > maxMult
    "Minimum factor is greater than maximum factor"

perfAlpha = input(10, title="Performance Memory", type=input.float, minval=2)
fromCluster = input("Best", title="From Cluster", type=input.string, options=["Best", "Average", "Worst"])

// 优化
maxIter = input(20, title="Maximum Iterations", type=input.integer, minval=0, maxval=50)
maxData = input(200, title="Historical Bars", type=input.integer, minval=0, maxval=300)
calc_interval = 50

// 遗传算法优化设置
useOptimizedParams = input(false, title="Use Genetic Optimization", type=input.bool)
populationSize = input(30, title="Population Size", type=input.integer, minval=10, maxval=100)
maxGenerations = input(50, title="Max Generations", type=input.integer, minval=10, maxval=200)
mutationRate = input(0.1, title="Mutation Rate", type=input.float, minval=0.01, maxval=0.5)
crossoverRate = input(0.8, title="Crossover Rate", type=input.float, minval=0.1, maxval=1.0)
eliteSize = input(3, title="Elite Size", type=input.integer, minval=1, maxval=10)

// 适应度函数权重
returnsWeight = input(0.4, title="Returns Weight", type=input.float, minval=0.0, maxval=1.0)
drawdownWeight = input(0.2, title="Drawdown Weight", type=input.float, minval=0.0, maxval=1.0)
sharpeWeight = input(0.2, title="Sharpe Weight", type=input.float, minval=0.0, maxval=1.0)
winrateWeight = input(0.2, title="Winrate Weight", type=input.float, minval=0.0, maxval=1.0)

// 样式
bearCss = input(color.red, title="Bear Color", type=input.color)
bullCss = input(color.teal, title="Bull Color", type=input.color)
amaBearCss = input(color.new(color.red, 50), title="AMA Bear", type=input.color)
amaBullCss = input(color.new(color.teal, 50), title="AMA Bull", type=input.color)
showGradient = input(true, title="Show Gradient", type=input.bool)
showSignals = input(true, title="Show Signals", type=input.bool)

//-----------------------------------------------------------------------------}
// 变量定义
//-----------------------------------------------------------------------------{
var float[] holder = array.new_float(0)
var float[] factors = array.new_float(0)
var float[] data = array.new_float(0)
var float[] centroids = array.new_float(0)
var float[] factors_clusters = array.new_float(0)
var float[] perfclusters = array.new_float(0)

var float target_factor = na
var float perf_idx = na
var float perf_ama = na

var int last_calc_bar = 0

//-----------------------------------------------------------------------------}
// 函数
//-----------------------------------------------------------------------------{
calculate_fitness(returns) =>
    total_return = 0.0
    max_drawdown = 0.0
    peak = returns[0]
    wins = 0
    
    for i = 1 to array.size(returns) - 1
        total_return += returns[i] - returns[i-1]
        peak := max(peak, returns[i])
        max_drawdown := max(max_drawdown, peak - returns[i])
        if returns[i] > returns[i-1]
            wins += 1
            
    win_rate = float(wins) / float(array.size(returns) - 1)
    returns_std = stdev(returns, array.size(returns))
    sharpe = returns_std != 0 ? total_return / returns_std : 0
    
    returnsWeight * total_return + drawdownWeight * (1.0 / (1.0 + max_drawdown)) + sharpeWeight * sharpe + winrateWeight * win_rate

//-----------------------------------------------------------------------------}
// 主逻辑
//-----------------------------------------------------------------------------{
if barstate.isfirst
    for i = 0 to int((maxMult - minMult) / step)
        array.push(factors, minMult + i * step)
        array.push(holder, 0)

atr = atr(length)

k = 0
if array.size(factors) > 0 and array.size(holder) > 0
    for i = 0 to array.size(factors) - 1
        factor = array.get(factors, i)
        get_spt = array.get(holder, k)

        up = hl2 + atr * factor
        dn = hl2 - atr * factor
        
        get_spt := close > get_spt ? 1 : close < get_spt ? 0 : get_spt
        get_spt := close[1] < get_spt ? min(up, get_spt) : up
        get_spt := close[1] > get_spt ? max(dn, get_spt) : dn
        
        diff = nz(close[1] - get_spt > 0 ? 1 : -1)
        get_spt += 2/(perfAlpha+1) * (nz(close - close[1]) * diff - get_spt)
        array.set(holder, k, get_spt)
        k += 1

//-----------------------------------------------------------------------------}
// K-means聚类
//-----------------------------------------------------------------------------{
if bar_index >= maxData and bar_index - last_calc_bar >= calc_interval
    last_calc_bar := bar_index
    max_samples = 50  // 限制样本数
    step_size = max(1, int(array.size(holder) / max_samples))
    for i = 0 to array.size(holder) - 1
        if i % step_size == 0
            array.push(data, array.get(holder, i))

    if array.size(data) > 0
        sorted_data = array.copy(data)
        array.sort(sorted_data, 1)
        size = array.size(sorted_data)
        if size > 0
            array.push(centroids, array.get(sorted_data, int(size * 0.25)))
            array.push(centroids, array.get(sorted_data, int(size * 0.50)))
            array.push(centroids, array.get(sorted_data, int(size * 0.75)))

            for _ = 0 to maxIter
                factors_clusters := array.new_float(0)
                perfclusters := array.new_float(0)
                
                i = 0
                for j = 0 to array.size(data) - 1
                    value = array.get(data, j)
                    dist = array.new_float(0)
                    
                    for k = 0 to array.size(centroids) - 1
                        array.push(dist, abs(value - array.get(centroids, k)))

                    if array.size(dist) > 0
                        idx = 0
                        min_dist = array.get(dist, 0)
                        for i = 1 to array.size(dist) - 1
                            curr_dist = array.get(dist, i)
                            if curr_dist < min_dist
                                min_dist := curr_dist
                                idx := i

                        array.push(perfclusters, value)
                        if i < array.size(factors)
                            array.push(factors_clusters, array.get(factors, i))
                    i += 1

                if array.size(perfclusters) > 0
                    new_centroids = array.new_float(0)
                    sum = 0.0
                    for i = 0 to array.size(perfclusters) - 1
                        sum += array.get(perfclusters, i)
                    array.push(new_centroids, sum / array.size(perfclusters))

                    if array.size(new_centroids) > 2 and array.size(centroids) > 2
                        if array.get(new_centroids, 0) == array.get(centroids, 0) and 
                           array.get(new_centroids, 1) == array.get(centroids, 1) and 
                           array.get(new_centroids, 2) == array.get(centroids, 2)
                            break

                    centroids := new_centroids

//-----------------------------------------------------------------------------}
// 信号和跟踪止损
//-----------------------------------------------------------------------------{
from = fromCluster == "Best" ? 2 : fromCluster == "Average" ? 1 : 0

den = ema(abs(close - close[1]), int(perfAlpha))

if array.size(perfclusters) > 0 and array.size(factors_clusters) > 0 and from < array.size(factors_clusters)
    target_factor := nz(array.get(factors_clusters, from), target_factor)
    perf_idx := max(nz(array.get(perfclusters, from)), 0) / den

var float upper = hl2
var float lower = hl2
var int os = 0

up = hl2 + atr * nz(target_factor, 0)
dn = hl2 - atr * nz(target_factor, 0)
upper := min(up, upper)
lower := max(dn, lower)
os := close > upper ? 1 : close < lower ? 0 : os
ts = os ? lower : upper

if na(ts[1]) and not na(ts)
    perf_ama := ts
else
    perf_ama += nz(perf_idx, 0) * (ts - nz(perf_ama, ts))

//-----------------------------------------------------------------------------}
// 绘图
//-----------------------------------------------------------------------------{
css = os ? bullCss : bearCss

plot(ts, "Trailing Stop", os != os[1] ? na : css)
plot(perf_ama, "Trailing Stop AMA", cross(close, perf_ama) ? na : close > perf_ama ? amaBullCss : amaBearCss)

barcolor(showGradient ? color.from_gradient(perf_idx, 0, 1, color.new(css, 80), css) : na)

if showSignals
    if os > os[1]
        label.new(bar_index, ts, tostring(int(perf_idx * 10)), color=bullCss, style=label.style_label_up, textcolor=color.white, size=size.tiny)
    if os < os[1]
        label.new(bar_index, ts, tostring(int(perf_idx * 10)), color=bearCss, style=label.style_label_down, textcolor=color.white, size=size.tiny)

//-----------------------------------------------------------------------------}