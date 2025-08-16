# 条件均值估计完整示例
# 基于grf包实现条件均值和平均处理效应的估计

# 清理工作环境
rm(list = ls())

# 加载必要的库
# 如果没有安装，请先运行: install.packages(c("grf", "tidyverse", "ggplot2"))
library(grf)        # 广义随机森林包，用于因果推断
library(tidyverse)  # 现代R数据处理包集合
library(ggplot2)    # 数据可视化包

# 设置随机种子以确保结果可重现
set.seed(42)

# ============================================================================
# 第一部分：生成测试数据
# ============================================================================

# 定义样本大小
n <- 2000  # 总样本数
p <- 10    # 协变量维度

cat("正在生成测试数据...\n")

# 生成协变量矩阵 X
# 使用标准正态分布生成p维协变量
X <- matrix(rnorm(n * p), n, p)
colnames(X) <- paste0("X", 1:p)  # 为列命名

# 生成处理变量 W (二元处理)
# 使用逻辑回归模型生成处理概率，确保处理分配不是完全随机的
# 倾向性得分依赖于前几个协变量
propensity_score <- plogis(0.1 * X[,1] + 0.2 * X[,2] - 0.1 * X[,3])
W <- rbinom(n, 1, propensity_score)

# 生成结果变量 Y
# 定义真实的条件均值函数
# mu_0(x): 控制组的条件均值
mu_0 <- function(x) {
  # 非线性函数，包含交互项
  2 * x[,1] + x[,2]^2 - 0.5 * x[,1] * x[,2] + 0.3 * x[,3]
}

# mu_1(x): 处理组的条件均值  
mu_1 <- function(x) {
  # 处理效应是异质性的，依赖于协变量
  mu_0(x) + (1 + 0.5 * x[,1]) * (0.5 + 0.3 * x[,2])
}

# 计算真实的条件均值
mu_0_true <- mu_0(X)
mu_1_true <- mu_1(X)

# 生成观测到的结果变量
# 添加随机误差项
epsilon <- rnorm(n, 0, 1)
Y <- W * mu_1_true + (1 - W) * mu_0_true + epsilon

# 真实的条件平均处理效应 (CATE)
tau_true <- mu_1_true - mu_0_true

cat("数据生成完成！\n")
cat(sprintf("样本大小: %d\n", n))
cat(sprintf("处理组比例: %.2f\n", mean(W)))
cat(sprintf("平均处理效应 (真实值): %.3f\n", mean(tau_true)))

# ============================================================================
# 第二部分：使用因果森林估计条件均值
# ============================================================================

cat("\n开始训练因果森林模型...\n")

# 训练因果森林模型
# 使用交叉拟合来避免过拟合
tryCatch({
  cf <- causal_forest(
    X = X,                    # 协变量矩阵
    Y = Y,                    # 结果变量
    W = W,                    # 处理变量
    num.trees = 2000,         # 树的数量，更多的树通常提供更好的估计
    sample.fraction = 0.5,    # 每棵树使用的样本比例
    mtry = min(ceiling(sqrt(p) + 20), p),  # 每次分裂考虑的变量数
    honesty = TRUE,           # 使用诚实分裂
    honesty.fraction = 0.5,   # 诚实样本比例
    ci.group.size = 2,        # 置信区间组大小
    tune.parameters = "all"   # 调整所有超参数
  )
  
  cat("因果森林训练完成！\n")
  
}, error = function(e) {
  cat("训练因果森林时出错:", e$message, "\n")
  stop("请检查grf包是否正确安装")
})

# ============================================================================
# 第三部分：估计条件均值
# ============================================================================

cat("\n开始估计条件均值...\n")

# 方法1: 直接从因果森林获取CATE估计
tau_hat <- predict(cf)$predictions

# 方法2: 使用回归森林分别估计 mu_0 和 mu_1
# 这种方法提供了更直接的条件均值估计

# 估计控制组条件均值 mu_0(X)
# 只使用控制组数据 (W = 0)
control_indices <- which(W == 0)
if(length(control_indices) > 50) {  # 确保有足够的控制组样本
  tryCatch({
    rf_control <- regression_forest(
      X = X[control_indices, , drop = FALSE],
      Y = Y[control_indices],
      num.trees = 1000,
      sample.fraction = 0.5,
      mtry = min(ceiling(sqrt(p) + 20), p),
      honesty = TRUE,
      tune.parameters = "all"
    )
    
    # 对所有样本预测控制组条件均值
    mu_0_hat <- predict(rf_control, X)$predictions
    cat("控制组条件均值估计完成\n")
    
  }, error = function(e) {
    cat("估计控制组条件均值时出错:", e$message, "\n")
    mu_0_hat <- rep(mean(Y[control_indices]), n)
  })
} else {
  cat("控制组样本不足，使用简单均值\n")
  mu_0_hat <- rep(mean(Y[control_indices]), n)
}

