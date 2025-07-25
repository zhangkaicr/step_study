# install.packages("grf")


library(grf)

# 生成数据
# 设置样本数量为2000，即数据集中包含2000个观测值
n <- 2000
# 设置特征数量为10，即每个观测值由10个特征组成
p <- 10
# 生成一个n行p列的矩阵X，矩阵中的元素服从标准正态分布（均值为0，标准差为1）
# 这里使用rnorm函数生成n * p个随机数，然后将其排列成n行p列的矩阵
X <- matrix(rnorm(n * p), n, p)

# 生成一个用于测试的矩阵X.test，该矩阵有101行p列，初始所有元素都设为0
X.test <- matrix(0, 101, p)
# 将X.test矩阵的第一列元素设置为从-2到2的等间距数值，共101个
X.test[, 1] <- seq(-2, 2, length.out = 101)

# 生成一个长度为n的二元变量W，它表示每个观测值的处理状态（例如是否接受某种处理）
# rbinom函数用于生成二项分布的随机数，试验次数为1，成功概率为0.4 + 0.2 * (X[, 1] > 0)
# 即当X矩阵第一列的元素大于0时，成功概率为0.6；否则为0.4
W <- rbinom(n, 1, 0.4 + 0.2 * (X[, 1] > 0))

# 生成响应变量Y，它是根据以下规则计算得到的：
# 1. pmax(X[, 1], 0) * W：取X矩阵第一列元素与0的较大值，再乘以处理状态W
# 2. X[, 2]：加上X矩阵第二列的元素
# 3. pmin(X[, 3], 0)：加上X矩阵第三列元素与0的较小值
# 4. rnorm(n)：最后加上n个服从标准正态分布的随机噪声
Y <- pmax(X[, 1], 0) * W + X[, 2] + pmin(X[, 3], 0) + rnorm(n)

head(X)
head(Y)
head(W)


# 使用 causal_forest 函数训练因果森林模型
# X：特征矩阵，包含所有观测样本的特征数据
# Y：响应变量，即模型的输出结果
# W：处理状态变量，指示每个样本是否接受处理
# num.trees = 2000：设置因果森林中树的数量为2000棵
# min.node.size = 5：设置每个节点的最小样本数量为5
# honesty = TRUE：开启 honesty 方法
# honesty.fraction = 0.9：设置 honesty 方法中用于训练模型的样本比例为0.9
tau.forest <- causal_forest(
  X,          # 特征矩阵，包含所有观测样本的特征数据
  Y,          # 响应变量，即模型的输出结果
  W,          # 处理状态变量，指示每个样本是否接受处理
  num.trees = 2000,  # 设置因果森林中树的数量为2000棵
  min.node.size = 5, # 设置每个节点的最小样本数量为5
  honesty = TRUE,    # 开启 honesty 方法
  honesty.fraction = 0.9  # 设置 honesty 方法中用于训练模型的样本比例为0.9
)

tau.forest


# 使用袋外预测估计训练数据的处理效应
tau.hat.oob <- predict(tau.forest)
hist(tau.hat.oob$predictions)
dim(tau.hat.oob)
head(tau.hat.oob)



# 估计测试样本的处理效应
# 查看测试矩阵X.test的前几行，用于检查数据的基本结构和内容
head(X.test)
# 查看测试矩阵X.test的数据类型，确认其为矩阵类型
class(X.test)

# 使用训练好的因果森林模型tau.forest对测试数据X.test进行预测，得到处理效应的估计值
tau.hat <- predict(tau.forest, X.test)
# 绘制测试数据第一列特征与预测处理效应的关系图
# ylim设置y轴的范围，包含预测值、0和2中的最小值与最大值
# xlab和ylab分别设置x轴和y轴的标签
# type = "l"表示绘制折线图
plot(X.test[, 1], tau.hat$predictions, ylim = range(tau.hat$predictions, 0, 2), xlab = "x", ylab = "tau", type = "l")
# 在已有的图上添加一条新的折线
# 该折线表示X.test第一列元素与0的较大值
# col = 2表示折线颜色为红色（R中2代表红色）
# lty = 2表示折线类型为虚线
lines(X.test[, 1], pmax(0, X.test[, 1]), col = 2, lty = 2)


# 估计全样本的条件平均处理效应（CATE）
average_treatment_effect(tau.forest, target.sample = "all")

