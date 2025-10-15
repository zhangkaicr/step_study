library(personalized)

set.seed(123)  # 设置随机种子以保证结果可重复

n.obs  <- 1000  # 观测样本量
n.vars <- 25    # 协变量个数

# 生成协变量矩阵（服从正态分布）
x <- matrix(rnorm(n.obs * n.vars, sd = 3), n.obs, n.vars)

# 模拟非随机化治疗分配
xbetat   <- 0.5 + 0.25 * x[, 11] - 0.25 * x[, 2]
trt.prob <- exp(xbetat) / (1 + exp(xbetat))  # 治疗分配概率
trt      <- rbinom(n.obs, 1, prob = trt.prob)  # 生成治疗状态（0=对照，1=治疗）

# 模拟获益得分Δ(X)
delta <- (0.5 + x[, 2] - 0.5 * x[, 3] - 1 * x[, 11] + 1 * x[, 1] * x[, 12])

# 模拟协变量主效应g(X)
xbeta <- x[, 1] + x[, 11] - 2 * x[, 12]^2 + x[, 13] + 0.5 * x[, 15]^2
xbeta <- xbeta + delta * (2 * trt - 1)  # 加入治疗与协变量的交互效应

# 模拟连续型结局变量
y <- drop(xbeta) + rnorm(n.obs)


# 定义倾向得分模型拟合函数
prop.func <- function(x, trt) {
  # 拟合倾向得分模型（使用Lasso进行变量选择）
  propens.model <- cv.glmnet(y = trt,
                             x = x, 
                             family = "binomial")  # 二分类结局的 glmnet 模型
  
  # 基于最优λ（lambda.min）预测倾向得分
  pi.x <- predict(propens.model, s = "lambda.min",
                  newx = x, type = "response")[, 1]
  
  return(pi.x)
}

check.overlap(x, trt, prop.func)


# 拟合亚组识别模型
subgrp.model <- fit.subgroup(x = x, y = y,
                             trt = trt,
                             propensity.func = prop.func,  # 倾向得分函数
                             loss = "sq_loss_lasso",       # 带Lasso惩罚的平方误差损失
                             nfolds = 5)                   # 交叉验证折数（cv.glmnet的参数）

# 查看模型摘要
summary(subgrp.model)

plot(subgrp.model)

# 绘制交互作用图
plot(subgrp.model, type = "interaction")

# 采用训练集-测试集分割法进行验证
validation <- validate.subgroup(subgrp.model, 
                                B = 10L,  # 重复次数
                                method = "training_test_replication",  # 验证方法
                                train.fraction = 0.75)  # 训练集比例

# 查看验证结果
validation


# 绘制验证后的亚组平均结局图
plot(validation)

# 绘制验证后的交互作用图
plot(validation, type = "interaction")


# 比较模型拟合结果与验证结果
plotCompare(subgrp.model, validation, type = "interaction")

propensity.func <- function(x, trt) 0.5  # 始终返回1/2

propensity.func(x,trt)



# 生成生存时间型结局
surv.time <- exp(-20 - xbeta + rnorm(n.obs, sd = 1))  # 潜在生存时间
cens.time <- exp(rnorm(n.obs, sd = 3))                # 截尾时间
y.time.to.event <- pmin(surv.time, cens.time)         # 观测时间（取生存时间和截尾时间的最小值）
status <- 1 * (surv.time <= cens.time)                # 生存状态（1=事件发生，0=截尾）

# 加载生存分析包
library(survival)

# 拟合生存时间型结局的亚组识别模型（需将y指定为Surv对象）
set.seed(123)
subgrp.cox <- fit.subgroup(x = x, y = Surv(y.time.to.event, status),
                           trt = trt,
                           propensity.func = prop.func,
                           method = "weighting",
                           loss = "cox_loss_lasso",  # Cox损失+Lasso
                           nfolds = 5)               # cv.glmnet的交叉验证折数

# 查看模型摘要（亚组治疗效应基于限制均值统计量估计）
summary(subgrp.cox)



library(personalized)

set.seed(1)  # 设置随机种子以保证结果可重复

n.obs  <- 500  # 观测样本量
n.vars <- 10   # 协变量数量

# 生成10个协变量，服从正态分布（标准差为3）
x <- matrix(rnorm(n.obs * n.vars, sd = 3), n.obs, n.vars)

