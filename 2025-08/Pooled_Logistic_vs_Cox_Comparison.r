# =============================================================================
# 合并逻辑回归生存分析与Cox比例风险模型全流程对比
# Pooled Logistic Regression Survival Analysis vs Cox Proportional Hazards Model
# =============================================================================

# 清理工作环境
rm(list = ls())
gc()

# =============================================================================
# 1. 加载必要的R包
# =============================================================================

# 检查并安装缺失的包
required_packages <- c(
  "survival",      # 生存分析核心包
  "dplyr",         # 数据处理
  "tidyr",         # 数据重塑
  "ggplot2",       # 数据可视化
  "gridExtra",     # 多图排列
  "riskRegression", # 模型评估指标
  "glmnet",        # 正则化回归
  "survminer",     # 生存分析可视化
  "pROC",          # ROC曲线分析
  "Hmisc",         # 统计函数
  "corrplot",      # 相关性图
  "knitr",         # 表格输出
  "broom"          # 模型结果整理
)

# 安装缺失的包
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}


# =============================================================================
# 2. 数据加载与预处理
# =============================================================================


# 加载肺癌数据集
data(cancer, package = "survival")


# 数据预处理
lung_df <- lung %>%
  as_tibble() %>%
  mutate(
    # 将status转换为0/1格式：1=死亡事件，0=删失
    status = if_else(status == 2, 1, 0),
    # 将性别转换为因子变量
    sex = factor(sex, levels = c(1, 2), labels = c("Male", "Female")),
    # 将ECOG评分转换为因子变量
    ph.ecog = factor(ph.ecog),
    # 创建年龄分组
    age_group = case_when(
      age < 60 ~ "<60",
      age >= 60 & age < 70 ~ "60-69",
      age >= 70 ~ ">=70"
    ) %>% factor(levels = c("<60", "60-69", ">=70"))
  ) %>%
  # 移除缺失值过多的变量
  select(-meal.cal, -pat.karno) %>%
  # 删除含有缺失值的行
  drop_na() %>%
  # 添加唯一ID
  mutate(id = row_number())

# 显示处理后的数据信息
glimpse(lung_df)


# =============================================================================
# 3. 探索性数据分析
# =============================================================================


# 3.1 生存时间分布
p1 <- ggplot(lung_df, aes(x = time)) +
  geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
  labs(title = "生存时间分布", x = "生存时间 (天)", y = "频数") +
  theme_minimal()

# 3.2 按性别分组的生存时间
p2 <- ggplot(lung_df, aes(x = sex, y = time, fill = sex)) +
  geom_boxplot(alpha = 0.7) +
  labs(title = "按性别分组的生存时间", x = "性别", y = "生存时间 (天)") +
  theme_minimal() +
  theme(legend.position = "none")

