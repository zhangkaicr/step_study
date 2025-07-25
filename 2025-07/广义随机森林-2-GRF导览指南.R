library(tidyverse)
library(grf)

rm(list = ls())
# 注意：直接从GitHub读取文件需要使用raw.githubusercontent.com
# 我们需要修改URL以指向原始文件
# 文件原始目录：https://github.com/grf-labs/grf/blob/master/r-package/grf/vignettes/data/bruhn2016.csv

data <- read_csv("https://raw.githubusercontent.com/grf-labs/grf/master/r-package/grf/vignettes/data/bruhn2016.csv")
head(data)
colnames(data)

# 从数据中提取结果变量
Y <- data$outcome.test.score
# 从数据中提取处理变量
W <- data$treatment
# 从数据中提取学校变量
school <- data$school
# 从数据中移除前3列，获取特征变量
X <- data[-(1:3)]

# 大约30%的数据存在一个或多个缺失的协变量，处理组和对照组之间的缺失模式似乎没有系统性差异，
# 由于广义随机森林(GRF)支持对存在缺失值的特征变量进行划分，因此我们将这些数据保留在分析中。
# 计算特征变量中包含缺失值的行数占比
sum(!complete.cases(X)) / nrow(X)

# 进行t检验，查看处理组和是否有缺失值之间是否存在显著差异
t.test(W ~ !complete.cases(X))


# 使用 causal_forest 函数训练因果森林模型
# X 为特征变量，使用之前从数据中移除前3列后得到的特征数据
# Y 为结果变量，即数据中的 outcome.test.score 列
# W 为处理变量，即数据中的 treatment 列
# W.hat 为处理分配概率的估计值，这里设置为 0.5
# clusters 为聚类变量，使用数据中的 school 列
cf <- causal_forest(X = X, Y = Y, W = W, W.hat = 0.5, clusters = school)
cf 

# 计算平均处理效应（Average Treatment Effect, ATE）
ate <- average_treatment_effect(cf)
# 输出平均处理效应的结果
ate["estimate"]/sd(Y)
# 0.3为金标准

# 计算因果森林模型中各特征变量的重要性
varimp <- variable_importance(cf)
# 对变量重要性进行降序排序，获取排序后的变量索引
ranked.vars <- order(varimp, decreasing = TRUE)

# 根据变量重要性排序，选取前5个最重要的变量
colnames(X)[ranked.vars[1:5]]


# 使用前5个最重要的特征变量，对因果森林模型进行最佳线性投影
best_linear_projection(cf, X[ranked.vars[1:5]])



# 按学校对样本进行分组，将样本索引按照学校变量进行分割
samples.by.school <- split(seq_along(school), school)
# 计算学校的数量
num.schools <- length(samples.by.school)
# 随机抽取一半的学校，将这些学校对应的样本索引合并为训练集
train <- unlist(samples.by.school[sample(1:num.schools, num.schools / 2)])
# 使用训练集数据训练因果森林模型
train.forest <- causal_forest(X[train, ], Y[train], W[train], W.hat = 0.5, clusters = school[train])
# 使用训练好的因果森林模型对非训练集数据进行预测，获取条件平均处理效应（CATE）的预测值
tau.hat.eval <- predict(train.forest, X[-train, ])$predictions

# 使用非训练集数据训练另一个因果森林模型
eval.forest <- causal_forest(X[-train, ], Y[-train], W[-train], W.hat = 0.5, clusters = school[-train])

# 基于评估森林模型和预测的 CATE 值，计算排序后的平均处理效应
rate.cate <- rank_average_treatment_effect(eval.forest, tau.hat.eval)
# 绘制排序后的平均处理效应图，图标题为 "TOC: By decreasing estimated CATE"
plot(rate.cate, main = "TOC: By decreasing estimated CATE")
# 输出排序后的平均处理效应结果
rate.cate


# 由于我们要基于某个协变量计算排序平均处理效应(RATE)，因此使用在全量数据上训练好的森林模型
rate.fin.index <- rank_average_treatment_effect(
  cf,
  -1 * X$financial.autonomy.index, # 乘以 -1 以便按指数降序排序
  subset = !is.na(X$financial.autonomy.index) # 忽略 X 中值为缺失的数据
  )
