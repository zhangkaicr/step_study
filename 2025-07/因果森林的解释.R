# 加载所需的R包
library(medicaldata)  # 提供医疗数据集
library(tidyverse)    # 数据处理和可视化工具集
library(grf)          # 用于构建因果森林模型(causal_forest)
library(patchwork)    # 用于组合多个ggplot图形
library(hstats)       # 用于计算Friedman's H统计量和部分依赖图(PDP)
library(kernelshap)   # 用于计算通用SHAP值
library(shapviz)      # 用于绘制SHAP可视化图

# 教程地址：https://www.r-bloggers.com/2024/09/explaining-a-causal-forest/
https://www.r-bloggers.com/2024/09/explaining-a-causal-forest/
# 查看indo_rct数据集的前6行数据
head(indo_rct)

#####################################################################
# indo_rct数据集说明:
# 这是一个关于印度美辛预防ERCP术后胰腺炎的随机对照试验数据集
#
# 数据集背景:
# - ERCP(内镜逆行胰胆管造影)是一种通过内镜进入十二指肠检查胆管和胰管的手术
# - ERCP术后胰腺炎是一种常见且严重的并发症,发生率约16%
# - 本研究旨在验证直肠给药印度美辛(100mg)是否能预防ERCP术后胰腺炎
#
# 数据集基本信息:
# - 样本量: 602名患者
# - 分组: 随机分为印度美辛组和安慰剂组
# - 主要结局: ERCP术后胰腺炎的发生情况
#
# 重要变量说明:
# 1. 基线特征:
#    - id: 受试者ID(1001-4003)
#    - site: 研究中心(1-4个中心)
#    - age: 年龄(19-90岁)
#    - gender: 性别(女/男)
#    - risk: 风险评分(1-5.5)
#
# 2. 风险因素:
#    - sod: 奥迪括约肌功能障碍
#    - pep: 既往ERCP术后胰腺炎史
#    - recpanc: 复发性胰腺炎
#    - difcan: 插管困难
#    - paninj: 胰管造影
#
# 3. 手术相关:
#    - psphinc: 胰管括约肌切开
#    - precut: 预切开
#    - pdstent: 胰管支架置入
#    - bsphinc: 胆管括约肌切开
#    - train: 是否有实习医生参与
#
# 4. 治疗和结局:
#    - rx: 治疗分组(0=安慰剂, 1=印度美辛)
#    - outcome: 是否发生术后胰腺炎
#    - bleed: 是否发生消化道出血
#
# 研究结果:
# - 安慰剂组术后胰腺炎发生率为16%
# - 印度美辛组术后胰腺炎发生率降至9%
# - 研究在入组602名患者后因印度美辛显著的预防效果而提前终止
#####################################################################


# 构建处理变量W
# 将原始rx变量转换为0-1编码:
# - 0表示对照组(安慰剂)
# - 1表示实验组(治疗)
W <- as.integer(indo_rct$rx) - 1L 

# 查看处理变量W的分布情况
table(W)



# 构建结局变量Y
# 将原始outcome变量转换为0-1编码:
# - 0表示未发生ERCP术后胰腺炎
# - 1表示发生ERCP术后胰腺炎(不良结果)
Y <- as.numeric(indo_rct$outcome) - 1

# 计算整体ERCP术后胰腺炎的发生率
# mean(Y)返回所有患者中发生胰腺炎的比例
mean(Y)

# 计算治疗组和对照组的ERCP术后胰腺炎发生率之差
# mean(Y[W == 1])计算治疗组(印度美辛组)的胰腺炎发生率
# mean(Y[W == 0])计算对照组(安慰剂组)的胰腺炎发生率
# 两者相减得到治疗效应(治疗组发生率减去对照组发生率)
mean(Y[W == 1]) - mean(Y[W == 0]) 





