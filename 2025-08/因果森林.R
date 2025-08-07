library(dplyr)
library(grf)          #  causal_forest()
library(ggplot2)
library(patchwork)    #  Combine ggplots
library(hstats)       #  Friedman's H, PDP
library(kernelshap)   #  General SHAP
library(shapviz)      #  SHAP plots
library(readxl)
setwd('D://文档//因果森林')
path = "run.xlsx"
data <- read_excel(path, sheet = 1)
W <- as.integer(data$treatment)      # 0=placebo, 1=treatment
table(W)
Y <- as.numeric(data$`24小时内发生PONV`)  # Y=1: post-ERCP pancreatitis (bad)
mean(Y)  # 0.1312292
mean(Y[W == 1]) - mean(Y[W == 0])      # -0.07785568
xvars <- c(  "age",         # Age in years
             "propofol",    # 丙泊酚  
             "Rocuronium",  # 罗库溴铵  
             "LOSPACU",     # 麻醉后监护病房（PACU）的停留时间 
             "HB",          # 血红蛋白
             "MD",          # “Mitral regurgitation”（二尖瓣反流）
             "CHD"         # “Coronary Heart Disease” 的缩写，即冠心病
             )
X <- data |>  
  mutate_if(is.factor, function(v) as.integer(v)) |>   
  mutate_if(is.character, function(v) as.integer(v)) |>   
  select_at(xvars)
head(X)
summary(X)



fit <- causal_forest(  
  X = X,  
  Y = Y,  
  W = W,  
  num.trees = 1000,  
  mtry = 4,  
  sample.fraction = 0.7,  
  seed = 1,  
  ci.group.size = 1,
  )


# 训练因果森林模型
# causal_forest <- causal_forest(X, Y, W)

# 获取平均处理效果 (ATE)
ate_estimate <- average_treatment_effect(fit)
print(paste("Average Treatment Effect Estimate:", ate_estimate))
# 提取点估计和标准误差
point_estimate <- ate_estimate["estimate"]
std_error <- ate_estimate["std.err"]
# 计算 95% 置信区间
lower_bound <- point_estimate - 1.96 * std_error
upper_bound <- point_estimate + 1.96 * std_error
cat("95% Confidence Interval for ATE: [", lower_bound, ", ", upper_bound, "]\n", sep = "")

# 获取个体处理效果 (ITE)
individual_effects <- predict(fit, X)$predictions
head(individual_effects)

# 变量的重要性
imp <- sort(setNames(variable_importance(fit), xvars))
par(mai = c(0.7, 2, 0.2, 0.2))
barplot(imp, horiz = TRUE, las = 1, col = "orange")
pred_fun <- function(object, newdata, ...) {  
  predict(object, newdata, ...)$predictions
}

pdps <- lapply(xvars, function(v) plot(partial_dep(fit, v, X = X, pred_fun = pred_fun)))
wrap_plots(pdps, guides = "collect", ncol = 3) &  
  # ylim(c(-0.11, -0.06)) &  
  ylab("Treatment effect")               

H <- hstats(fit, X = X, pred_fun = pred_fun, verbose = FALSE)
plot(H)
partial_dep(fit, v = "age", X = X, BY = "LOSPACU", pred_fun = pred_fun) |>   
  plot()



# SHAP分析
# Explaining one CATE
kernelshap(fit, X = X[2, ], bg_X = X, pred_fun = pred_fun) |>   
  shapviz() |>   
  sv_waterfall() +  
  xlab("Prediction")
# Explaining all CATEs globally
system.time(  # 13 min  
  ks <- kernelshap(fit, X = X, pred_fun = pred_fun)  
  )

shap_values <- shapviz(ks)

sv_importance(shap_values)
sv_importance(shap_values, kind = "bee")
sv_dependence(shap_values, v = xvars) + 
  plot_layout(ncol = 3) &  
  ylim(c(-0.04, 0.03))