# 3.3 年龄与生存时间的关系
p3 <- ggplot(lung_df, aes(x = age, y = time)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(title = "年龄与生存时间关系", x = "年龄", y = "生存时间 (天)") +
  theme_minimal()

# 3.4 ECOG评分分布
p4 <- ggplot(lung_df, aes(x = ph.ecog, fill = factor(status))) +
  geom_bar(position = "fill", alpha = 0.7) +
  labs(title = "ECOG评分与事件状态", x = "ECOG评分", y = "比例", fill = "状态") +
  scale_fill_manual(values = c("0" = "lightblue", "1" = "coral"),
                    labels = c("删失", "死亡")) +
  theme_minimal()

# 组合图形
grid.arrange(p1, p2, p3, p4, ncol = 2)
00
# 3.5 相关性分析
cat("\n=== 数值变量相关性分析 ===\n")
numeric_vars <- lung_df %>% select(time, age, status) %>% cor()
print(numeric_vars)

# =============================================================================
# 4. 合并逻辑回归模型实现
# =============================================================================



# 4.1 定义时间区间
# 根据数据分布确定合适的时间断点
max_time <- max(lung_df$time)

# 创建时间断点（每90天一个区间）
time_breaks <- seq(0, max_time + 90, by = 90)

# 4.2 数据转换为长格式
cat("\n将数据转换为长格式...\n")

# 使用survSplit函数将数据转换为离散时间格式
lung_long <- survSplit(
  Surv(time, status) ~ .,  # 生存对象公式
  data = lung_df,          # 原始数据
  cut = time_breaks,       # 时间断点
  episode = "time_interval" # 时间区间变量名
)

# 重命名变量以符合标准命名
lung_long <- lung_long %>%
  rename(
    tstop = time,      # 区间结束时间
    event = status     # 事件指示变量
  ) %>%
  mutate(
    # 将时间区间转换为因子
    time_interval = factor(time_interval),
    # 计算区间长度
    interval_length = tstop - tstart
  )

cat("长格式数据维度:", dim(lung_long), "\n")
cat("长格式数据前10行:\n")
print(head(lung_long, 10))

# 检查每个时间区间的事件数
interval_summary <- lung_long %>%
  group_by(time_interval) %>%
  summarise(
    n_obs = n(),                    # 观察数
    n_events = sum(event),          # 事件数
    event_rate = mean(event),       # 事件率
    .groups = "drop"
  )

cat("\n各时间区间事件统计:\n")
print(interval_summary)

# 4.3 拟合合并逻辑回归模型
cat("\n拟合合并逻辑回归模型...\n")

# 基础模型：包含时间区间和协变量
fit_pooled_logistic <- glm(
  event ~ time_interval + age + sex + ph.ecog,
  data = lung_long,
  family = binomial(link = "logit")
)

# 显示模型摘要
summary(fit_pooled_logistic)

# 模型系数的置信区间
confint(fit_pooled_logistic)

# 4.4 时间变化效应模型

# 包含时间与协变量交互项的模型
fit_pooled_tv <- glm(
  event ~ time_interval + age + sex + ph.ecog + 
          age:time_interval + sex:time_interval,
  data = lung_long,
  family = binomial(link = "logit")
)

summary(fit_pooled_tv)

# 模型比较（似然比检验）
anova_result <- anova(fit_pooled_logistic, fit_pooled_tv, test = "Chisq")
print(anova_result)

# =============================================================================
# 5. Cox比例风险模型实现
# =============================================================================


# 5.1 拟合Cox比例风险模型
fit_cox <- coxph(
  Surv(time, status) ~ age + sex + ph.ecog,
  data = lung_df,
  x = TRUE,  # 保存设计矩阵，用于后续评估
  y = TRUE   # 保存响应变量
)

# 显示Cox模型结果
summary(fit_cox)

# 5.2 Cox模型诊断

# 比例风险假设检验
ph_test <- cox.zph(fit_cox)
print(ph_test)

# 如果p值<0.05，则违反比例风险假设

# 5.3 分层Cox模型（如果需要）
# 如果ECOG评分违反比例风险假设，可以考虑分层
if ("ph.ecog" %in% rownames(ph_test$table) && ph_test$table["ph.ecog", "p"] < 0.05) {
  cat("\n拟合分层Cox模型（按ECOG评分分层）...\n")
  fit_cox_strata <- coxph(
    Surv(time, status) ~ age + sex + strata(ph.ecog),
    data = lung_df,
    x = TRUE,
    y = TRUE
  )
  cat("分层Cox模型结果:\n")
  print(summary(fit_cox_strata))
}

# =============================================================================
# 6. 模型预测与生存曲线
# =============================================================================


# 6.1 定义预测场景
# 创建典型患者档案进行预测
pred_scenarios <- expand.grid(
  age = c(60, 70),  # 两个年龄组
  sex = c("Male", "Female"),  # 两种性别
  ph.ecog = factor(c(0, 1))   # 两种ECOG评分
) %>%
  mutate(
    scenario_id = row_number(),
    scenario_name = paste0(
      "Age", age, "_", sex, "_ECOG", ph.ecog
    )
  )

print(pred_scenarios)

# 6.2 合并逻辑回归预测
cat("\n计算合并逻辑回归生存曲线...\n")

# 为每个场景创建长格式数据
predict_pooled_survival <- function(model, scenarios, time_breaks) {
  results <- list()
  
  # 获取模型中实际使用的时间区间水平
  model_time_levels <- levels(model$data$time_interval)
  if (is.null(model_time_levels)) {
    # 如果模型数据不可用，从模型对象中提取
    model_time_levels <- levels(lung_long$time_interval)
  }
  
  for (i in 1:nrow(scenarios)) {
    scenario <- scenarios[i, ]
    
    # 创建该场景下所有时间区间的数据，使用模型中的因子水平
    scenario_data <- expand.grid(
      time_interval = factor(model_time_levels, levels = model_time_levels),
      age = scenario$age,
      sex = scenario$sex,
      ph.ecog = scenario$ph.ecog
    )
    
    # 预测每个区间的风险概率
    hazard_probs <- predict(model, newdata = scenario_data, type = "response")
    
    # 计算累积生存概率
    survival_probs <- cumprod(1 - hazard_probs)
    
    # 添加时间点（确保长度匹配）
    n_intervals <- length(hazard_probs)
    result_df <- data.frame(
      scenario_id = scenario$scenario_id,
      scenario_name = scenario$scenario_name,
      time = time_breaks[2:(n_intervals+1)],
      survival_prob = survival_probs,
      method = "Pooled Logistic"
    )
    
    results[[i]] <- result_df
  }
  
  return(do.call(rbind, results))
}

# 计算合并逻辑回归生存曲线
survival_pooled <- predict_pooled_survival(
  fit_pooled_logistic, pred_scenarios, time_breaks
)

# 6.3 Cox模型预测

# 使用survfit函数计算Cox模型生存曲线
survival_cox_list <- list()

for (i in 1:nrow(pred_scenarios)) {
  scenario <- pred_scenarios[i, ]
  
  # 创建新数据
  newdata <- data.frame(
    age = scenario$age,
    sex = scenario$sex,
    ph.ecog = scenario$ph.ecog
  )
  
  # 计算生存曲线
  surv_fit <- survfit(fit_cox, newdata = newdata)
  
  # 提取生存概率和时间
  result_df <- data.frame(
    scenario_id = scenario$scenario_id,
    scenario_name = scenario$scenario_name,
    time = surv_fit$time,
    survival_prob = surv_fit$surv,
    method = "Cox PH"
  )
  
  survival_cox_list[[i]] <- result_df
}

survival_cox <- do.call(rbind, survival_cox_list)

head(survival_combined)
# 6.4 合并两种方法的结果
survival_combined <- rbind(survival_pooled, survival_cox)

cat("生存曲线数据维度:", dim(survival_combined), "\n")

# =============================================================================
# 7. 模型性能评估
# =============================================================================

cat("\n=== 开始模型性能评估 ===\n")

# 7.1 模型拟合优度比较
cat("\n=== 模型拟合优度比较 ===\n")

# AIC和BIC比较
aic_pooled <- AIC(fit_pooled_logistic)
bic_pooled <- BIC(fit_pooled_logistic)
aic_cox <- AIC(fit_cox)
bic_cox <- BIC(fit_cox)

model_comparison <- data.frame(
  Model = c("Pooled Logistic", "Cox PH"),
  AIC = c(aic_pooled, aic_cox),
  BIC = c(bic_pooled, bic_cox),
  stringsAsFactors = FALSE
)

cat("模型比较结果:\n")
print(model_comparison)

# 7.2 预测性能评估
cat("\n=== 预测性能评估 ===\n")

# 计算C-index（一致性指数）
tryCatch({
  # Cox模型的C-index
  cox_concordance <- concordance(fit_cox)
  cat(sprintf("Cox模型C-index: %.3f (95%% CI: %.3f-%.3f)\n",
              cox_concordance$concordance,
              cox_concordance$concordance - 1.96 * sqrt(cox_concordance$var),
              cox_concordance$concordance + 1.96 * sqrt(cox_concordance$var)))
  
  # 对于逻辑回归，我们需要自定义计算C-index
  # 这里使用简化的方法
  cat("\n注意：合并逻辑回归的C-index计算需要特殊处理\n")
  
}, error = function(e) {
  cat("C-index计算出错:", e$message, "\n")
})

# 7.3 残差分析
cat("\n=== 残差分析 ===\n")

# Cox模型残差
cox_residuals <- residuals(fit_cox, type = "martingale")
deviance_residuals <- residuals(fit_cox, type = "deviance")

# 逻辑回归残差
logistic_residuals <- residuals(fit_pooled_logistic, type = "deviance")

cat(sprintf("Cox模型Martingale残差范围: [%.3f, %.3f]\n",
            min(cox_residuals), max(cox_residuals)))
cat(sprintf("Cox模型偏差残差范围: [%.3f, %.3f]\n",
            min(deviance_residuals), max(deviance_residuals)))
cat(sprintf("逻辑回归偏差残差范围: [%.3f, %.3f]\n",
            min(logistic_residuals), max(logistic_residuals)))

# =============================================================================
# 8. 可视化对比
# =============================================================================

cat("\n=== 开始可视化对比 ===\n")

# 8.1 生存曲线对比图
cat("绘制生存曲线对比图...\n")

# 选择几个代表性场景进行可视化
selected_scenarios <- c(1, 2, 7, 8)  # 选择4个场景

survival_plot_data <- survival_combined %>%
  filter(scenario_id %in% selected_scenarios) %>%
  mutate(
    scenario_label = case_when(
      scenario_id == 1 ~ "60岁男性，ECOG=0",
      scenario_id == 2 ~ "60岁男性，ECOG=1",
      scenario_id == 7 ~ "70岁女性，ECOG=0",
      scenario_id == 8 ~ "70岁女性，ECOG=1",
      TRUE ~ scenario_name
    )
  )

# 生存曲线对比图
p_survival <- ggplot(survival_plot_data, aes(x = time, y = survival_prob, 
                                             color = method, linetype = method)) +
  geom_step(size = 1) +
  facet_wrap(~scenario_label, ncol = 2) +
  labs(
    title = "合并逻辑回归 vs Cox比例风险模型：生存曲线对比",
    x = "时间 (天)",
    y = "生存概率",
    color = "模型方法",
    linetype = "模型方法"
  ) +
  scale_color_manual(values = c("Pooled Logistic" = "red", "Cox PH" = "blue")) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 10),
    plot.title = element_text(hjust = 0.5)
  )

