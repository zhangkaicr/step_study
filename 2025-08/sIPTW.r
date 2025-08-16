library(tidyverse)
# 设置随机种子以保证结果可复现
set.seed(123)

# 1. 模拟数据
n <- 1000
# 生成协变量
age <- rnorm(n, 50, 10)
gender <- factor(sample(c("Male", "Female"), n, replace = TRUE, prob = c(0.5, 0.5)))
severity <- rnorm(n, 10, 2)

# 2. 模拟处理分配（倾向性得分模型）
# 假设年龄越大、严重程度越高的患者越有可能接受新药
linear_predictor_A <- -2 + 0.05 * age + 0.1 * severity
prob_A <- plogis(linear_predictor_A) # logistic function to get probability
treatment <- rbinom(n, 1, prob_A)

# 3. 模拟结局（结局模型）
# 假设新药能降低outcome，同时年龄和严重程度也影响outcome
outcome <- 100 - 5 * treatment + 0.5 * age + 2 * severity + rnorm(n, 0, 5)

# 4. 组合成数据框
sim_data <- data.frame(id = 1:n, age, gender, severity, treatment, outcome)
head(sim_data)


naive_model <- lm(outcome ~ treatment, data = sim_data)
summary(naive_model) 
# 可以看到，由于混杂，treatment的效果被低估了


# 拟合倾向性得分模型
ps_model <- glm(treatment ~ age + gender + severity, 
                data = sim_data, 
                family = binomial(link = "logit"))

# 预测每个个体的倾向性得分
sim_data$ps <- predict(ps_model, type = "response")
summary(sim_data$ps)


table(sim_data$treatment) %>% prop.table()

# 计算稳定权重的分子
# 分子是边际的处理概率，不依赖协变量
# 这里我们可以用一个只包含截距项的模型来估计
numerator_model <- glm(treatment ~ 1, data = sim_data, family = binomial(link = "logit"))
p_treatment <- predict(numerator_model, type = "response")

sim_data$stabilized_numerator <- ifelse(sim_data$treatment == 1, 
                                        p_treatment, 
                                        1 - p_treatment)

# 计算稳定权重的分母
sim_data$stabilized_denominator <- ifelse(sim_data$treatment == 1, 
                                          sim_data$ps, 
                                          1 - sim_data$ps)

# 计算最终的稳定IPTW权重
sim_data$iptw_sw <- sim_data$stabilized_numerator / sim_data$stabilized_denominator

# 查看权重分布
summary(sim_data$iptw_sw)
hist(sim_data$iptw_sw, breaks = 50, main = "Distribution of Stabilized IPTW")



# 安装并加载 'tableone' 包
# install.packages("tableone")
library(tableone)

# 定义需要检查平衡性的变量
vars_to_check <- c("age", "gender", "severity")

# 创建加权前的基线特征表
table_before <- CreateTableOne(vars = vars_to_check, 
                               strata = "treatment", 
                               data = sim_data, 
                               test = FALSE)
print(table_before, smd = TRUE)

# 安装并加载 'survey' 包，用于创建加权后的对象
# install.packages("survey")
library(survey)

# 创建一个加权后的调查设计对象 
weighted_design <- svydesign(ids = ~1, data = sim_data, weights = ~iptw_sw)

# 创建加权后的基线特征表
table_after <- svyCreateTableOne(vars = vars_to_check, 
                                 strata = "treatment", 
                                 data = weighted_design, 
                                 test = FALSE)
print(table_after, smd = TRUE)


# install.packages("cobalt")
library(cobalt)

love.plot(ps_model, 
          data = sim_data, 
          weights = sim_data$iptw_sw, 
          stats = "mean.diffs", 
          threshold = .1,
          binary = "std",
          abs = TRUE)

ggsave("love_plot.png", width = 10, height = 8)


# 使用svyglm拟合加权后的结局模型
weighted_model <- svyglm(outcome ~ treatment, design = weighted_design)
summary(weighted_model)
confint(weighted_model)

