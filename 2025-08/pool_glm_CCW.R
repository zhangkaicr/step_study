# 加载必要的包
library(tidyverse)
library(survival)
library(openxlsx)
library(gridExtra)
library(broom)

# 1. 创建示例生存数据--------------------------------------------

set.seed(123)
n <- 100
data <- data.frame(
  id = 1:n,
  time = rexp(n, rate = 0.1),  # 生存时间
  event = rbinom(n, 1, 0.7),   # 事件指示
  age = rnorm(n, 50, 10),      # 年龄
  sex = rbinom(n, 1, 0.5),     # 性别
  treatment = rbinom(n, 1, 0.5) # 治疗组
)

head(data)
write.xlsx(data, file = "data.xlsx")


# # 2. 数据转换函数：将生存数据转换为pooled格式
# 函数名: convert_to_pooled
# 参数说明:
#   data: 包含生存数据的数据框
#   time_var: 时间变量的列名（字符串）
#   event_var: 事件变量的列名（字符串）
#   time_intervals: 时间间隔向量，用于定义观察时间点
#   covariates: 需要保留的协变量列名向量，如果为NULL则保留所有变量
convert_to_pooled <- function(data, 
                            time_var, 
                            event_var, 
                            time_intervals,
                            covariates = NULL) {
  # 参数检查
  if (!time_var %in% names(data)) {
    stop("时间变量 '", time_var, "' 在数据中不存在")
  }
  if (!event_var %in% names(data)) {
    stop("事件变量 '", event_var, "' 在数据中不存在")
  }
  
  # 如果未指定协变量，使用除时间和事件外的所有变量
  if (is.null(covariates)) {
    covariates <- setdiff(names(data), c(time_var, event_var))
  } else {
    # 检查指定的协变量是否存在
    missing_vars <- setdiff(covariates, names(data))
    if (length(missing_vars) > 0) {
      stop("以下协变量在数据中不存在: ", paste(missing_vars, collapse = ", "))
    }
  }
  # 创建空的数据框用于存储池化后的数据
  pooled_data <- data.frame()
  
  # 遍历每个个体的数据
  for (i in 1:nrow(data)) {
    # 提取当前个体的所有信息
    individual <- data[i, ]
    
    # 计算个体的最大观察时间
    max_time <- individual[[time_var]]
    
    # 筛选出小于等于最大观察时间的时间点
    valid_time_points <- time_intervals[time_intervals <= max_time]
    
    # 如果没有有效的时间点则跳过当前个体
    if (length(valid_time_points) == 0) next
    
    # 为每个时间间隔创建观察记录
    for (j in 1:length(valid_time_points)) {
      t <- valid_time_points[j]
      
      # 判断是否是最后一个时间点
      is_last_interval <- (j == length(valid_time_points))
      
      # 判断事件状态
      event_in_interval <- if (is_last_interval) {
        # 如果是最后一个间隔，直接使用原始事件状态
        # 1表示死亡，0表示生存
        individual[[event_var]]
      } else {
        # 中间时间点，事件状态都记为0
        0
      }
      
      # 创建基础记录
      pooled_record <- data.frame(
        id = i,  # 使用行号作为ID
        time_interval = t,
        event_in_interval = as.numeric(event_in_interval)
      )
      
      # 添加协变量
      for (var in covariates) {
        pooled_record[[var]] <- individual[[var]]
      }
      
      # 将当前记录添加到池化数据中
      pooled_data <- rbind(pooled_data, pooled_record)
    }
  }
  # 返回转换后的池化数据
  return(pooled_data)
}



# 3. 执行数据转换--------------------------------
time_intervals <- 1:20  # 定义时间间隔
pooled_data <- convert_to_pooled( data = data,
  time_var = "time",
  event_var = "event",
  time_intervals = time_intervals)

head(pooled_data)
glimpse(pooled_data)


# 4.拟合删失模型：预测在时间t被删失的概率--------------------------------
# logit(P(censored_at_t = 1)) = α + β1*time + β2*covariates
censoring_model <- glm(event_in_interval ~ time_interval + age + sex + treatment, 
                       data = pooled_data, 
                       family = binomial(link = "logit"))

summary(censoring_model)
tidy(censoring_model)

# 5. 计算IPCW权重-----------------------
# 预测每个时间点被删失的概率
pooled_data$censoring_prob <- predict(censoring_model, type = "response")

# 计算非删失概率（生存到该时间点的概率）
pooled_data$survival_prob <- 1 - pooled_data$censoring_prob


# 计算每个个体的累积权重
calculate_ipcw <- function(data) {
  # 按个体ID分组
  ids <- unique(data$id)
  data$ipcw_weight <- NA
  
  for (id in ids) {
    # 获取该个体的所有记录
    individual_data <- data[data$id == id, ]
    individual_data <- individual_data[order(individual_data$time_interval), ]
    
    # 计算累积权重
    cumulative_weight <- 1
    for (i in 1:nrow(individual_data)) {
      # 累积权重 = 1 / (累积非删失概率)
      cumulative_weight <- cumulative_weight * (1 / individual_data$survival_prob[i])
      data[data$id == id & data$time_interval == individual_data$time_interval[i], "ipcw_weight"] <- cumulative_weight
    }
  }
  
  return(data)
}

# 计算权重
pooled_data <- calculate_ipcw(pooled_data)


head(pooled_data)

# 6. 权重截断（处理极端权重）
# 计算99%分位数进行截断
weight_99th <- quantile(pooled_data$ipcw_weight, 0.99, na.rm = TRUE)
pooled_data$truncated_weight <- pmin(pooled_data$ipcw_weight, weight_99th)



# 7. 权重比较
weight_stats <- data.frame(
  指标 = c("最小值", "第一四分位数", "中位数", "均值", "第三四分位数", "最大值"),
  IPCW = as.numeric(summary(pooled_data$ipcw_weight)),
  截断IPCW = as.numeric(summary(pooled_data$truncated_weight))
)

# 打印权重统计结果
print(weight_stats)