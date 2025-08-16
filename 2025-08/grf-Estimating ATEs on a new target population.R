library(grf)
library(tidyverse)

# 定义一个函数用于估计新测试集上的平均处理效应
average_treatment_effect_test <- function(forest, X.test, p.hat = NULL) {
  # 从forest对象中提取预测值和原始值
  Y.hat <- forest$Y.hat    # 获取结果变量的预测值
  Y.orig <- forest$Y.orig  # 获取结果变量的原始值
  W.hat <- forest$W.hat    # 获取处理变量的预测值
  W.orig <- forest$W.orig  # 获取处理变量的原始值
  n.rct <- length(Y.orig)  # 计算原始数据的样本量
  n.obs <- nrow(X.test)    # 计算测试集的样本量

  # 如果没有提供p.hat，则需要估计倾向性得分
  if (is.null(p.hat)) {
    # 使用回归森林估计倾向性得分
    S.forest <- regression_forest(X = rbind(forest$X.orig, X.test),  # 合并原始特征和测试集特征
                                  Y = c(rep(1, n.rct), rep(0, n.obs)), # 构造标签
                                  num.trees = 500)  # 设置树的数量为500
    p.hat <- predict(S.forest)$predictions[1:n.rct]  # 获取原始数据的倾向性得分预测值
  }

  # 计算处理效应
  tau.hat.test <- predict(forest, X.test)$predictions  # 对测试集预测处理效应
  tau.hat.train <- predict(forest)$predictions         # 对训练集预测处理效应
  # 计算去偏权重
  debiasing.weights <- (1 - p.hat) / p.hat * (W.orig - W.hat) / (W.hat * (1 - W.hat))
  # 计算结果变量的残差
  Y.residual <- Y.orig - (Y.hat + tau.hat.train * (W.orig - W.hat))

  # 计算最终的处理效应估计值
  tau.hat <- mean(tau.hat.test) + sum(debiasing.weights * Y.residual) / n.obs
  # 计算方差估计值
  sigma2.hat <- var(tau.hat.test) / n.obs + sum(Y.residual^2 * (debiasing.weights / n.obs)^2)

  # 返回估计值和标准误
  c(estimate = tau.hat, std.err = sqrt(sigma2.hat))
}



# 设置样本量和特征维度
n <- 2000
p <- 5

# 生成总体数据矩阵，包含n个样本，每个样本p个特征
X.population <- matrix(rnorm(n * p), n, p)

# 计算试验纳入概率，使用logistic函数将第一个特征转换为概率
trial.inclusion.prob <- 1 / (1 + exp(-X.population[, 1] / 2))

# 根据纳入概率生成二元选择指标S
S <- rbinom(n, 1, trial.inclusion.prob)

# 将未被选中的样本(S=0)作为测试集
X.test <- X.population[S == 0, ]

# 将被选中的样本(S=1)作为训练集
X <- X.population[S == 1, ]

# 生成随机处理分配，概率为0.5
W <- rbinom(nrow(X), 1, 0.5)

# 定义真实处理效应，为第一个特征加1
tau <- X[, 1] + 1

# 生成观察到的结果变量
Y <- X[, 2] + tau * W + rnorm(nrow(X))

head(X.test)
head(Y)
head(W)

# 训练因果森林模型
forest <- causal_forest(X, Y, W, W.hat = 0.5)

# 在测试集上估计平均处理效应
ate.test <- average_treatment_effect_test(forest, X.test)
estimate <- ate.test[1]
std.err <- ate.test[2]

# 输出估计结果
sprintf("Estimate: %1.2f", estimate)
#> [1] "Estimate: 0.81"
sprintf("95%% CI: (%1.2f, %1.2f)", estimate - 1.96 * std.err, estimate + 1.96 * std.err)
#> [1] "95% CI: (0.66, 0.96)"
sprintf("Naive estimate: %1.2f", mean(predict(forest, X.test)$predictions))
#> [1] "Naive estimate: 0.87"
sprintf("True mean: %1.2f", mean(X.test[, 1] + 1))
#> [1] "True mean: 0.78"


# 设置样本量和特征维度
n <- 2000
p <- 5

# 生成随机特征矩阵
X <- matrix(rnorm(n * p), n, p)

# 计算选择概率
S.hat <- 1 / (1 + exp(-X[, 1] / 2))

# 根据选择概率生成二元选择指标
S <- rbinom(n, 1, S.hat)

# 生成结果变量
Y <- 1 + X[, 1] + X[, 2] + rnorm(n)

# 划分训练集和测试集
X.train <- X[S == 1, ]
Y.train <- Y[S == 1]
X.test <- X[S == 0, ]

# 构建增广数据集
X.aug <- rbind(X.train, X.test)
Y.aug <- c(Y.train, rep(0, nrow(X.test)))
W.aug <- c(rep(1, nrow(X.train)), rep(0, nrow(X.test)))

# 训练因果森林模型
cf <- causal_forest(X.aug, Y.aug, W.aug, num.trees = 500)

# 估计平均处理效应
ate <- average_treatment_effect(cf, target.sample = "control")
estimate <- ate[1]
std.err <- ate[2]

# 输出结果
sprintf("Estimate: %1.2f", estimate)
#> [1] "Estimate: 0.74"
sprintf("95%% CI: (%1.2f, %1.2f)", estimate - 1.96 * std.err, estimate + 1.96 * std.err)
#> [1] "95% CI: (0.64, 0.85)"
sprintf("True mean: %1.2f",  mean(Y[S == 0]))
#> [1] "True mean: 0.79"