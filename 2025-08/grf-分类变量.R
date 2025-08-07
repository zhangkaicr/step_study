library(grf)
# install.packages("https://github.com/grf-labs/sufrep/blob/master/sufrep_0.1.0.tar.gz?raw=true", repos = NULL, type = "source")
library(sufrep)
library(tidyverse)



# 使用品牌名创建一个分类变量列
# 以下代码在 mtcars 数据框中添加一个新列 brand，该列存储每辆车的品牌名
# 示例：将 'Mazda RX4' 转换为 'Mazda'
df <- within(mtcars, {
  # E.g. 'Mazda RX4' --> 'Mazda'
  brand <- factor(sapply(rownames(mtcars), function(x) strsplit(x, " ")[[1]][1]))
})

# 定义连续变量，选取 cyl 和 qsec 列作为连续变量
x <- c("cyl", "qsec") # Continuous variables

# 定义分类变量，选取 brand 列作为分类变量
g <- c("brand")       # Categorical variable

# 查看数据框 df 中连续变量和分类变量组成的子集的前几行
head(df[c(x, g)])

rf <- regression_forest(X=df[c(x, g)], Y=df$mpg)

# 方法1：将变量转换为数字
# 从数据框 df 中选取连续变量和分类变量组成的子集，并将分类变量 brand 转换为数值类型
# 将转换后的数据存储在新的数据框 X1 中
X1 <- within(df[c(x, g)], brand <- as.numeric(brand))
# 使用转换后的特征矩阵 X1 和目标变量 df$mpg 构建回归森林模型
rf1 <- regression_forest(X1, df$mpg)
# 查看转换后的数据框 X1 的前几行，方便检查数据转换结果
X1 %>% head()

# 方法2：独热编码
# 使用 model.matrix 函数对数据框 df 中选取的连续变量和分类变量进行独热编码
# ~ 0 + . 表示不包含截距项，对所有变量进行编码
X2 <- model.matrix(~ 0 + ., df[c(x, g)])
# 使用独热编码后的特征矩阵 X2 和目标变量 df$mpg 构建回归森林模型
rf2 <- regression_forest(X2, df$mpg)
X2 %>% head()

# 方法3：使用'sufrep'包进行‘平均’编码
# 使用 make_encoder 函数创建一个编码器对象
# 输入连续变量 df[x]、分类变量 df$brand，指定编码方法为 'means'（平均编码）
encoder <- make_encoder(df[x], df$brand, method="means")
# 使用创建好的编码器对象对连续变量 df[x] 和分类变量 df$brand 进行平均编码
# 将编码结果存储在 X3 中
X3 <- encoder(df[x], df$brand)
# 此处注释可能是编码结果的维度信息，但原代码中以注释形式存在，推测是打印结果

# 使用平均编码后的特征矩阵 X3 和目标变量 df$mpg 构建回归森林模型
rf3 <- regression_forest(X3, df$mpg)

# 计算三种不同编码方式下回归森林模型的均方误差（MSE）
# 计算将分类变量转换为整数编码时模型的均方误差
mse1 <- mean(rf1$debiased.error)
# 计算将分类变量进行独热编码时模型的均方误差
mse2 <- mean(rf2$debiased.error)
# 计算使用 sufrep 包进行平均编码时模型的均方误差
mse3 <- mean(rf3$debiased.error)

# 打印提示信息，说明后续输出的是不同分类变量表示方式下的均方误差
print("MSE when representing categorical variables as...")

# 打印将分类变量转换为整数编码时的均方误差
print(paste0("Integers: ", mse1))

# 打印将分类变量进行独热编码时的均方误差
print(paste0("One-hot vectors: ", mse2))

# 打印使用 sufrep 包进行平均编码时的均方误差
print(paste0("'Means' encoding [sufrep]: ", mse3))