# 估计处理样本的条件平均处理效应（CATT）
average_treatment_effect(tau.forest, target.sample = "treated")


# 为异质处理效应添加置信区间；现在建议增加树的数量。
# 重新训练因果森林模型，将树的数量增加到4000棵，以提高模型的稳定性和预测精度
tau.forest <- causal_forest(X, Y, W, num.trees = 4000)
# 对测试数据进行预测，并设置 estimate.variance = TRUE 以估计预测值的方差
# 这样可以得到每个预测值对应的方差估计，用于后续计算置信区间
tau.hat <- predict(tau.forest, X.test, estimate.variance = TRUE)
# 计算预测值的标准差，通过对方差估计值取平方根得到
# 标准差是计算置信区间的关键参数
sigma.hat <- sqrt(tau.hat$variance.estimates)
# 绘制测试数据第一列特征与预测处理效应的关系图
# ylim 参数设置y轴的范围，包含预测值的上下置信区间边界、0和2中的最小值与最大值
# xlab 和 ylab 分别设置x轴和y轴的标签
# type = "l" 表示绘制折线图
plot(X.test[, 1], tau.hat$predictions, ylim = range(tau.hat$predictions + 1.96 * sigma.hat, tau.hat$predictions - 1.96 * sigma.hat, 0, 2), xlab = "x", ylab = "tau", type = "l")
# 在已有的图上添加预测值的上置信区间折线
# 置信区间为预测值加上1.96倍的标准差（对应95%置信水平）
# col = 1 表示折线颜色为黑色，lty = 2 表示折线类型为虚线
lines(X.test[, 1], tau.hat$predictions + 1.96 * sigma.hat, col = 1, lty = 2)
# 在已有的图上添加预测值的下置信区间折线
# 置信区间为预测值减去1.96倍的标准差（对应95%置信水平）
# col = 1 表示折线颜色为黑色，lty = 2 表示折线类型为虚线
lines(X.test[, 1], tau.hat$predictions - 1.96 * sigma.hat, col = 1, lty = 2)
# 在已有的图上添加一条新的折线
# 该折线表示X.test第一列元素与0的较大值
# col = 2 表示折线颜色为红色，lty = 1 表示折线类型为实线
lines(X.test[, 1], pmax(0, X.test[, 1]), col = 2, lty = 1)


# 加载所需库
library(ggplot2)
library(dplyr)

# 准备绘图数据
data_plot <- tibble(
  x = X.test[, 1],
  predictions = tau.hat$predictions,
  upper_ci = tau.hat$predictions + 1.96 * sigma.hat,
  lower_ci = tau.hat$predictions - 1.96 * sigma.hat,
  theoretical = pmax(0, X.test[, 1])
)

# 使用ggplot2绘制图形
ggplot(data_plot, aes(x = x)) +
  # 添加预测值曲线
  geom_line(aes(y = predictions), color = "black") +
  # 添加置信区间曲线
  geom_line(aes(y = upper_ci), color = "black", linetype = "dashed") +
  geom_line(aes(y = lower_ci), color = "black", linetype = "dashed") +
  # 添加理论值曲线
  geom_line(aes(y = theoretical), color = "red") +
  # 设置坐标轴标签
  labs(x = "x", y = "tau") +
  # 设置y轴范围与原plot保持一致
  ylim(range(data_plot$upper_ci, data_plot$lower_ci, 0, 2)) +
  # 使用经典主题，接近基础plot的外观
  theme_classic()


# 生成新数据
# 设置样本数量为4000，即数据集中包含4000个观测值
n <- 4000
# 设置特征数量为20，即每个观测值由20个特征组成
p <- 20
# 生成一个n行p列的矩阵X，矩阵中的元素服从标准正态分布（均值为0，标准差为1）
X <- matrix(rnorm(n * p), n, p)
# 计算处理效应TAU，使用X矩阵第三列元素通过sigmoid函数转换得到
TAU <- 1 / (1 + exp(-X[, 3]))
# 生成一个长度为n的二元变量W，它表示每个观测值的处理状态
# 使用sigmoid函数基于X矩阵第一列和第二列元素之和计算成功概率，生成二项分布随机数
W <- rbinom(n, 1, 1 / (1 + exp(-X[, 1] - X[, 2])))
# 生成响应变量Y
# 1. pmax(X[, 2] + X[, 3], 0)：取X矩阵第二列与第三列元素之和与0的较大值
# 2. rowMeans(X[, 4:6]) / 2：取X矩阵第4到6列元素的行均值并除以2
# 3. W * TAU：处理状态W乘以处理效应TAU
# 4. rnorm(n)：加上n个服从标准正态分布的随机噪声
Y <- pmax(X[, 2] + X[, 3], 0) + rowMeans(X[, 4:6]) / 2 + W * TAU + rnorm(n)