print(p_survival)

# 8.2 模型系数对比图
cat("\n绘制模型系数对比图...\n")

# 提取模型系数
cox_coefs <- tidy(fit_cox, conf.int = TRUE) %>%
  filter(term != "time_interval") %>%
  mutate(model = "Cox PH")

logistic_coefs <- tidy(fit_pooled_logistic, conf.int = TRUE) %>%
  filter(!grepl("time_interval", term)) %>%
  mutate(model = "Pooled Logistic")

# 合并系数数据
coef_comparison <- rbind(cox_coefs, logistic_coefs) %>%
  mutate(
    term_label = case_when(
      term == "age" ~ "年龄",
      term == "sexFemale" ~ "性别：女性",
      term == "ph.ecog1" ~ "ECOG评分：1",
      term == "ph.ecog2" ~ "ECOG评分：2",
      TRUE ~ term
    )
  )

# 系数对比图
p_coefs <- ggplot(coef_comparison, aes(x = term_label, y = estimate, 
                                       color = model, shape = model)) +
  geom_point(size = 3, position = position_dodge(width = 0.3)) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), 
                width = 0.2, position = position_dodge(width = 0.3)) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  labs(
    title = "模型系数对比（95%置信区间）",
    x = "协变量",
    y = "系数估计值",
    color = "模型",
    shape = "模型"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5)
  )