# 模拟非随机化处理分配
xbetat   <- 0.5 + 0.25 * x[,9] - 0.25 * x[,1]  # 处理分配的线性预测项
trt.prob <- exp(xbetat) / (1 + exp(xbetat))    # 处理1的分配概率（逻辑回归转换）
trt      <- rbinom(n.obs, 1, prob = trt.prob)  # 生成二元处理变量（0或1）

# 模拟处理效应修饰项delta
delta <- (0.5 + x[,2] - 0.5 * x[,3] - 1 * x[,1] + 1 * x[,1] * x[,4] )

# 模拟结果的主效应g(X)
xbeta <- 2 * x[,1] + 3 * x[,4] - 0.25 * x[,2]^2 + 2 * x[,3] + 0.25 * x[,5] ^ 2
xbeta <- xbeta + delta * (2 * trt - 1)  # 纳入处理与delta的交互效应

# 模拟连续型结果变量y（添加正态误差，标准差为3）
y <- drop(xbeta) + rnorm(n.obs, sd = 3)


# 可通过`cv.glmnet.args`向cv.glmnet函数传递参数
prop.func <- create.propensity.function(crossfit = TRUE,
                                        nfolds.crossfit = 4,  # 交叉拟合的折数
                                        cv.glmnet.args = list(type.measure = "auc", nfolds = 3))  # 评估指标为AUC，3折交叉验证


subgrp.model <- fit.subgroup(x = x, y = y,
                             trt = trt,  # 处理变量
                             propensity.func = prop.func,  # 传入倾向得分函数
                             loss   = "sq_loss_lasso",  # 损失函数：平方损失Lasso
                             nfolds = 3)  # 用于ITR估计的cv.glmnet参数

summary(subgrp.model)  # 输出模型摘要


aug.func <- create.augmentation.function(family = "gaussian",  # 结果分布族（高斯分布，适用于连续结果）
                                         crossfit = TRUE,  # 启用交叉拟合
                                         nfolds.crossfit = 4,  # 交叉拟合折数
                                         cv.glmnet.args = list(type.measure = "mae", nfolds = 3))  # 评估指标为MAE，3折交叉验证


subgrp.model.aug <- fit.subgroup(x = x, y = y,
                                 trt = trt,
                                 propensity.func = prop.func,  # 传入倾向得分函数
                                 augment.func = aug.func,  # 传入增强函数
                                 loss   = "sq_loss_lasso",
                                 nfolds = 3)  # 用于ITR估计的cv.glmnet参数

summary(subgrp.model.aug)  # 输出增强后模型的摘要


valmod <- validate.subgroup(subgrp.model, B = 3,  # 重复验证3次
                            method = "training_test",  # 验证方法：训练-测试分割
                            train.fraction = 0.75)  # 训练集占比75%
valmod  # 输出未增强模型的验证结果


valmod.aug <- validate.subgroup(subgrp.model.aug, B = 3,  # 重复验证3次
                                method = "training_test",  # 验证方法：训练-测试分割
                                train.fraction = 0.75)  # 训练集占比75%
valmod.aug  # 输出增强模型的验证结果



library(personalized)
set.seed(123)

# 设定观测数量与变量数量
n.obs  <- 250  # 观测数
n.vars <- 10   # 变量数

# 生成协变量矩阵（服从正态分布，标准差为3）
x <- matrix(rnorm(n.obs * n.vars, sd = 3), n.obs, n.vars)

# 基于多项逻辑回归模型，模拟非随机分配的多水平处理方式
xbetat_1 <- 0.1 + 0.5 * x[, 1] - 0.25 * x[, 5]  # 处理1的线性预测项
xbetat_2 <- 0.1 - 0.5 * x[, 9] + 0.25 * x[, 5]  # 处理2的线性预测项

# 计算各处理方式的分配概率
trt.1.prob <- exp(xbetat_1) / (1 + exp(xbetat_1) + exp(xbetat_2))  # 处理1的概率
trt.2.prob <- exp(xbetat_2) / (1 + exp(xbetat_1) + exp(xbetat_2))  # 处理2的概率
trt.3.prob <- 1 - (trt.1.prob + trt.2.prob)                        # 处理3的概率（概率和为1）

# 构建概率矩阵与处理方式分配矩阵
prob.mat <- cbind(trt.1.prob, trt.2.prob, trt.3.prob)  # 每行对应一个观测的各处理概率
trt.mat  <- apply(prob.mat, 1, function(rr) rmultinom(1, 1, prob = rr))  # 按概率分配处理方式（0-1矩阵）

