# 0.安装并加载所需包及配置环境-----------------------

# 设定清华镜像
# options("repos" = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))
# install.packages("quartets")

library(tidyverse)
library(quartets)
library(finalfit)

# 查看包的所有函数及数据
ls("package:quartets")



# 1. Anscombe’s Quartet 安斯库姆四重奏----------------------------

# 绘制Anscombe四重奏散点图并添加线性回归线
ggplot(anscombe_quartet, aes(x = x, y = y)) +
  geom_point() + 
  geom_smooth(method = "lm", formula = "y ~ x") +
  facet_wrap(~dataset)

# 计算每个数据集的统计量并格式化输出
anscombe_quartet |>
  group_by(dataset) |>
  summarise(mean_x = mean(x),
            var_x = var(x),
            mean_y = mean(y),
            var_y = var(y),
            cor = cor(x, y)) |>
  knitr::kable(digits = 2)


# 2. Datasaurus Dozen 数据aurus十二组-------------------

ggplot(datasaurus_dozen, aes(x = x, y = y)) +
  geom_point() + 
  geom_smooth(method = "lm", formula = "y ~ x") +
  facet_wrap(~dataset)

  # 对 datasaurus_dozen 数据框按 dataset 分组
  datasaurus_dozen |>
  group_by(dataset) |>
  # 计算每组 x 与 y 的均值、方差及相关系数
  summarise(mean_x = mean(x),      # x 的均值
            var_x  = var(x),       # x 的方差
            mean_y = mean(y),      # y 的均值
            var_y  = var(y),       # y 的方差
            cor    = cor(x, y)) |>  # x 与 y 的皮尔逊相关系数
  # 使用 knitr::kable 以 2 位小数格式输出表格
  knitr::kable(digits = 2)



# 3. Causal Quartet 因果四重奏----------------------------

# 使用 ggplot2 绘制因果四重奏数据集的散点图与线性回归线
ggplot(causal_quartet,                           # 指定数据集：causal_quartet
       aes(x = exposure,                          # 将暴露变量 exposure 映射到 x 轴
           y = outcome)) +                       # 将结果变量 outcome 映射到 y 轴
  geom_point() +                                  # 添加散点图层，展示每个观测点的位置
  geom_smooth(method = "lm",                      # 添加平滑回归线，使用线性回归方法（lm）
              formula = "y ~ x") +                # 指定回归公式：y 关于 x 的简单线性模型
  facet_wrap(~dataset)                            # 按照 dataset 变量进行分面，每个子图展示一个数据集

# 从因果四重奏数据集 causal_quartet 开始管道操作
causal_quartet |>
  # 按照 dataset 变量进行分组，后续操作将基于每个子数据集独立执行
  group_by(dataset) |>
  # 对每个分组仅提取第一行观测（即每组的头一条记录），用于快速查看各子数据集的首行样本
  slice_head()

unique(causal_quartet$dataset)

explanatory = c("exposure", "covariate")
dependent = 'outcome'

causal_quartet %>%
filter(dataset == "(1) Collider") %>% 
  finalfit.lm(dependent,explanatory) %>% 
  knitr::kable()

causal_quartet %>%
filter(dataset == "(2) Confounder" )%>% 
  finalfit.lm(dependent,explanatory) %>% 
  knitr::kable()

causal_quartet %>%
filter(dataset == "(3) Mediator") %>% 
  finalfit.lm(dependent,explanatory) %>% 
  knitr::kable()

causal_quartet %>%
filter(dataset == "(4) M-Bias") %>% 
  finalfit.lm(dependent,explanatory) %>% 
  knitr::kable()

# 因果四重奏：按数据集分组后，分别拟合两个模型并计算 X 与协变量 Z 的相关系数
causal_quartet |>
  nest_by(dataset) |>                                   # 将每个数据集嵌套成一行
  mutate(`Y ~ X` = round(coef(lm(outcome ~ exposure, data = data))[2], 2),          # 仅含暴露变量的回归系数
         `Y ~ X + Z` = round(coef(lm(outcome ~ exposure + covariate, data = data))[2], 2),  # 加入协变量后的回归系数
         `Correlation of X and Z` = round(cor(data$exposure, data$covariate), 2)) |> # 暴露与协变量的相关系数
  select(-data, `Data generating mechanism` = dataset) |>  # 移除嵌套数据列，并重命名 dataset 列
  knitr::kable()                                         # 用 knitr 输出格式化表格







# 4. Interaction Triptych 交互三要素------------------------------