# 定义用于构建特征矩阵的变量名向量
# 包含10个临床相关变量作为预测因子
xvars <- c(
  "age",         # 年龄（单位：岁）
  "male",        # 男性（1表示是）
  "pep",         # 既往有ERCP后胰腺炎（1表示是）
  "recpanc",     # 有复发性胰腺炎病史（1表示是）
  "type",        # Oddi括约肌功能障碍类型/程度（0表示无，最高3表示3型）
  "difcan",      # 乳头插管困难（1表示是）
  "psphinc",     # 行胰管括约肌切开术（1表示是）
  "bsphinc",     # 行胆管括约肌切开术（1表示是）
  "pdstent",     # 放置胰管支架（1表示是）
  "train"        # 有实习生参与支架置入（1表示是）
)

# 构建特征矩阵X
# 1. 使用管道操作符|>连接数据处理步骤
# 2. mutate_if()将所有factor类型变量转换为0-1编码的整数
# 3. rename()将gender变量重命名为male
# 4. select_at()选择xvars中指定的变量列
X <- indo_rct |>
  mutate_if(is.factor, function(v) as.integer(v) - 1L) |> 
  rename(male = gender) |> 
  select_at(xvars)

# 显示特征矩阵X的前几行数据,用于检查数据处理结果
head(X)



# 使用causal_forest()函数构建因果森林模型
# 该模型用于估计个体治疗效应(ITE)和异质性治疗效应(HTE)
fit <- causal_forest(
  X = X,                    # 特征矩阵,包含10个临床预测变量
  Y = Y,                    # 结局变量,0-1编码的ERCP术后胰腺炎发生情况
  W = W,                    # 处理变量,0表示对照组(安慰剂),1表示治疗组(印度美辛)
  num.trees = 1000,         # 森林中的决策树数量,增加可提高模型稳定性
  mtry = 4,                 # 每次分裂时随机选择的变量数,这里设为特征总数的平方根
  sample.fraction = 0.7,    # 每棵树使用的训练样本比例,0.7表示使用70%的数据
  seed = 1,                 # 随机数种子,确保结果可重复
  ci.group.size = 1,        # 用于计算置信区间的组大小,1表示逐个样本计算
)


# 计算变量重要性
# 1. 使用setNames()将变量重要性值与变量名配对
# 2. sort()对变量重要性值进行排序
# 3. 使用par()设置图形参数,mai参数设置图形边距
# 4. barplot()绘制变量重要性条形图,horiz = TRUE表示水平条形图,las = 1表示标签水平
# 5. col = "orange"设置条形图颜色为橙色
imp <- sort(setNames(variable_importance(fit), xvars))
par(mai = c(0.7, 2, 0.2, 0.2))
barplot(imp, horiz = TRUE, las = 1, col = "orange")



# 定义预测函数
# 1. 使用function()定义一个匿名函数
# 2. 参数object表示模型对象,newdata表示新数据,…表示可变参数
# 3. 使用predict()函数对新数据进行预测,并返回预测结果
pred_fun <- function(object, newdata, ...) {
  predict(object, newdata, ...)$predictions
}


# 使用lapply()对每个变量计算偏依赖图
# 1. lapply()遍历xvars中的每个变量
# 2. partial_dep()计算每个变量的偏依赖关系
# 3. plot()将偏依赖关系可视化
pdps <- lapply(xvars, function(v) plot(partial_dep(fit, v, X = X, pred_fun = pred_fun)))

# 将所有偏依赖图组合在一起显示
# 1. wrap_plots()将多个图形组合成一个面板
# 2. guides = "collect"合并所有图例
# 3. ncol = 3设置每行显示3个图形
# 4. ylim()设置y轴范围
# 5. ylab()设置y轴标签
wrap_plots(pdps, guides = "collect", ncol = 3) &
  ylim(c(-0.11, -0.06)) &
  ylab("治疗效果")



# 使用predict()函数对数据进行预测
# 返回的res对象包含每个个体的预测治疗效应
res <- predict(fit, X)