# 绘制排序平均处理效应图，设置 x 轴标签为 "处理比例"，y 轴标签为 "测试分数提升"，图标题为 "TOC: 按财务自主权增加排序"
plot(rate.fin.index, xlab = "Treated fraction", ylab = "Increase in test scores", main = "TOC: By increasing financial autonomy")



# 加载 policytree 包，该包用于拟合策略树模型
library(policytree)
# install.packages("policytree")



# 利用上面已经划分好的训练集和评估集（按学校划分），但仅选取特征变量无缺失值的样本用于策略树建模
# 获取评估集的样本索引，即从全部样本索引中排除训练集的索引
eval <- (1:nrow(X))[-train]
# 找出特征变量 X 中所有无缺失值的样本的索引
not.missing <- which(complete.cases(X))
# 筛选训练集，仅保留特征变量无缺失值的样本索引
train <- train[which(train %in% not.missing)]
# 筛选评估集，仅保留特征变量无缺失值的样本索引
eval <- eval[which(eval %in% not.missing)]

# 计算双重稳健分数（doubly robust scores），用于后续策略树的奖励计算
dr.scores <- get_scores(cf)
# 将之前计算得到的平均处理效应（ATE）作为项目处理的 “成本”，以找到有意义的策略
cost <- ate[["estimate"]]
# 计算控制组和处理组的奖励，控制组奖励为负的双重稳健分数，处理组奖励为双重稳健分数减去成本
dr.rewards <- cbind(control=-dr.scores, treat=dr.scores - cost)

# 在训练子集上拟合深度为 2 的策略树模型，设置每个叶子节点的最小样本量为 100
tree <- policy_tree(X[train, ], dr.rewards[train, ], min.node.size = 100)
# 绘制拟合好的策略树，为叶子节点添加标签，分别表示 “不处理” 和 “处理”
plot(tree, leaf.labels = c("dont treat", "treat"))


# 对评估集数据使用策略树模型进行预测，并将预测结果减 1，得到处理策略的预测值
pi.hat <- predict(tree, X[eval,]) - 1
# 计算评估集上基于预测策略的平均奖励，其中 dr.scores[eval] 为评估集的双重稳健分数，cost 为项目处理成本
mean((dr.scores[eval] - cost) * (2*pi.hat - 1))

# 预测评估集样本所在的叶子节点ID
leaf.node <- predict(tree, X[eval, ], type = "node.id")
# 按叶子节点分组，获取每个叶子节点对应的处理策略（唯一值）
action.by.leaf <- unlist(lapply(split(pi.hat, leaf.node), unique))

# 定义一个函数来计算每个叶子节点的统计摘要
# 输入：某个叶子节点对应的双重稳健分数减去成本的值
# 输出：包含平均处理效应减去成本、标准误差和样本量的向量
leaf_stats <- function(leaf) {
  c(ATE.minus.cost = mean(leaf), std.err = sd(leaf) / sqrt(length(leaf)), size = length(leaf))
}

# 合并处理策略规则和按叶子节点分组计算的统计摘要
cbind(
  # 根据处理策略的值，给出对应的处理规则
  rule = ifelse(action.by.leaf == 0, "dont treat", "treat"),
  # 按叶子节点分组，对评估集的双重稳健分数减去成本的值应用统计摘要函数
  aggregate(dr.scores[eval] - cost, by = list(leaf.node = leaf.node),
            FUN = leaf_stats)
)

# 拟合深度为 1 的策略树模型，设置每个叶子节点的最小样本量为 100
tree.depth1 <- policy_tree(X[train, ], dr.rewards[train, ], depth = 1, min.node.size = 100)
# 对评估集数据使用深度为 1 的策略树模型进行预测，并将预测结果减 1，得到处理策略的预测值
pi.hat.eval <- predict(tree.depth1, X[eval, ]) - 1

# 从评估集中筛选出预测应进行处理的样本索引
treat.eval <- eval[pi.hat.eval == 1]
# 从评估集中筛选出预测不应进行处理的样本索引
dont.treat.eval <- eval[pi.hat.eval == 0]