# 使用 ggplot2 绘制交互三要素数据集的散点图与回归线
ggplot(interaction_triptych, aes(x, y)) +                 # 指定数据集与映射：x 轴为 x 变量，y 轴为 y 变量
  geom_point(shape = "o") +                              # 添加散点图层，形状为圆圈（"o" 即默认圆圈）
  geom_smooth(method = "lm", formula = "y ~ x") +        # 添加线性回归平滑线，使用最小二乘法拟合 y ~ x
  facet_grid(dataset ~ moderator)                        # 按 dataset（行）与 moderator（列）进行网格分面，展示不同组合下的图形


# 5. Rashomon Quartet 罗生门四重奏-------------------


# 设定随机种子，保证结果可复现
set.seed(1568)

# 加载 tidymodels 全家桶（建模、预处理、评估等）
library(tidymodels)

# 加载 DALEXtra，用于模型可解释性（SHAP、LIME 等）
library(DALEXtra)

# 用 rashomon_quartet_train 数据创建配方：以 y 为因变量，其余所有变量为自变量
rec <- recipe(y ~ ., data = rashomon_quartet_train)

### 1. 回归树模型

# 构建工作流：先加配方，再加模型
wf_tree <- workflow() |>
  add_recipe(rec) |>                                           # 引入数据预处理配方
  add_model(                                                   # 添加回归树模型
    decision_tree(mode = "regression", engine = "rpart",       # 指定为回归任务，使用 rpart 引擎
                  tree_depth = 3, min_n = 250)                # 限制树深 3 层，叶节点最小样本 250
  )

# 在训练集上拟合回归树
tree <- fit(wf_tree, rashomon_quartet_train)

# 用 DALEXtra 包装模型，准备可解释性分析
exp_tree <- explain_tidymodels(
  tree, 
  data = rashomon_quartet_test[, -1],   # 测试集去掉第一列（y）
  y = rashomon_quartet_test[, 1],       # 测试集的真实 y
  verbose = FALSE,                      # 不打印冗余信息
  label = "decision tree")              # 给模型起个名字

## 2. 线性回归模型

# 沿用前面的工作流，仅替换模型为线性回归
wf_linear <- wf_tree |>
  update_model(linear_reg())            # 默认最小二乘线性回归

# 在训练集上拟合线性模型
lin <- fit(wf_linear, rashomon_quartet_train)

# 同样包装，方便后续解释
exp_lin <- explain_tidymodels(
  lin, 
  data = rashomon_quartet_test[, -1], 
  y = rashomon_quartet_test[, 1],
  verbose = FALSE, 
  label = "linear regression")

## 3. 随机森林模型 

# 继续沿用工作流，替换为随机森林
wf_rf <- wf_tree |>
  update_model(rand_forest(mode = "regression", 
                           engine = "randomForest", 
                           trees = 100))  # 100 棵树，默认其他参数

# 训练随机森林
rf <- fit(wf_rf, rashomon_quartet_train)

# 包装模型
exp_rf <- explain_tidymodels(
  rf, 
  data = rashomon_quartet_test[, -1], 
  y = rashomon_quartet_test[, 1],
  verbose = FALSE, 
  label = "random forest")

## 4. 神经网络模型

# 加载专门用于神经网络的包
library(neuralnet)
# install.packages("neuralnet")   # 如未安装可取消注释

# 直接调用 neuralnet 函数拟合前馈神经网络
nn <- neuralnet(
  y ~ .,                        # 公式：y 为因变量，其余为自变量
  data = rashomon_quartet_train, 
  hidden = c(8, 4),             # 两层隐藏层，神经元数分别为 8 和 4
  threshold = 0.05)             # 收敛阈值 0.05

# 用 DALEXtra 包装神经网络（注意：neuralnet 并非 tidymodels 体系，但 DALEXtra 仍能处理）
exp_nn <- explain_tidymodels(
  nn, 
  data = rashomon_quartet_test[, -1], 
  y = rashomon_quartet_test[, 1],
  verbose = FALSE, 
  label = "neural network")

# 将四个已解释的模型对象打包成列表，逐一调用 model_performance 计算 R² 与 RMSE 等指标
mp <- map(list(exp_tree, exp_lin, exp_rf, exp_nn), model_performance)

# 新建一个 tibble：第一列是模型名称，第二列提取每个模型对象的 R²，第三列提取 RMSE
tibble(
  model = c("Decision tree", "Linear regression", "Random forest", "Neural network"),  # 对应四个模型
  R2    = map_dbl(mp, ~ .x$measures$r2),   # 从每个性能结果中提取 R² 值
  RMSE  = map_dbl(mp, ~ .x$measures$rmse)  # 从每个性能结果中提取 RMSE 值
) |>
  knitr::kable(digits = 2)  # 用 knitr 输出表格，保留两位小数