print(p_coefs)

# 8.3 残差诊断图
cat("\n绘制残差诊断图...\n")

# Cox模型残差图
residual_data_cox <- data.frame(
  fitted = predict(fit_cox),
  martingale = cox_residuals,
  deviance = deviance_residuals,
  model = "Cox PH"
)

# 逻辑回归残差图
residual_data_logistic <- data.frame(
  fitted = predict(fit_pooled_logistic),
  deviance = logistic_residuals,
  model = "Pooled Logistic"
)

# Cox模型残差图
p_residuals_cox <- ggplot(residual_data_cox, aes(x = fitted, y = deviance)) +
  geom_point(alpha = 0.6) +
  geom_smooth(se = TRUE, color = "red") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(
    title = "Cox模型：偏差残差 vs 拟合值",
    x = "拟合值",
    y = "偏差残差"
  ) +
  theme_minimal()

# 逻辑回归残差图
p_residuals_logistic <- ggplot(residual_data_logistic, aes(x = fitted, y = deviance)) +
  geom_point(alpha = 0.6) +
  geom_smooth(se = TRUE, color = "red") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(
    title = "合并逻辑回归：偏差残差 vs 拟合值",
    x = "拟合值",
    y = "偏差残差"
  ) +
  theme_minimal()

# 组合残差图
grid.arrange(p_residuals_cox, p_residuals_logistic, ncol = 2)