head(W)
head(Y)
head(X)


# 使用 regression_forest 函数训练一个回归森林模型，用于预测处理状态变量 W
# X 为特征矩阵，包含所有观测样本的特征数据
# W 为响应变量，即每个样本的处理状态
# tune.parameters = "all" 表示自动调整所有可调整的参数以优化模型性能
forest.W <- regression_forest(X, W, tune.parameters = "all")
forest.W
# 使用训练好的回归森林模型 forest.W 对训练数据进行预测
# $predictions 用于提取预测结果，将预测得到的处理状态值存储在 W.hat 中
W.hat <- predict(forest.W)$predictions
head(W.hat)

# 使用 regression_forest 函数训练一个回归森林模型，用于预测响应变量 Y
# X 为特征矩阵，包含所有观测样本的特征数据
# Y 为响应变量，即模型的输出结果
# tune.parameters = "all" 表示自动调整所有可调整的参数以优化模型性能
forest.Y <- regression_forest(X, Y, tune.parameters = "all")

# 使用训练好的回归森林模型 forest.Y 对训练数据进行预测
# $predictions 用于提取预测结果，将预测得到的响应变量值存储在 Y.hat 中
Y.hat <- predict(forest.Y)$predictions
head(Y.hat)

# 使用 variable_importance 函数计算回归森林模型 forest.Y 中各特征变量的重要性
# 将计算得到的特征重要性结果存储在 forest.Y.varimp 中
forest.Y.varimp <- variable_importance(forest.Y)
head(forest.Y.varimp)
range(forest.Y.varimp)



# 注意：当森林在很少的变量上训练时可能会遇到困难
#（例如，ncol(X) = 1、2 或 3）。我们建议不要过于激进地进行选择

# 筛选出特征重要性大于平均重要性 0.2 倍的特征索引
selected.vars <- which(forest.Y.varimp / mean(forest.Y.varimp) > 0.2)

# 使用筛选后的特征训练因果森林模型，同时传入处理状态和响应变量的预测值，并自动调整所有参数
# X[, selected.vars]：使用筛选出的特征重要性大于平均重要性 0.2 倍的特征构建的特征矩阵
# Y：响应变量，即模型的输出结果
# W：处理状态变量，指示每个样本是否接受处理
# W.hat：处理状态变量 W 的预测值，由回归森林模型 forest.W 预测得到
# Y.hat：响应变量 Y 的预测值，由回归森林模型 forest.Y 预测得到
# tune.parameters = "all"：自动调整所有可调整的参数以优化模型性能
tau.forest <- causal_forest(X[, selected.vars], Y, W,
                            W.hat = W.hat, Y.hat = Y.hat,
                            tune.parameters = "all")

tau.forest 


# 通过绘制 TOC 并计算 AUTOC 的 95% 置信区间，查看因果森林是否成功捕捉到异质性。

# 从 1 到 n 的整数中随机抽样，抽取样本数量为 n/2，将抽样结果存储在 train 中，用于划分训练集索引
train <- sample(1:n, n / 2)

# 使用训练集索引 train 从特征矩阵 X、响应变量 Y 和处理状态变量 W 中提取对应的数据，训练一个因果森林模型
train.forest <- causal_forest(X[train, ], Y[train], W[train])
# 使用除训练集索引之外的数据（即测试集）从特征矩阵 X、响应变量 Y 和处理状态变量 W 中提取对应的数据，训练另一个因果森林模型
eval.forest <- causal_forest(X[-train, ], Y[-train], W[-train])
# 计算排序平均处理效应，使用评估森林模型 eval.forest 和训练森林模型在测试集上的预测结果
rate <- rank_average_treatment_effect(eval.forest,
                                      predict(train.forest, X[-train, ])$predictions)
# 绘制排序平均处理效应的结果
plot(rate)

# 输出 AUTOC（排序平均处理效应）的估计值及其 95% 置信区间的误差范围，结果保留两位小数
paste("AUTOC:", round(rate$estimate, 2), "+/", round(1.96 * rate$std.err, 2))

