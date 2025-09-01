# 遗传算法优化器
struct Chromosome
    atr_length::Int
    min_mult::Int  
    max_mult::Int
    step::Float64
    perf_alpha::Float64
    fitness::Float64
end

struct GeneticOptimizer
    population_size::Int
    max_generations::Int
    mutation_rate::Float64
    crossover_rate::Float64
    elite_size::Int
    chromosomes::Vector{Chromosome}
end

function initialize_population(size::Int)
    population = Vector{Chromosome}()
    for i in 1:size
        # 随机生成参数,范围参考之前建议
        chromosome = Chromosome(
            rand(10:50),  # atr_length
            rand(1:3),    # min_mult
            rand(3:10),   # max_mult
            rand() * 0.9 + 0.1,  # step (0.1-1.0)
            rand() * 18 + 2,     # perf_alpha (2-20)
            0.0  # 初始适应度为0
        )
        push!(population, chromosome)
    end
    return population
end

function calculate_fitness(chromosome::Chromosome, price_data)
    # 使用参数运行策略回测
    returns, max_drawdown, sharpe_ratio, win_rate = backtest_strategy(
        price_data,
        chromosome.atr_length,
        chromosome.min_mult,
        chromosome.max_mult,
        chromosome.step,
        chromosome.perf_alpha
    )
    
    # 计算适应度
    w1, w2, w3, w4 = 0.4, 0.2, 0.2, 0.2  # 权重
    fitness = w1 * returns + w2 * (1/max_drawdown) + w3 * sharpe_ratio + w4 * win_rate
    return fitness
end

function select_parents(population::Vector{Chromosome})
    # 轮盘赌选择
    total_fitness = sum(c.fitness for c in population)
    r = rand() * total_fitness
    current_sum = 0.0
    
    for chromosome in population
        current_sum += chromosome.fitness
        if current_sum >= r
            return chromosome
        end
    end
    
    return population[end]
end

function crossover(parent1::Chromosome, parent2::Chromosome)
    # 单点交叉
    if rand() > 0.5
        child1 = Chromosome(parent1.atr_length, parent1.min_mult, parent2.max_mult, 
                          parent2.step, parent1.perf_alpha, 0.0)
        child2 = Chromosome(parent2.atr_length, parent2.min_mult, parent1.max_mult,
                          parent1.step, parent2.perf_alpha, 0.0)
    else
        child1 = Chromosome(parent2.atr_length, parent1.min_mult, parent1.max_mult,
                          parent2.step, parent1.perf_alpha, 0.0)
        child2 = Chromosome(parent1.atr_length, parent2.min_mult, parent2.max_mult,
                          parent1.step, parent2.perf_alpha, 0.0)
    end
    return child1, child2
end

function mutate!(chromosome::Chromosome, mutation_rate::Float64)
    if rand() < mutation_rate
        # 随机选择一个参数进行变异
        param = rand(1:5)
        if param == 1
            chromosome.atr_length = rand(10:50)
        elseif param == 2
            chromosome.min_mult = rand(1:3)
        elseif param == 3
            chromosome.max_mult = rand(3:10)
        elseif param == 4
            chromosome.step = rand() * 0.9 + 0.1
        else
            chromosome.perf_alpha = rand() * 18 + 2
        end
    end
end

function optimize(optimizer::GeneticOptimizer, price_data)
    for generation in 1:optimizer.max_generations
        # 计算适应度
        for chromosome in optimizer.chromosomes
            chromosome.fitness = calculate_fitness(chromosome, price_data)
        end
        
        # 排序并保留精英
        sort!(optimizer.chromosomes, by = c -> c.fitness, rev = true)
        elite = optimizer.chromosomes[1:optimizer.elite_size]
        
        # 生成新一代
        new_population = copy(elite)
        while length(new_population) < optimizer.population_size
            # 选择父代
            parent1 = select_parents(optimizer.chromosomes)
            parent2 = select_parents(optimizer.chromosomes)
            
            # 交叉
            if rand() < optimizer.crossover_rate
                child1, child2 = crossover(parent1, parent2)
                
                # 变异
                mutate!(child1, optimizer.mutation_rate)
                mutate!(child2, optimizer.mutation_rate)
                
                push!(new_population, child1)
                if length(new_population) < optimizer.population_size
                    push!(new_population, child2)
                end
            else
                push!(new_population, parent1)
                if length(new_population) < optimizer.population_size
                    push!(new_population, parent2)
                end
            end
        end
        
        optimizer.chromosomes = new_population
        
        # 输出当前最优解
        println("Generation $generation best fitness: $(optimizer.chromosomes[1].fitness)")
    end
    
    return optimizer.chromosomes[1]  # 返回最优参数组合
end 