# 查看前6个病人的预测结果
# 预测值含义:
# - 负值表示印度美辛治疗降低了ERCP术后胰腺炎的风险
# - 数值大小表示风险降低的百分点
# 例如: -0.10表示该病人使用印度美辛后,胰腺炎风险降低了10个百分点
res$predictions %>% head()


# 说明partial_dep()函数用法
#
# partial_dep()函数用于计算和可视化偏依赖关系(Partial Dependence Plot, PDP)
# 主要用途：展示某个特征变量如何影响模型的预测结果
#
# 函数参数说明：
# 1. fit: 模型对象，这里是我们训练好的因果森林模型
# 2. v: 要分析的变量名，如"age"、"risk"等
# 3. X: 特征矩阵，包含所有预测变量
# 4. pred_fun: 预测函数，定义如何使用模型进行预测
# 5. BY: 分组变量（可选），用于分析交互效应
#
# 使用示例1：计算单个变量的偏依赖关系
pdp_age <- partial_dep(
  fit,                    # 因果森林模型
  v = "age",             # 分析年龄变量
  X = X,                 # 特征矩阵
  pred_fun = pred_fun    # 预测函数
)

plot(pdp_age)


# 使用示例2：计算带交互效应的偏依赖关系
pdp_age_bsphinc <- partial_dep(
  fit,                    # 因果森林模型
  v = "age",             # 主要分析变量：年龄
  BY = "bsphinc",        # 交互变量：括约肌切开
  X = X,                 # 特征矩阵
  pred_fun = pred_fun    # 预测函数
)

plot(pdp_age_bsphinc)




# 计算并可视化异质性统计量
# 1. hstats()计算治疗效应异质性统计量
# 2. verbose = FALSE不显示计算过程
# 3. plot()绘制异质性统计量图形
H <- hstats(fit, X = X, pred_fun = pred_fun, verbose = FALSE)
plot(H)

# 计算并绘制年龄与括约肌切开的交互作用
# 1. partial_dep()计算年龄的偏依赖关系,按括约肌切开分组
# 2. v = "age"指定主要变量为年龄
# 3. BY = "bsphinc"按括约肌切开分组
# 4. plot()绘制交互作用图
partial_dep(fit, v = "age", X = X, BY = "bsphinc", pred_fun = pred_fun) |> 
  plot()


# 使用KernelSHAP解释单个样本的条件平均处理效应(CATE)
# 1. kernelshap()计算第一个样本的SHAP值
# 2. X[1, ]选择第一个样本的特征
# 3. bg_X = X使用全部数据作为背景分布
# 4. shapviz()将SHAP值转换为可视化对象
# 5. sv_waterfall()绘制瀑布图,展示各特征对预测的贡献
kernelshap(fit, X = X[1, ], bg_X = X, pred_fun = pred_fun) |> 
  shapviz() |> 
  sv_waterfall() +
  xlab("预测值") # 设置x轴标签为"预测值"


# 计算并解释所有样本的CATE
# system.time()记录计算时间(约13分钟)
system.time(
  # kernelshap()计算所有样本的SHAP值
  ks <- kernelshap(fit, X = X, pred_fun = pred_fun)  
)

# 将SHAP值转换为可视化对象
shap_values <- shapviz(ks)

# 绘制特征重要性条形图
# sv_importance()展示各特征对模型预测的整体影响程度
sv_importance(shap_values)

# 绘制蜂群图展示特征重要性
# kind = "bee"参数指定绘制蜂群图,展示SHAP值的分布
sv_importance(shap_values, kind = "bee")

# 绘制SHAP依赖图
# 1. sv_dependence()展示特征值与SHAP值的关系
# 2. plot_layout(ncol = 3)将图形排列为3列
# 3. ylim()设置y轴范围为-0.04到0.03
sv_dependence(shap_values, v = xvars) +
  plot_layout(ncol = 3) &
  ylim(c(-0.04, 0.03))