# 计算并解释 R² 与 RMSE 的意义
# R²（决定系数）= 1 - SS_res / SS_tot
#   SS_res：模型预测值与真实值之差的平方和（残差平方和）
#   SS_tot：真实值与其均值之差的平方和（总平方和）
# 意义：衡量模型对数据变异的解释比例，越接近 1 表示拟合越好

# RMSE（均方根误差）= sqrt( mean( (y_true - y_pred)^2 ) )
# 意义：反映预测值与真实值的平均偏差，单位与因变量一致，越小越好

# 对决策树模型计算偏依赖剖面（PDP），N=NULL 表示使用全部样本
pd_tree <- model_profile(exp_tree, N = NULL)

# 对线性回归模型计算偏依赖剖面，同样使用全部样本
pd_lin <- model_profile(exp_lin, N = NULL)

# 对随机森林模型计算偏依赖剖面
pd_rf <- model_profile(exp_rf, N = NULL)

# 对神经网络模型计算偏依赖剖面
pd_nn <- model_profile(exp_nn, N = NULL)

# 将四个模型的偏依赖剖面结果绘制在同一张图上，便于直观比较各变量对预测的影响
plot(pd_tree, pd_nn, pd_rf, pd_lin)


# 6. Gelman Variation and Heterogeneity Causal Quartets 格尔曼变异与异质性因果四重奏-------------

# 绘制 variation_causal_quartet 数据：以协变量 covariate 为 x 轴，结果变量 outcome 为 y 轴
# 将 exposure 因子化后映射为颜色，半透明散点便于观察重叠
ggplot(variation_causal_quartet, aes(x = covariate, y = outcome, color = factor(exposure))) + 
  geom_point(alpha = 0.5) +                       # 添加散点图层，透明度 0.5
  facet_wrap(~ dataset) +                         # 按 dataset 分面，一行多列展示四个子图
  labs(color = "exposure group")                   # 图例标题改为“exposure group”


# 计算每个数据集的 ATE（平均处理效应）
variation_causal_quartet |>
  nest_by(dataset) |>                             # 按 dataset 分组嵌套，每行一个子数据框
  mutate(
    # 对嵌套数据拟合线性模型 outcome ~ exposure，提取 exposure 的系数（即 ATE），保留两位小数
    ATE = round(coef(lm(outcome ~ exposure, data = data))[2], 2)
  ) |>
  select(-data, dataset) |>                        # 去掉嵌套数据列，保留 dataset 与 ATE
  knitr::kable()                                   # 用 knitr 输出格式化表格


# 使用 ggplot2 绘制 heterogeneous_causal_quartet 数据集的散点图
ggplot(heterogeneous_causal_quartet,                       # 指定数据集：heterogeneous_causal_quartet
       aes(x = covariate,                                  # 将协变量 covariate 映射到 x 轴
           y = outcome,                                    # 将结果变量 outcome 映射到 y 轴
           color = factor(exposure))) +                    # 将暴露变量 exposure 转换为因子后映射为点的颜色
  geom_point(alpha = 0.5) +                               # 添加散点图层，透明度设为 0.5，便于观察重叠点
  facet_wrap(~ dataset) +                                  # 按照 dataset 变量进行分面，一行多列展示四个子图
  labs(color = "exposure group")                           # 设置颜色图例标题为“exposure group”



  heterogeneous_causal_quartet |>                         # 从 heterogeneous_causal_quartet 数据框开始管道操作
  nest_by(dataset) |>                                     # 按 dataset 分组，并将每组数据嵌套成一行（生成 list-col 列 data）
  mutate(                                                 # 在嵌套后的每一行上新增一列 ATE
    ATE = round(                                          # 对计算结果四舍五入保留两位小数
      coef(                                               # 提取回归系数向量
        lm(outcome ~ exposure, data = data)               # 用嵌套数据拟合简单线性回归：结果 ~ 暴露
      )[2],                                               # 取第二个系数，即 exposure 的回归系数（平均处理效应 ATE）
      2)                                                   # 保留两位小数
  ) |>
  select(-data, dataset) |>                               # 去掉嵌套数据列 data，同时保留 dataset 与 ATE 列
  knitr::kable()                                          # 用 knitr::kable() 输出美观的 Markdown 表格