# 将0-1矩阵转换为处理方式编号（1/2/3），并转换为因子类型
trt.num <- apply(trt.mat, 2, function(rr) which(rr == 1))  # 提取各观测的处理方式编号
trt     <- as.factor(paste0("Trt_", trt.num))              # 转换为因子（水平：Trt_1/Trt_2/Trt_3）

# 模拟响应变量（结果变量Y）
# 处理1相对于处理3的效应
delta1 <- 2 * (0.5 + x[, 2] - 2 * x[, 3])
# 处理2相对于处理3的效应
delta2 <- (0.5 + x[, 6] - 2 * x[, 5])

# 协变量的主效应（含非线性项）
xbeta <- x[, 1] + x[, 9] - 2 * x[, 4]^2 + x[, 4] + 0.5 * x[, 5]^2 + 2 * x[, 2] - 3 * x[, 5]

# 构建条件期望E(Y|T,X)的完整函数形式（加入处理方式效应）
xbeta <- xbeta + 
  delta1 * ((trt.num == 1) - (trt.num == 3)) +  # 处理1与处理3的效应差异
  delta2 * ((trt.num == 2) - (trt.num == 3))    # 处理2与处理3的效应差异

# 模拟连续型结果变量Y（含随机误差，标准差为2）
y <- xbeta + rnorm(n.obs, sd = 2)




trt[1:5]  # 查看前5个观测的处理方式

table(trt)  # 统计各处理方式的观测数量


propensity.multinom.lasso <- function(x, trt) {
  # 确保处理方式为因子类型
  if (!is.factor(trt)) trt <- as.factor(trt)
  
  # 拟合带3折交叉验证的Lasso惩罚多项逻辑回归
  gfit <- cv.glmnet(y = trt, x = x, family = "multinomial", nfolds = 3)
  
  # 预测各处理方式的概率（使用最优lambda值lambda.min）
  propens <- drop(predict(gfit, newx = x, type = "response", s = "lambda.min"))
  
  # 确保概率矩阵的列顺序与处理方式水平一致
  probs <- propens[, match(levels(trt), colnames(propens))]
  
  # 返回处理方式分配概率矩阵
  probs
}


check.overlap(x = x, trt = trt, propensity.multinom.lasso)


set.seed(123)
subgrp.multi <- fit.subgroup(
  x = x,                      # 协变量矩阵
  y = y,                      # 结果变量
  trt = trt,                  # 处理方式（因子类型）
  propensity.func = propensity.multinom.lasso,  # 倾向得分函数
  reference.trt = "Trt_3",    # 参考处理方式（Trt_3）
  loss = "sq_loss_lasso",     # 损失函数：平方误差损失（带Lasso）
  nfolds = 3                  # 3折交叉验证
)

# 查看亚组模型的详细结果
summary(subgrp.multi)


pl <- plot(subgrp.multi)
pl + theme(axis.text.x = element_text(angle = 90, hjust = 1))  # 旋转x轴标签（90度）


set.seed(123)
validation.multi <- validate.subgroup(
  subgrp.multi,                          # 已拟合的亚组模型
  B = 4,                                 # 重采样次数（实际需增大）
  method = "training_test_replication",  # 验证方法：训练-测试重采样
  train.fraction = 0.5                   # 训练集比例（50%）
)

# 查看验证结果（保留2位小数，显示亚组占比）
print(validation.multi, digits = 2, sample.pct = TRUE)



library(personalized)

set.seed(1)  # 设置随机种子以保证结果可重复
n.obs  <- 500  # 观察样本量
n.vars <- 10   # 协变量数量
x <- matrix(rnorm(n.obs * n.vars, sd = 1), n.obs, n.vars)  # 生成10个符合正态分布的协变量

# 模拟非随机化治疗分配
xbetat   <- 0.5 + 0.25 * x[,1] - 0.25 * x[,5]  # 计算治疗分配的线性预测值
trt.prob <- exp(xbetat) / (1 + exp(xbetat))     # 通过logistic转换得到治疗概率（倾向得分）
trt      <- rbinom(n.obs, 1, prob = trt.prob)   # 基于概率生成二分类治疗分配（1=接受治疗，0=不接受治疗）

# 模拟复杂的条件平均治疗效应（CATE，记为delta）
delta <- 2*(0.25 + x[,1] * x[,2] - x[,3] ^ {-2} * (x[,3] > 0.35) + 
                (x[,1] < x[,3]) - (x[,1] < x[,2]))