# =============================================================================
# 9. 模型验证与交叉验证
# =============================================================================

cat("\n=== 开始模型验证 ===\n")

# 9.1 Bootstrap验证
cat("进行Bootstrap验证...\n")

set.seed(123)
n_bootstrap <- 100  # Bootstrap次数

# 存储Bootstrap结果
bootstrap_results <- list()

for (i in 1:n_bootstrap) {
  # 生成Bootstrap样本
  boot_indices <- sample(nrow(lung_df), replace = TRUE)
  boot_data <- lung_df[boot_indices, ]
  
  tryCatch({
    # 拟合Cox模型
    boot_cox <- coxph(Surv(time, status) ~ age + sex + ph.ecog, data = boot_data)
    
    # 转换为长格式并拟合逻辑回归
    boot_long <- survSplit(Surv(time, status) ~ ., data = boot_data,
                           cut = time_breaks, episode = "time_interval") %>%
      rename(tstop = time, event = status) %>%
      mutate(time_interval = factor(time_interval))
    
    boot_logistic <- glm(event ~ time_interval + age + sex + ph.ecog,
                         data = boot_long, family = binomial)
    
    # 存储系数
    bootstrap_results[[i]] <- list(
      cox_coefs = coef(boot_cox),
      logistic_coefs = coef(boot_logistic)[!grepl("time_interval", names(coef(boot_logistic)))]
    )
    
  }, error = function(e) {
    # 如果Bootstrap样本导致拟合失败，跳过
    NULL
  })
  
  if (i %% 20 == 0) {
    cat(sprintf("Bootstrap进度: %d/%d\n", i, n_bootstrap))
  }
}

# 移除失败的Bootstrap
bootstrap_results <- bootstrap_results[!sapply(bootstrap_results, is.null)]
cat(sprintf("成功的Bootstrap次数: %d/%d\n", length(bootstrap_results), n_bootstrap))

# 计算Bootstrap置信区间
if (length(bootstrap_results) > 10) {
  # Cox模型系数的Bootstrap分布
  cox_boot_coefs <- do.call(rbind, lapply(bootstrap_results, function(x) x$cox_coefs))
  cox_boot_ci <- apply(cox_boot_coefs, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE)
  
  cat("\nCox模型系数Bootstrap 95%置信区间:\n")
  print(cox_boot_ci)
  
  # 逻辑回归系数的Bootstrap分布
  logistic_boot_coefs <- do.call(rbind, lapply(bootstrap_results, function(x) x$logistic_coefs))
  logistic_boot_ci <- apply(logistic_boot_coefs, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE)
  
  cat("\n合并逻辑回归系数Bootstrap 95%置信区间:\n")
  print(logistic_boot_ci)
}

# =============================================================================
# 10. 结果总结与解释
# =============================================================================

cat("\n=== 分析结果总结 ===\n")

# 10.1 模型比较总结
cat("\n1. 模型拟合比较:\n")
cat(sprintf("   - 合并逻辑回归 AIC: %.2f, BIC: %.2f\n", aic_pooled, bic_pooled))
cat(sprintf("   - Cox比例风险模型 AIC: %.2f, BIC: %.2f\n", aic_cox, bic_cox))