# 估计处理组条件均值 mu_1(X)
# 只使用处理组数据 (W = 1)
treatment_indices <- which(W == 1)
if(length(treatment_indices) > 50) {  # 确保有足够的处理组样本
  tryCatch({
    rf_treatment <- regression_forest(
      X = X[treatment_indices, , drop = FALSE],
      Y = Y[treatment_indices],
      num.trees = 1000,
      sample.fraction = 0.5,
      mtry = min(ceiling(sqrt(p) + 20), p),
      honesty = TRUE,
      tune.parameters = "all"
    )
    
    # 对所有样本预测处理组条件均值
    mu_1_hat <- predict(rf_treatment, X)$predictions
    cat("处理组条件均值估计完成\n")
    
  }, error = function(e) {
    cat("估计处理组条件均值时出错:", e$message, "\n")
    mu_1_hat <- rep(mean(Y[treatment_indices]), n)
  })
} else {
  cat("处理组样本不足，使用简单均值\n")
  mu_1_hat <- rep(mean(Y[treatment_indices]), n)
}

# 从条件均值计算CATE
tau_hat_from_means <- mu_1_hat - mu_0_hat

# ============================================================================
# 第四部分：计算平均处理效应 (ATE)
# ============================================================================

cat("\n计算平均处理效应...\n")

# 方法1: 直接从CATE估计计算ATE
ate_hat_1 <- mean(tau_hat)

# 方法2: 从条件均值估计计算ATE
ate_hat_2 <- mean(tau_hat_from_means)

# 方法3: 使用grf的内置函数计算ATE及其置信区间
tryCatch({
  ate_result <- average_treatment_effect(cf)
  ate_hat_3 <- ate_result[1]
  ate_se <- ate_result[2]
  ate_ci_lower <- ate_hat_3 - 1.96 * ate_se
  ate_ci_upper <- ate_hat_3 + 1.96 * ate_se
  
  cat("ATE估计（带置信区间）完成\n")
}, error = function(e) {
  cat("计算ATE置信区间时出错:", e$message, "\n")
  ate_hat_3 <- ate_hat_1
  ate_se <- NA
  ate_ci_lower <- NA
  ate_ci_upper <- NA
})

# 真实ATE
ate_true <- mean(tau_true)

# ============================================================================
# 第五部分：结果输出和评估
# ============================================================================

cat("\n", paste0(rep("=", 60), collapse=""), "\n")
cat("                    结果总结\n")
cat(paste0(rep("=", 60), collapse=""), "\n")

# ATE结果比较
cat("\n【平均处理效应 (ATE) 估计结果】\n")
cat(sprintf("真实ATE:                    %.4f\n", ate_true))
cat(sprintf("方法1 (直接CATE均值):        %.4f  (偏差: %.4f)\n", 
            ate_hat_1, ate_hat_1 - ate_true))
cat(sprintf("方法2 (条件均值差):          %.4f  (偏差: %.4f)\n", 
            ate_hat_2, ate_hat_2 - ate_true))
if(!is.na(ate_hat_3)) {
  cat(sprintf("方法3 (grf内置函数):         %.4f  (偏差: %.4f)\n", 
              ate_hat_3, ate_hat_3 - ate_true))
  if(!is.na(ate_se)) {
    cat(sprintf("95%%置信区间:                [%.4f, %.4f]\n", 
                ate_ci_lower, ate_ci_upper))
    cat(sprintf("标准误:                     %.4f\n", ate_se))
  }
}

# 条件均值估计精度
cat("\n【条件均值估计精度】\n")
rmse_mu0 <- sqrt(mean((mu_0_hat - mu_0_true)^2))
rmse_mu1 <- sqrt(mean((mu_1_hat - mu_1_true)^2))
rmse_tau <- sqrt(mean((tau_hat - tau_true)^2))

cat(sprintf("控制组条件均值 RMSE:         %.4f\n", rmse_mu0))
cat(sprintf("处理组条件均值 RMSE:         %.4f\n", rmse_mu1))
cat(sprintf("CATE估计 RMSE:              %.4f\n", rmse_tau))

# 相关性分析
cat("\n【估计与真实值相关性】\n")
cor_mu0 <- cor(mu_0_hat, mu_0_true)
cor_mu1 <- cor(mu_1_hat, mu_1_true)
cor_tau <- cor(tau_hat, tau_true)