# 计算预测应进行处理的样本子集的平均处理效应
average_treatment_effect(cf, subset = treat.eval)
#> estimate  std.err 
#>      3.9      0.8
# 计算预测不应进行处理的样本子集的平均处理效应
average_treatment_effect(cf, subset = dont.treat.eval)
#> estimate  std.err 
#>      1.8      2.3

################################## ex2 ####################################
rm(list = ls())
# 使用 read_csv 函数读取数据，与文件中其他部分保持一致
data <- read_csv("https://raw.githubusercontent.com/grf-labs/grf/master/r-package/grf/vignettes/data/carvalho2016.csv")
glimpse(data)

# 从数据中提取结果变量
Y <- data$outcome.num.correct.ans
# 从数据中提取处理变量
W <- data$treatment
# 从数据中移除前4列，获取特征变量
X <- data[-(1:4)]

# 使用回归森林模型预测处理变量 W，设置树的数量为 500
rf <- regression_forest(X, W, num.trees = 500)
# 获取回归森林模型的预测结果
p.hat <- predict(rf)$predictions
# 绘制预测结果的直方图，直观展示预测值的分布
hist(p.hat, main = "回归森林预测值分布", xlab = "预测值", ylab = "频数")


# 使用回归森林模型对结果变量 Y 进行预测
Y.forest <- regression_forest(X, Y, num.trees = 500)
# 获取回归森林模型的预测结果
Y.hat <- predict(Y.forest)$predictions

# 计算回归森林模型中各特征变量的重要性
varimp.Y <- variable_importance(Y.forest)

# 保留变量重要性排名前10的变量，用于后续的条件平均处理效应（CATE）估计
keep <- colnames(X)[order(varimp.Y, decreasing = TRUE)[1:10]]
# 输出保留的变量名
print(keep)


# 选取变量重要性排名前10的变量构建新特征矩阵
X.cf <- X[, keep]
# 设置处理分配概率的估计值为0.5
W.hat <- 0.5

# 预留前半部分数据用于训练，后半部分用于评估
# （注意：根据预留用于训练/评估的样本不同，结果可能会发生变化）
train <- 1:(nrow(X.cf) / 2)

# 使用训练集数据训练因果森林模型，并传入结果变量和处理变量的预测值
train.forest <- causal_forest(X.cf[train, ], Y[train], W[train], Y.hat = Y.hat[train], W.hat = W.hat)
# 使用训练好的因果森林模型对评估集数据进行预测，获取条件平均处理效应（CATE）的预测值
tau.hat.eval <- predict(train.forest, X.cf[-train, ])$predictions

# 使用评估集数据训练另一个因果森林模型，并传入结果变量和处理变量的预测值
eval.forest <- causal_forest(X.cf[-train, ], Y[-train], W[-train], Y.hat = Y.hat[-train], W.hat = W.hat)

average_treatment_effect(eval.forest)
average_treatment_effect(train.forest)


# 计算评估集因果森林模型中各特征变量的重要性
varimp <- variable_importance(eval.forest)
# 对变量重要性进行降序排序，获取排序后的变量索引
ranked.vars <- order(varimp, decreasing = TRUE)
# 根据变量重要性排序，选取前5个最重要的变量并输出其名称
colnames(X.cf)[ranked.vars[1:5]]


# 基于评估森林模型和负的预测 CATE 值，计算排序后的平均处理效应
# 乘以 -1 是为了按 CATE 值从最负到最正排序
rate.cate <- rank_average_treatment_effect(eval.forest, list(cate = -1 *tau.hat.eval))
# 基于评估森林模型和年龄变量，计算按年龄排序后的平均处理效应
rate.age <- rank_average_treatment_effect(eval.forest, list(age = X[-train, "age"]))

# 设置绘图布局为一行两列
par(mfrow = c(1, 2))
# 绘制按最负 CATE 值排序的平均处理效应图
plot(rate.cate, ylab = "Number of correct answers", main = "TOC: By most negative CATEs")
# 绘制按年龄降序排序的平均处理效应图
plot(rate.age, ylab = "Number of correct answers", main = "TOC: By decreasing age")