if (aic_pooled < aic_cox) {
  cat("   - 根据AIC，合并逻辑回归模型拟合更好\n")
} else {
  cat("   - 根据AIC，Cox比例风险模型拟合更好\n")
}

# 10.2 系数解释
cat("\n2. 主要发现:\n")
cat("   Cox模型系数解释（风险比）:\n")
cox_summary <- summary(fit_cox)
for (i in 1:length(cox_summary$coefficients[,1])) {
  var_name <- rownames(cox_summary$coefficients)[i]
  hr <- exp(cox_summary$coefficients[i,1])
  p_val <- cox_summary$coefficients[i,5]
  cat(sprintf("     - %s: HR=%.3f, p=%.3f\n", var_name, hr, p_val))
}

cat("\n   合并逻辑回归系数解释（优势比）:\n")
logistic_summary <- summary(fit_pooled_logistic)
logistic_coefs <- logistic_summary$coefficients
for (i in 2:nrow(logistic_coefs)) {  # 跳过截距
  var_name <- rownames(logistic_coefs)[i]
  if (!grepl("time_interval", var_name)) {
    or <- exp(logistic_coefs[i,1])
    p_val <- logistic_coefs[i,4]
    cat(sprintf("     - %s: OR=%.3f, p=%.3f\n", var_name, or, p_val))
  }
}

# 10.3 模型适用性讨论
cat("\n3. 模型适用性分析:\n")
cat("   合并逻辑回归优势:\n")
cat("     - 可以处理时间变化的效应\n")
cat("     - 不需要比例风险假设\n")
cat("     - 可以直接估计绝对风险\n")
cat("     - 便于处理复杂的时间模式\n")

cat("\n   Cox比例风险模型优势:\n")
cat("     - 半参数方法，对基线风险分布无假设\n")
cat("     - 计算效率高\n")
cat("     - 广泛接受和理解\n")
cat("     - 适合相对风险分析\n")

# 10.4 建议
cat("\n4. 建议:\n")
if (any(ph_test$table[, "p"] < 0.05)) {
  cat("   - 由于违反比例风险假设，建议使用合并逻辑回归\n")
} else {
  cat("   - 比例风险假设成立，两种方法都适用\n")
}
cat("   - 如果关注绝对风险预测，推荐合并逻辑回归\n")
cat("   - 如果关注相对风险比较，推荐Cox模型\n")
cat("   - 对于复杂的时间模式，合并逻辑回归更灵活\n")

# =============================================================================
# 11. 保存结果
# =============================================================================

cat("\n=== 保存分析结果 ===\n")

# 创建结果列表
analysis_results <- list(
  data_summary = list(
    original_n = nrow(lung),
    final_n = nrow(lung_df),
    event_rate = event_rate,
    max_followup = max_time
  ),
  models = list(
    pooled_logistic = fit_pooled_logistic,
    cox_ph = fit_cox
  ),
  model_comparison = model_comparison,
  survival_curves = survival_combined,
  diagnostics = list(
    ph_test = ph_test,
    cox_residuals = cox_residuals,
    logistic_residuals = logistic_residuals
  )
)

# 保存到RData文件
save(analysis_results, file = "pooled_logistic_vs_cox_analysis.RData")
cat("分析结果已保存到 'pooled_logistic_vs_cox_analysis.RData'\n")

# 保存生存曲线数据到CSV
write.csv(survival_combined, "survival_curves_comparison.csv", row.names = FALSE)
cat("生存曲线数据已保存到 'survival_curves_comparison.csv'\n")

# 保存模型比较结果
write.csv(model_comparison, "model_comparison_results.csv", row.names = FALSE)
cat("模型比较结果已保存到 'model_comparison_results.csv'\n")

cat("\n=== 分析完成 ===\n")
cat("所有分析步骤已完成。请查看生成的图表和保存的结果文件。\n")
cat("如需进一步分析，可以加载保存的RData文件继续工作。\n")

# 显示会话信息
cat("\n=== 会话信息 ===\n")
sessionInfo()