cat(sprintf("控制组条件均值相关性:        %.4f\n", cor_mu0))
cat(sprintf("处理组条件均值相关性:        %.4f\n", cor_mu1))
cat(sprintf("CATE相关性:                 %.4f\n", cor_tau))

# ============================================================================
# 第六部分：数据可视化
# ============================================================================

cat("\n开始生成可视化图表...\n")

# 创建结果数据框
results_df <- data.frame(
  mu_0_true = mu_0_true,
  mu_0_hat = mu_0_hat,
  mu_1_true = mu_1_true,
  mu_1_hat = mu_1_hat,
  tau_true = tau_true,
  tau_hat = tau_hat,
  X1 = X[,1],
  X2 = X[,2],
  W = W,
  Y = Y
)

# 图1: 真实值 vs 估计值散点图
tryCatch({
  p1 <- ggplot(results_df, aes(x = tau_true, y = tau_hat)) +
    geom_point(alpha = 0.6, color = "steelblue") +
    geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
    labs(
      title = "CATE估计精度",
      subtitle = paste0("相关性: ", round(cor_tau, 3), ", RMSE: ", round(rmse_tau, 3)),
      x = "真实CATE",
      y = "估计CATE"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5),
          plot.subtitle = element_text(hjust = 0.5))
  
  print(p1)
  
}, error = function(e) {
  cat("生成CATE散点图时出错:", e$message, "\n")
})

# 图2: 条件均值估计比较
tryCatch({
  p2 <- results_df %>%
    select(mu_0_true, mu_0_hat, mu_1_true, mu_1_hat) %>%
    mutate(id = row_number()) %>%
    pivot_longer(cols = -id, names_to = "type", values_to = "value") %>%
    separate(type, into = c("group", "estimate_type"), sep = "_(?=true|hat)") %>%
    pivot_wider(names_from = estimate_type, values_from = value) %>%
    ggplot(aes(x = true, y = hat, color = group)) +
    geom_point(alpha = 0.6) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed") +
    facet_wrap(~group, labeller = labeller(group = c("mu_0" = "控制组 (μ₀)", "mu_1" = "处理组 (μ₁)"))) +
    labs(
      title = "条件均值估计精度比较",
      x = "真实值",
      y = "估计值"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5),
          legend.position = "none")
  
  print(p2)
  
}, error = function(e) {
  cat("生成条件均值比较图时出错:", e$message, "\n")
})

# 图3: CATE分布直方图
tryCatch({
  p3 <- ggplot(results_df) +
    geom_histogram(aes(x = tau_true, fill = "真实CATE"), alpha = 0.7, bins = 30) +
    geom_histogram(aes(x = tau_hat, fill = "估计CATE"), alpha = 0.7, bins = 30) +
    labs(
      title = "CATE分布比较",
      x = "CATE值",
      y = "频数",
      fill = "类型"
    ) +
    scale_fill_manual(values = c("真实CATE" = "red", "估计CATE" = "blue")) +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5))
  
  print(p3)
  
}, error = function(e) {
  cat("生成CATE分布图时出错:", e$message, "\n")
})

cat("\n可视化完成！\n")

# ============================================================================
# 第七部分：保存结果
# ============================================================================

# 保存主要结果到CSV文件
tryCatch({
  # 创建汇总结果
  summary_results <- data.frame(
    Metric = c("ATE_True", "ATE_Method1", "ATE_Method2", "ATE_Method3",
               "RMSE_mu0", "RMSE_mu1", "RMSE_tau",
               "Cor_mu0", "Cor_mu1", "Cor_tau"),
    Value = c(ate_true, ate_hat_1, ate_hat_2, 
              ifelse(is.na(ate_hat_3), NA, ate_hat_3),
              rmse_mu0, rmse_mu1, rmse_tau,
              cor_mu0, cor_mu1, cor_tau)
  )
  
  write.csv(summary_results, "conditional_mean_results_summary.csv", row.names = FALSE)
  write.csv(results_df, "conditional_mean_detailed_results.csv", row.names = FALSE)
  
  cat("\n结果已保存到CSV文件:\n")
  cat("- conditional_mean_results_summary.csv (汇总结果)\n")
  cat("- conditional_mean_detailed_results.csv (详细结果)\n")
  
}, error = function(e) {
  cat("保存结果时出错:", e$message, "\n")
})

cat("\n", paste0(rep("=", 60), collapse=""), "\n")
cat("                 分析完成！\n")
cat(paste0(rep("=", 60), collapse=""), "\n")

# 清理大型对象以释放内存
rm(cf, rf_control, rf_treatment)
gc()  # 垃圾回收

cat("\n内存清理完成。\n")