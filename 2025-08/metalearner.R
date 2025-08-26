# 设置清华CRAN镜像 - 临时设置
# 在当前R会话中生效，重启R后需要重新设置

# 设置清华大学CRAN镜像
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))

# 验证镜像设置
cat("当前CRAN镜像设置为:", getOption("repos")["CRAN"], "\n")

install.packages(c(
  "doParallel",           # 并行计算支持
  "plyr",                 # 数据操作工具（tidyverse的前身）
  "dbarts"                # 贝叶斯加性回归树
))

# 安装BART包（贝叶斯加性回归树）
install.packages("BART")

# 安装rBayesianOptimization（贝叶斯优化）
install.packages("rBayesianOptimization")

# 安装distances包（距离计算）
install.packages("distances")

# 安装quickmatch包（快速匹配算法）
install.packages("quickmatch")

# 3. 安装Rforestry包（需要从GitHub安装）
# 这个包可能需要从GitHub安装
if (!require("devtools")) {
  install.packages("devtools")  # 安装devtools用于GitHub包安装
}

# 尝试从CRAN安装Rforestry
tryCatch({
  install.packages("Rforestry")
}, error = function(e) {
  # 如果CRAN安装失败，从GitHub安装
  cat("从CRAN安装Rforestry失败，尝试从GitHub安装...\n")
  devtools::install_github("forestry-labs/Rforestry")
})

# 4. 验证所有包是否安装成功
required_packages <- c(
  "doParallel", "plyr", "rBayesianOptimization", 
  "dbarts", "Rforestry", "quickmatch", 
  "distances", "BART"
)

# 检查每个包是否可以加载
cat("检查依赖包安装状态:\n")
for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("✓", pkg, "安装成功\n")
  } else {
    cat("✗", pkg, "安装失败\n")
  }
}

# 5. 现在尝试安装causalToolbox
cat("\n开始安装causalToolbox...\n")
devtools::install_github("forestry-labs/causalToolbox")




library(causalToolbox)
library(rlearner)
library(grf)
library(ggplot2)
library(dplyr)

# 读取数据
data <- read.csv("metalearner_data.csv")

# 准备数据
X <- data %>% select(age, bmi, sex)
Y <- data$outcome
W <- data$treatment # 在R中，习惯用W表示treatment

head(data)

# # 1. S-Learner
# # 'S'代表S-Learner，'RF'代表使用Random Forest作为基础学习器
# s_learner_fit <- S_BART(feat = X, tr = W, yobs = Y)
# s_learner_cate <- EstimateCate(s_learner_fit, X)

rlearner::
# 4. R-Learner (使用 rlearner 包)
# 需要将X转换为矩阵
X_mat <- as.matrix(X)
# rlearner也需要估计倾向得分和结果模型
# 这里我们使用随机森林作为基础模型
r_learner_fit <- rlasso(X_mat, W, Y)
r_learner_cate <- predict(r_learner_fit, X_mat)

# 5. Causal Forest (使用 grf 包)
causal_forest_fit <- causal_forest(X = X_mat, Y = Y, W = W)
causal_forest_cate <- predict(causal_forest_fit, X_mat)$predictions

# 将结果合并
data$r_cate_r <- r_learner_cate
data$cf_cate_r <- causal_forest_cate

print("rlearner 和 grf CATE 估计值预览:")
head(data %>% select(r_cate_r, cf_cate_r))


# 比较不同算法的CATE估计分布
library(tidyr)
data %>%
  select(contains("_cate_r")) %>%
  gather(key = "method", value = "cate") %>%
  ggplot(aes(x = cate, fill = method)) +
  geom_density(alpha = 0.5) +
  ggtitle("Distribution of CATE Estimates from Different R Packages") +
  theme_minimal()