# 模拟协变量的主效应g(X)
xbeta <- x[,1] + x[,2] + x[,4] - 0.2 * x[,4]^2 + x[,5] + 0.2 * x[,9] ^ 2
xbeta <- xbeta + delta * (2 * trt - 1) * 0.5  # 纳入治疗效应与治疗分配的交互项

# 模拟连续型结局变量（含随机误差）
y <- drop(xbeta) + rnorm(n.obs)



library(personalized)

set.seed(1)  # 设置随机种子以保证结果可重复
n.obs  <- 500  # 观察样本量
n.vars <- 10   # 协变量数量
x <- matrix(rnorm(n.obs * n.vars, sd = 1), n.obs, n.vars)  # 生成10个符合正态分布的协变量

# 模拟非随机化治疗分配
xbetat   <- 0.5 + 0.25 * x[,1] - 0.25 * x[,5]  # 计算治疗分配的线性预测值
trt.prob <- exp(xbetat) / (1 + exp(xbetat))     # 通过logistic转换得到治疗概率（倾向得分）
trt      <- rbinom(n.obs, 1, prob = trt.prob)   # 基于概率生成二分类治疗分配（1=接受治疗，0=不接受治疗）

# 模拟复杂的条件平均治疗效应（CATE，记为delta）
delta <- 2*(0.25 + x[,1] * x[,2] - x[,3] ^ {-2} * (x[,3] > 0.35) + 
              (x[,1] < x[,3]) - (x[,1] < x[,2]))

# 模拟协变量的主效应g(X)
xbeta <- x[,1] + x[,2] + x[,4] - 0.2 * x[,4]^2 + x[,5] + 0.2 * x[,9] ^ 2
xbeta <- xbeta + delta * (2 * trt - 1) * 0.5  # 纳入治疗效应与治疗分配的交互项

# 模拟连续型结局变量（含随机误差）
y <- drop(xbeta) + rnorm(n.obs)


# 可通过`cv.glmnet.args`向cv.glmnet函数传递参数
# 为缩短计算时间，此处将交叉拟合折数和内部折数设为较小值；实际应用中应设为更大值（如10折）
prop.func <- create.propensity.function(crossfit = TRUE,
                                        nfolds.crossfit = 4,  # 交叉拟合的折数
                                        cv.glmnet.args = list(type.measure = "auc", nfolds = 3))  # 用AUC评价倾向得分模型性能，内部交叉验证为3折


aug.func <- create.augmentation.function(family = "gaussian",  # 结局为连续型，故指定高斯分布
                                         crossfit = TRUE,
                                         nfolds.crossfit = 4,  # 交叉拟合的折数
                                         cv.glmnet.args = list(type.measure = "mse", nfolds = 3))  # 用均方误差（MSE）评价增强函数性能，内部交叉验证为3折


subgrp.model.linear <- fit.subgroup(x = x, y = y,
                                    trt = trt,
                                    propensity.func = prop.func,  # 传入已构建的倾向得分函数
                                    augment.func = aug.func,      # 传入已构建的增强函数
                                    loss   = "sq_loss_lasso",     # 损失函数：带LASSO正则的平方损失
                                    nfolds = 3)                   # ITR估计中cv.glmnet的交叉验证折数

# 查看线性ITR模型的结果摘要
summary(subgrp.model.linear)

## 设置XGBoost的调优参数
param <- list(max_depth = 5,        # 树的最大深度，控制模型复杂度
              eta = 0.01,           # 学习率，较小值可提升模型稳定性但需更多迭代
              nthread = 1,          # 并行线程数，此处设为1（单线程）
              booster = "gbtree",   # 基础模型类型：梯度提升树
              subsample = 0.623,    # 训练样本抽样比例，用于防止过拟合
              colsample_bytree = 1) # 每棵树使用的特征比例，此处为1（使用全部特征）

# 拟合基于XGBoost的ITR模型
subgrp.model.xgb <- fit.subgroup(x = x, y = y,
                                 trt = trt,
                                 propensity.func = prop.func,  # 传入倾向得分函数
                                 augment.func = aug.func,      # 传入增强函数
                                 ## 通过'loss'参数指定使用XGBoost
                                 loss   = "sq_loss_xgboost",
                                 nfold = 3,                    # XGBoost交叉验证折数
                                 params = param,               # 传入XGBoost参数列表
                                 verbose = 0,                  # 训练过程不输出日志（0=不输出，1=输出）
                                 nrounds = 5000,               # 最大提升迭代次数
                                 early_stopping_rounds = 50)   # 连续50轮性能无提升则停止训练

# 查看基于XGBoost的ITR模型结果
subgrp.model.xgb



