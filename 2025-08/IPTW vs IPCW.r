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



# 延续之前的模拟设定
set.seed(456)
n <- 500

# 1. 模拟基线数据
age <- rnorm(n, 55, 8)
gender <- factor(sample(c("Male", "Female"), n, replace = TRUE))
treatment <- rbinom(n, 1, 0.5) # 假设基线随机分配，以简化问题，聚焦IPCW

# 2. 创建长格式数据结构
# 假设我们有5个随访时间点
visit_times <- 1:5
long_data <- data.frame(
  id = rep(1:n, each = length(visit_times)),
  time_visit = rep(visit_times, n),
  age = rep(age, each = length(visit_times)),
  gender = rep(gender, each = length(visit_times)),
  treatment = rep(treatment, each = length(visit_times))
)

# 3. 模拟时间依赖性协变量和信息性删失
# 这里需要一个循环来模拟每个个体的轨迹
library(dplyr)
long_data <- long_data %>%
  group_by(id) %>%
  mutate(
    # 模拟时间依赖性严重程度，假设其随时间增长，且受治疗影响
    severity_tv = 10 + 0.5 * time_visit - 2 * treatment * (time_visit > 1) + rnorm(n(), 0, 1),
    
    # 模拟删失概率，受年龄和当前严重程度影响
    prob_censor = plogis(-5 + 0.03 * age + 0.2 * severity_tv),
    
    # 模拟事件（死亡）概率，受治疗和当前严重程度影响
    prob_event = plogis(-6 + 0.5 * treatment + 0.3 * severity_tv)
  ) %>%
  ungroup()

# 4. 从概率生成事件和删失时间
# 这是一个简化的模拟，现实中通常用生存模型模拟
# 我们需要一个更精细的方法来确定每个人的最终时间和状态
# 为了演示，我们直接生成生存数据，并假设删失与severity_tv相关
true_event_time <- rweibull(n, shape = 2, scale = 20 * exp(-0.5 * treatment - 0.1 * mean(long_data$severity_tv[long_data$id %in% 1:n])))
# 删失时间与年龄和平均严重程度相关
mean_severity_per_id <- long_data %>% group_by(id) %>% summarise(mean_sev = mean(severity_tv)) %>% pull(mean_sev)
censor_time <- rweibull(n, shape = 2, scale = 30 * exp(-0.02 * age - 0.05 * mean_severity_per_id))

# 创建最终的生存数据（宽格式）
survival_data <- data.frame(id = 1:n, age, gender, treatment)
survival_data$time <- pmin(true_event_time, censor_time, 10) # 10是行政删失
survival_data$status <- ifelse(true_event_time <= pmin(censor_time, 10), 1, 0)
head(survival_data)
# 合并时间依赖性协变量到长格式数据中
# 真实数据分析中，你需要将宽格式的生存数据和长格式的时变协变量数据进行合并和重构
# 这里为了代码流程的完整性，我们重新构造一个适合模型拟合的长格式数据
# `survival`包的`tmerge`函数是处理这类问题的利器
library(survival)
# 先创建基线数据
base_data <- survival_data %>% select(id, treatment, age, gender)
# 创建事件数据
event_data <- survival_data %>% select(id, time, status)
# 创建时变协变量数据
tdc_data <- long_data %>% select(id, time_visit, severity_tv)

# 使用tmerge构建分析数据集
# tmerge会自动创建 start-stop 时间格式
analysis_long <- tmerge(data1=base_data, data2=event_data, id=id, event=event(time, status))
analysis_long <- tmerge(analysis_long, data2=tdc_data, id=id, tdc=tdc(time_visit, severity_tv))
# 查看数据结构
head(analysis_long)
head(tdc_data)


# 创建一个表示删失的事件变量 (status_censor)
analysis_long$status_censor <- ifelse(analysis_long$event == 0 & analysis_long$tstop < max(survival_data$time[survival_data$event==1]), 1, 0)
# Cox模型，用于估计在每个时间点未被删失的条件概率
# 这里我们使用一个时间依赖的Cox模型
censor_model <- coxph(Surv(tstart, tstop, status_censor) ~ treatment + age + gender + tdc,
                      data = analysis_long)

summary(censor_model)
