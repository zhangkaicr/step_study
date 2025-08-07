# 加载grf包，用于执行广义随机森林相关分析
library(grf)
# 加载tidyverse包，该包包含多个数据处理和可视化的实用工具
library(tidyverse)

rm(list =ls())
# 从https://github.com/grf-labs/grf/tree/master/r-package/grf/vignettes获取半合成数据
# 加载存储半合成数据的RData文件
load("synthetic_SPRINT_ACCORD.RData")
# 将不同来源的数据合并到一个数据框中
df <- data.frame(Y = c(Y.sprint, Y.accord),
                 D = c(D.sprint, D.accord),
                 data = c(rep("synthetic-SPRINT", length(Y.sprint)),
                          rep("synthetic-ACCORD", length(Y.accord))))

# 将D列转换为因子类型，并标记为是否删失
df$Censored <- factor(df$D, labels = c("Yes", "No"))

# 查看数据框的前几行，用于快速检查数据结构和内容
head(df)

# 使用ggplot2绘制直方图，按数据来源分面展示不同删失状态下的主要结局时间分布
ggplot(df, aes(x = Y, fill = Censored)) +
  facet_wrap(data ~ .) +
  geom_histogram(alpha = 0.5, bins = 30) +
  xlab("Time until primary outcome (days)") +
  ylab("Frequency") +
  theme_classic()

head(df)

# 定义生存分析的时间范围，设置为3年（每年按365天计算）
horizon <- 3 * 365
# 使用 causal_survival_forest 函数为 synthetic-SPRINT 数据构建因果生存森林模型
# 输入特征矩阵为 X.sprint，结局时间为 Y.sprint，处理变量为 W.sprint，删失状态为 D.sprint
# 处理变量的预测值使用 W.sprint 的均值，目标为计算受限平均生存时间（RMST），时间范围为前面定义的 horizon
csf.sprint <- causal_survival_forest(X.sprint, Y.sprint, W.sprint, D.sprint,seed = 2,
                                     W.hat = mean(W.sprint), target = "RMST", horizon = horizon)

# 使用 causal_survival_forest 函数为 synthetic-ACCORD 数据构建因果生存森林模型
# 输入特征矩阵为 X.accord，结局时间为 Y.accord，处理变量为 W.accord，删失状态为 D.accord
# 处理变量的预测值使用 W.accord 的均值，目标为计算受限平均生存时间（RMST），时间范围为前面定义的 horizon
csf.accord <- causal_survival_forest(X.accord, Y.accord, W.accord, D.accord,seed = 2,
                                     W.hat = mean(W.accord), target = "RMST", horizon = horizon)

# 使用 synthetic-ACCORD 数据训练的因果生存森林模型对 synthetic-SPRINT 数据进行预测
# 提取预测结果中的预测值部分
tau.hat.sprint <- predict(csf.accord, X.sprint)$predictions
# 使用 synthetic-SPRINT 数据训练的因果生存森林模型对 synthetic-ACCORD 数据进行预测
# 提取预测结果中的预测值部分
tau.hat.accord <- predict(csf.sprint, X.accord)$predictions


# 计算 synthetic-SPRINT 数据的排序平均处理效应，目标指标为 AUTOC
rate.sprint <- rank_average_treatment_effect(csf.sprint, tau.hat.sprint, target = "AUTOC")
# 计算 synthetic-ACCORD 数据的排序平均处理效应，目标指标为 AUTOC
rate.accord <- rank_average_treatment_effect(csf.accord, tau.hat.accord, target = "AUTOC")
# 打印 synthetic-SPRINT 数据的排序平均处理效应结果
rate.sprint
# 打印 synthetic-ACCORD 数据的排序平均处理效应结果
rate.accord

# 设置绘图布局为一行两列
par(mfrow = c(1, 2))
# 绘制 synthetic-SPRINT 数据的排序平均处理效应图，在 SPRINT 数据上评估 TOC，tau(X) 由 ACCORD 数据估计
plot(rate.sprint, xlab = "Treated fraction", main = "TOC evaluated on SPRINT\n tau(X) estimated from ACCORD")
# 绘制 synthetic-ACCORD 数据的排序平均处理效应图，在 ACCORD 数据上评估 TOC，tau(X) 由 SPRINT 数据估计
plot(rate.accord, xlab = "Treated fraction", main = "TOC evaluated on ACCORD\n tau(X) estimated from SPRINT")
