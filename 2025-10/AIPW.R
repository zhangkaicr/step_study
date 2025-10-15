# 设置随机种子以保证结果可复现
set.seed(123)

# 样本量
n <- 1000

# 1. 生成协变量 W
age <- rnorm(n, mean = 65, sd = 5)
baseline_sbp <- rnorm(n, mean = 150, sd = 10)
comorbidity_score <- rbinom(n, size = 5, prob = 0.3)

# 2. 生成治疗分配 A (依赖于W)
# 倾向得分的真实模型包含非线性和交互项
ps_linear_component <- -1.5 + 0.02*age + 0.01*baseline_sbp + 0.1*comorbidity_score + 0.005*baseline_sbp*comorbidity_score
propensity_score <- plogis(ps_linear_component) # logit转换
treatment <- rbinom(n, size = 1, prob = propensity_score) # 0 for std_drug, 1 for new_drug

# 3. 生成结果 Y (依赖于A和W)
# 真实的结果模型也包含非线性和交互项
# 真实的ATE是 -5
true_ate <- -5
outcome_mean <- 2 - 0.05*age - 0.1*baseline_sbp + 0.5*comorbidity_score^2 + true_ate*treatment
sbp_change <- rnorm(n, mean = outcome_mean, sd = 3)

# 4. 合成数据集
sim_data <- data.frame(
  id = 1:n,
  age,
  baseline_sbp,
  comorbidity_score,
  treatment, # 1=new_drug, 0=std_drug
  sbp_change # 负数表示收缩压下降
)

# 查看数据
head(sim_data)


# 安装和加载必要的包
# install.packages(c("tableone", "survey", "AIPW", "SuperLearner"))
library(tableone)

# 定义变量列表
vars <- c("age", "baseline_sbp", "comorbidity_score")

# 创建表1
table_one <- CreateTableOne(vars = vars, strata = "treatment", data = sim_data, test = TRUE)
print(table_one, smd = TRUE)


# 1. 拟合一个简单的(错误的)结果模型
ra_model <- lm(sbp_change ~ treatment + age + baseline_sbp + comorbidity_score, data = sim_data)
summary(ra_model)

# 2. 预测潜在结果
# 创建两个新数据集，一个让所有人都接受治疗，另一个让所有人都不接受
data_treat_all <- sim_data
data_treat_all$treatment <- 1
pred_y1 <- predict(ra_model, newdata = data_treat_all)

data_control_all <- sim_data
data_control_all$treatment <- 0
pred_y0 <- predict(ra_model, newdata = data_control_all)

# 3. 计算ATE
ate_ra <- mean(pred_y1) - mean(pred_y0)
print(paste("RA Estimated ATE:", round(ate_ra, 3)))

summary(ra_model)




# 1. 拟合一个简单的(错误的)倾向得分模型
ps_model <- glm(treatment ~ age + baseline_sbp + comorbidity_score, 
                data = sim_data, family = "binomial")

# 2. 估计倾向得分
ps_scores <- predict(ps_model, type = "response")

# 3. 计算IPW权重
sim_data$ipw_weights <- ifelse(sim_data$treatment == 1, 1 / ps_scores, 1 / (1 - ps_scores))

# 检查权重分布
summary(sim_data$ipw_weights)
hist(sim_data$ipw_weights, breaks = 50)

# 4. 检查加权后的协变量平衡性
weighted_table_one <- svydesign(ids = ~1, data = sim_data, weights = ~ipw_weights)
weighted_balance <- svyCreateTableOne(vars = vars, strata = "treatment", data = weighted_table_one, test = FALSE)
print(weighted_balance, smd = TRUE)

# 5. 使用加权回归估计ATE
library(survey)
# 使用survey包来正确处理加权数据的标准误
ipw_model <- svyglm(sbp_change ~ treatment, design = weighted_table_one)
summary(ipw_model)
ate_ipw <- coef(ipw_model)["treatment"]
print(paste("IPW Estimated ATE:", round(ate_ipw, 3)))




library(AIPW)
library(SuperLearner) # AIPW依赖此包进行机器学习建模

# 准备数据
# Y: 结果变量
Y <- sim_data$sbp_change
# A: 治疗变量 (必须是0/1)
A <- sim_data$treatment
# W: 协变量矩阵
W <- sim_data[, c("age", "baseline_sbp", "comorbidity_score")]

# 设定用于估计模型的机器学习算法库
# SL.glm: 线性/逻辑回归
# SL.gam: 广义可加模型 (捕捉非线性)
# SL.randomForest: 随机森林
# 我们在这里使用一个包含简单和复杂模型的库，让SuperLearner自动选择最佳模型
sl_lib <- c("SL.glm", "SL.gam", "SL.randomForest")

# 运行AIPW
# Q.SL.library: 用于结果模型的算法库
# g.SL.library: 用于倾向得分模型的算法库
set.seed(456) # SuperLearner内部有随机性
aipw_result <- AIPW$new(Y = Y, A = A, W = W,
                        Q.SL.library = sl_lib,
                        g.SL.library = sl_lib,
                        k_split = 5, # 5折交叉验证
                        verbose = FALSE)$fit()

# 查看详细结果
aipw_result$ip_weights.plot
