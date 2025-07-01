library(quantreg)
data(mtcars)


# 使用rq()函数进行分位数回归，建立mpg与wt的关系模型
# rq()函数用于拟合分位数回归，默认为中位数(tau=0.5)回归
rqfit <- rq(mpg ~ wt, tau = 0.5, data = mtcars)

# 显示回归结果
rqfit

# 显示回归结果的详细统计信息，包括系数估计、标准误、t值和p值等
summary(rqfit)

# 查看summary.rq函数的帮助文档
?summary.rq

# 绘制散点图和回归线
# plot()函数绘制散点图，pch=16设置点的形状，main设置图标题
plot(mpg ~ wt, data = mtcars, pch = 16, main = "mpg ~ wt")

# 添加最小二乘回归线(红色虚线)
# lm()函数进行普通线性回归，abline()添加回归线
abline(lm(mpg ~ wt, data = mtcars), col = "red", lty = 2)

# 添加分位数回归线(蓝色虚线)
abline(rq(mpg ~ wt, data = mtcars), col = "blue", lty = 2)

# 添加图例
# legend()函数在右上角添加图例，说明两条线分别代表普通线性回归(lm)和分位数回归(rq)
legend("topright", legend = c("lm", "rq"), col = c("red", "blue"), lty = 2)



# 创建新的响应变量y，将mtcars数据集中的mpg变量和两个新值(40,36)组合在一起
y <- c(mtcars$mpg, 40, 36)

# 创建新的预测变量x，将mtcars数据集中的wt变量和两个新值(5,4)组合在一起
x <- c(mtcars$wt, 5, 4)

# 绘制散点图，x为预测变量，y为响应变量
# pch=16设置点的形状为实心圆点，main设置图标题
plot(y ~ x, pch = 16, main = "mpg ~ wt")

# 添加两个新的观测点，用深橙色标记
# points()函数用于在已有图形上添加点
points(c(5, 4), c(40, 36), pch = 16, col = "dark orange")

# 添加原始数据的最小二乘回归线(红色虚线)
abline(lm(mpg ~ wt, data = mtcars), col = "red", lty = 2)

# 添加包含新观测点的最小二乘回归线(红色实线)
abline(lm(y ~ x), col = "red")

# 添加原始数据的分位数回归线(蓝色虚线)
abline(rq(mpg ~ wt, data = mtcars), col = "blue", lty = 2)

# 添加包含新观测点的分位数回归线(蓝色实线)
abline(rq(y ~ x), col = "blue")


multi_rqfit <- rq(mpg ~ wt, data = mtcars, tau = seq(0, 1, by = 0.1))
multi_rqfit


# 绘制不同分位数的回归线
# 创建一个颜色向量，从浅红色到深红色再到黑色，用于区分不同分位数的回归线
colors <- c("#ffe6e6", "#ffcccc", "#ff9999", "#ff6666", "#ff3333",
            "#ff0000", "#cc0000", "#b30000", "#800000", "#4d0000", "#000000")

# 绘制基础散点图
# plot()函数绘制mpg与wt的散点图，pch=16设置点的形状为实心圆点
plot(mpg ~ wt, data = mtcars, pch = 16, main = "mpg ~ wt")

# 使用循环添加不同分位数的回归线
# 遍历multi_rqfit系数矩阵的每一列(每一列代表一个分位数的回归系数)
for (j in 1:ncol(multi_rqfit$coefficients)) {
    # abline()函数使用coef(multi_rqfit)[,j]获取第j个分位数的回归系数
    # 使用colors[j]为每条回归线设置不同的颜色，从浅到深表示分位数从低到高
    abline(coef(multi_rqfit)[, j], col = colors[j])
}



# 无截距
rq(mpg ~ wt - 1, data = mtcars)


# 加法模型
rq(mpg ~ wt + cyl, data = mtcars)


# 具有交互项的模型
rq(mpg ~ wt * cyl, data = mtcars)


# 对所有其他预测变量进行拟合
rq(mpg ~ ., data = mtcars)

# 二元逻辑回归的分位数回归示例

# 生成模拟数据
set.seed(123) # 设置随机种子，确保结果可重复
n <- 1000 # 样本量

# 生成自变量
x1 <- rnorm(n) # 从标准正态分布生成连续变量x1
x2 <- rbinom(n, 1, 0.5) # 生成二元分类变量x2，服从伯努利分布

# 生成因变量y（二元分类变量）
# 使用logistic函数生成概率，然后根据概率生成二元结果
prob <- 1 / (1 + exp(-(0.5 + 0.8 * x1 + 1.2 * x2)))
y <- rbinom(n, 1, prob)

# 创建数据框
test_data <- data.frame(y = y, x1 = x1, x2 = x2)

# 使用quantreg包进行分位数回归
# 对不同分位数进行拟合
taus <- c(0.1, 0.25, 0.5, 0.75, 0.9)
binary_rq_fits <- list()

for(tau in taus) {
    # 对每个分位数进行拟合
    binary_rq_fits[[as.character(tau)]] <- rq(y ~ x1 + x2, 
                                             data = test_data, 
                                             tau = tau)
}

# 打印各个分位数的回归结果
for(tau in taus) {
    cat("\n分位数 =", tau, "的回归结果：\n")
    print(summary(binary_rq_fits[[as.character(tau)]]))
}

# 绘制散点图和不同分位数的回归线（以x1为例）
plot(y ~ x1, data = test_data, 
     main = "Binary Quantile Regression", 
     xlab = "x1", ylab = "y",
     pch = 16, col = rgb(0,0,0,0.3))

# 添加不同分位数的回归线
colors <- rainbow(length(taus))
x_range <- seq(min(x1), max(x1), length.out = 100)

for(i in seq_along(taus)) {
    tau <- taus[i]
    fit <- binary_rq_fits[[as.character(tau)]]
    
    # 计算回归线
    y_pred <- fit$coefficients[1] + fit$coefficients[2] * x_range
    
    # 添加回归线
    lines(x_range, y_pred, col = colors[i], lwd = 2)
}

# 添加图例
legend("topright", 
       legend = paste("tau =", taus),
       col = colors,
       lwd = 2,
       title = "分位数")

# 比较不同分位数的系数
# 创建系数矩阵
coef_matrix <- sapply(binary_rq_fits, function(x) coef(x))
colnames(coef_matrix) <- paste("tau =", taus)
rownames(coef_matrix) <- c("Intercept", "x1", "x2")

# 打印系数矩阵
cat("\n不同分位数的回归系数：\n")
print(round(coef_matrix, 4))

