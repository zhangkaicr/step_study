# ============================================================================
# here包文件路径管理演示脚本
# 作者：SOLO Coding
# 功能：演示如何使用here包进行跨平台文件路径管理
# 创建日期：2024
# ============================================================================

# 清理工作环境
# 移除所有已存在的对象，确保脚本在干净的环境中运行
rm(list = ls())

# 设置控制台输出编码为UTF-8，确保中文字符正确显示
options(encoding = "UTF-8")

# ============================================================================
# 第一部分：包的安装和加载
# ============================================================================

# 检查并安装here包
# here包用于构建与操作系统无关的文件路径
if (!require(here, quietly = TRUE)) {
  # 如果here包未安装，则自动安装
  install.packages("here", dependencies = TRUE)
  # 加载here包
  library(here)
  cat("here包已成功安装并加载\n")
} else {
  # 如果here包已安装，直接加载
  library(here)
  cat("here包已加载\n")
}

# 检查并安装tidyverse包
# tidyverse包含现代R数据处理的核心包集合
if (!require(tidyverse, quietly = TRUE)) {
  # 如果tidyverse包未安装，则自动安装
  install.packages("tidyverse", dependencies = TRUE)
  # 加载tidyverse包
  library(tidyverse)
  cat("tidyverse包已成功安装并加载\n")
} else {
  # 如果tidyverse包已安装，直接加载
  library(tidyverse)
  cat("tidyverse包已加载\n")
}

# 检查并安装readxl包
# readxl包用于读取Excel文件
if (!require(readxl, quietly = TRUE)) {
  # 如果readxl包未安装，则自动安装
  install.packages("readxl", dependencies = TRUE)
  # 加载readxl包
  library(readxl)
  cat("readxl包已成功安装并加载\n")
} else {
  # 如果readxl包已安装，直接加载
  library(readxl)
  cat("readxl包已加载\n")
}

# 检查并安装zoo包
# zoo包用于时间序列数据处理，特别是移动平均计算
if (!require(zoo, quietly = TRUE)) {
  # 如果zoo包未安装，则自动安装
  install.packages("zoo", dependencies = TRUE)
  # 加载zoo包
  library(zoo)
  cat("zoo包已成功安装并加载\n")
} else {
  # 如果zoo包已安装，直接加载
  library(zoo)
  cat("zoo包已加载\n")
}

# ============================================================================
# 第二部分：here包基础功能演示
# ============================================================================

# 显示项目根目录
# here()函数会自动识别项目根目录（通常包含.Rproj文件的目录）
project_root <- here()
cat("项目根目录：", project_root, "\n")

# 显示当前工作目录
current_wd <- getwd()
cat("当前工作目录：", current_wd, "\n")

# 比较here()和getwd()的区别
if (project_root == current_wd) {
  cat("项目根目录与当前工作目录相同\n")
} else {
  cat("项目根目录与当前工作目录不同\n")
  cat("这展示了here包的优势：无论当前工作目录在哪里，here()总是指向项目根目录\n")
}

# ============================================================================
# 第三部分：创建项目文件夹结构
# ============================================================================

# 使用here包创建input文件夹的绝对路径
input_dir <- here("input")
cat("input文件夹路径：", input_dir, "\n")

# 使用here包创建output文件夹的绝对路径
output_dir <- here("output")
cat("output文件夹路径：", output_dir, "\n")

# 创建input文件夹（如果不存在）
if (!dir.exists(input_dir)) {
  # 创建input目录
  dir.create(input_dir, recursive = TRUE)
  cat("已创建input文件夹：", input_dir, "\n")
} else {
  cat("input文件夹已存在：", input_dir, "\n")
}

# 创建output文件夹（如果不存在）
if (!dir.exists(output_dir)) {
  # 创建output目录
  dir.create(output_dir, recursive = TRUE)
  cat("已创建output文件夹：", output_dir, "\n")
} else {
  cat("output文件夹已存在：", output_dir, "\n")
}

# 创建子文件夹示例
# 在input文件夹下创建raw_data子文件夹
raw_data_dir <- here("input", "raw_data")
if (!dir.exists(raw_data_dir)) {
  dir.create(raw_data_dir, recursive = TRUE)
  cat("已创建raw_data子文件夹：", raw_data_dir, "\n")
}

# 在output文件夹下创建processed_data子文件夹
processed_data_dir <- here("output", "processed_data")
if (!dir.exists(processed_data_dir)) {
  dir.create(processed_data_dir, recursive = TRUE)
  cat("已创建processed_data子文件夹：", processed_data_dir, "\n")
}

# 在output文件夹下创建plots子文件夹
plots_dir <- here("output", "plots")
if (!dir.exists(plots_dir)) {
  dir.create(plots_dir, recursive = TRUE)
  cat("已创建plots子文件夹：", plots_dir, "\n")
}

# ============================================================================
# 第四部分：创建示例数据文件
# ============================================================================

# 创建示例数据集1：学生成绩数据
student_data <- tibble(
  # 学生ID
  student_id = 1:50,
  # 学生姓名
  name = paste0("学生", sprintf("%02d", 1:50)),
  # 年龄（18-25岁随机分布）
  age = sample(18:25, 50, replace = TRUE),
  # 性别
  gender = sample(c("男", "女"), 50, replace = TRUE),
  # 数学成绩（60-100分随机分布）
  math_score = round(runif(50, 60, 100), 1),
  # 英语成绩（60-100分随机分布）
  english_score = round(runif(50, 60, 100), 1),
  # 科学成绩（60-100分随机分布）
  science_score = round(runif(50, 60, 100), 1)
)

# 使用here包构建文件路径并保存CSV文件
student_csv_path <- here("input", "student_scores.csv")
write_csv(student_data, student_csv_path)
cat("已创建示例数据文件：", student_csv_path, "\n")

# 创建示例数据集2：销售数据
sales_data <- tibble(
  # 日期（最近30天）
  date = seq(from = Sys.Date() - 29, to = Sys.Date(), by = "day"),
  # 产品类别
  product_category = sample(c("电子产品", "服装", "食品", "图书"), 30, replace = TRUE),
  # 销售额（1000-10000元随机分布）
  sales_amount = round(runif(30, 1000, 10000), 2),
  # 销售数量（1-100件随机分布）
  quantity = sample(1:100, 30, replace = TRUE),
  # 销售员
  salesperson = sample(c("张三", "李四", "王五", "赵六"), 30, replace = TRUE)
)

# 使用here包构建文件路径并保存Excel文件
sales_excel_path <- here("input", "raw_data", "sales_data.xlsx")
# 注意：这里使用writexl包来写入Excel文件
if (!require(writexl, quietly = TRUE)) {
  install.packages("writexl", dependencies = TRUE)
  library(writexl)
}
write_xlsx(sales_data, sales_excel_path)
cat("已创建示例Excel文件：", sales_excel_path, "\n")

# ============================================================================
# 第五部分：演示从input文件夹读取数据
# ============================================================================

cat("\n=== 开始演示数据读取 ===\n")

# 方法1：读取CSV文件
# 使用here包构建绝对路径，确保在任何工作目录下都能正确读取
student_data_read <- read_csv(here("input", "student_scores.csv"), 
                              locale = locale(encoding = "UTF-8"),
                              show_col_types = FALSE)

cat("成功读取学生成绩数据，共", nrow(student_data_read), "行", ncol(student_data_read), "列\n")

# 显示数据前几行
cat("学生成绩数据预览：\n")
print(head(student_data_read))

# 方法2：读取Excel文件
# 使用here包构建绝对路径读取Excel文件
sales_data_read <- read_excel(here("input", "raw_data", "sales_data.xlsx"))

cat("\n成功读取销售数据，共", nrow(sales_data_read), "行", ncol(sales_data_read), "列\n")

# 显示数据前几行
cat("销售数据预览：\n")
print(head(sales_data_read))

# 方法3：列出input文件夹中的所有文件
# 使用here包构建路径来列出文件
input_files <- list.files(here("input"), recursive = TRUE, full.names = TRUE)
cat("\ninput文件夹中的所有文件：\n")
for (file in input_files) {
  cat("  -", file, "\n")
}

# ============================================================================
# 第六部分：数据处理和分析
# ============================================================================

cat("\n=== 开始数据处理和分析 ===\n")

# 处理学生成绩数据
# 使用tidyverse的现代语法流进行数据处理
student_summary <- student_data_read %>%
  # 计算总分
  mutate(total_score = math_score + english_score + science_score) %>%
  # 计算平均分
  mutate(average_score = total_score / 3) %>%
  # 根据平均分评定等级
  mutate(grade = case_when(
    average_score >= 90 ~ "优秀",
    average_score >= 80 ~ "良好", 
    average_score >= 70 ~ "中等",
    average_score >= 60 ~ "及格",
    TRUE ~ "不及格"
  )) %>%
  # 按性别分组统计
  group_by(gender) %>%
  # 计算各项统计指标
  summarise(
    学生人数 = n(),
    平均总分 = round(mean(total_score), 2),
    最高总分 = max(total_score),
    最低总分 = min(total_score),
    标准差 = round(sd(total_score), 2),
    .groups = "drop"
  )

cat("学生成绩按性别统计结果：\n")
print(student_summary)

# 处理销售数据
# 使用tidyverse的现代语法流进行数据处理
sales_summary <- sales_data_read %>%
  # 按产品类别分组
  group_by(product_category) %>%
  # 计算各项统计指标
  summarise(
    销售天数 = n(),
    总销售额 = round(sum(sales_amount), 2),
    平均销售额 = round(mean(sales_amount), 2),
    总销售数量 = sum(quantity),
    平均销售数量 = round(mean(quantity), 2),
    .groups = "drop"
  ) %>%
  # 按总销售额降序排列
  arrange(desc(总销售额))

cat("\n销售数据按产品类别统计结果：\n")
print(sales_summary)

# 创建时间序列分析
daily_sales <- sales_data_read %>%
  # 按日期分组
  group_by(date) %>%
  # 计算每日总销售额
  summarise(
    daily_total = sum(sales_amount),
    daily_quantity = sum(quantity),
    .groups = "drop"
  ) %>%
  # 计算移动平均（7天）
  mutate(
    moving_avg_7d = zoo::rollmean(daily_total, k = 7, fill = NA, align = "right")
  )

cat("\n每日销售趋势数据已生成\n")

# ============================================================================
# 第七部分：将处理后的数据写入output文件夹
# ============================================================================

cat("\n=== 开始保存处理后的数据 ===\n")

# 保存学生成绩统计结果
# 使用here包构建输出文件的绝对路径
student_summary_path <- here("output", "processed_data", "student_summary_by_gender.csv")
write_csv(student_summary, student_summary_path)
cat("学生成绩统计结果已保存至：", student_summary_path, "\n")

# 保存销售数据统计结果
sales_summary_path <- here("output", "processed_data", "sales_summary_by_category.csv")
write_csv(sales_summary, sales_summary_path)
cat("销售统计结果已保存至：", sales_summary_path, "\n")

# 保存每日销售趋势数据
daily_sales_path <- here("output", "processed_data", "daily_sales_trend.csv")
write_csv(daily_sales, daily_sales_path)
cat("每日销售趋势数据已保存至：", daily_sales_path, "\n")

# 保存详细的学生成绩数据（包含计算字段）
detailed_student_path <- here("output", "processed_data", "detailed_student_scores.xlsx")
detailed_student_data <- student_data_read %>%
  mutate(total_score = math_score + english_score + science_score) %>%
  mutate(average_score = round(total_score / 3, 2)) %>%
  mutate(grade = case_when(
    average_score >= 90 ~ "优秀",
    average_score >= 80 ~ "良好", 
    average_score >= 70 ~ "中等",
    average_score >= 60 ~ "及格",
    TRUE ~ "不及格"
  ))

write_xlsx(detailed_student_data, detailed_student_path)
cat("详细学生成绩数据已保存至：", detailed_student_path, "\n")

# ============================================================================
# 第八部分：创建数据可视化图表
# ============================================================================

cat("\n=== 开始创建数据可视化图表 ===\n")

# 创建学生成绩分布图
p1 <- detailed_student_data %>%
  # 将数据转换为长格式以便绘图
  pivot_longer(cols = c(math_score, english_score, science_score),
               names_to = "subject", 
               values_to = "score") %>%
  # 重新编码科目名称
  mutate(subject = case_when(
    subject == "math_score" ~ "数学",
    subject == "english_score" ~ "英语", 
    subject == "science_score" ~ "科学"
  )) %>%
  # 创建箱线图
  ggplot(aes(x = subject, y = score, fill = subject)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, alpha = 0.5) +
  labs(
    title = "各科目成绩分布图",
    subtitle = "显示成绩的分布情况和异常值",
    x = "科目",
    y = "成绩",
    fill = "科目"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 12),
    legend.position = "none"
  ) +
  scale_fill_brewer(palette = "Set2")

# 保存图表1
plot1_path <- here("output", "plots", "subject_scores_distribution.png")
ggsave(plot1_path, p1, width = 10, height = 6, dpi = 300)
cat("学科成绩分布图已保存至：", plot1_path, "\n")

# 创建销售趋势图
p2 <- daily_sales %>%
  # 确保date列是Date类型
  mutate(date = as.Date(date)) %>%
  ggplot(aes(x = date)) +
  # 绘制每日销售额柱状图
  geom_col(aes(y = daily_total), alpha = 0.6, fill = "steelblue") +
  # 绘制7天移动平均线（使用linewidth替代size）
  geom_line(aes(y = moving_avg_7d), color = "red", linewidth = 1.2, na.rm = TRUE) +
  labs(
    title = "每日销售额趋势图",
    subtitle = "蓝色柱状图为每日销售额，红色线为7天移动平均",
    x = "日期",
    y = "销售额（元）"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 12),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  scale_y_continuous(labels = scales::comma_format()) +
  scale_x_date(date_labels = "%m-%d", date_breaks = "3 days")

# 保存图表2
plot2_path <- here("output", "plots", "daily_sales_trend.png")
ggsave(plot2_path, p2, width = 12, height = 6, dpi = 300)
cat("每日销售趋势图已保存至：", plot2_path, "\n")

# 创建产品类别销售额饼图
p3 <- sales_summary %>%
  ggplot(aes(x = "", y = 总销售额, fill = product_category)) +
  geom_col(width = 1) +
  coord_polar("y", start = 0) +
  labs(
    title = "各产品类别销售额占比",
    fill = "产品类别"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "right"
  ) +
  scale_fill_brewer(palette = "Set3") +
  # 添加百分比标签
  geom_text(aes(label = paste0(round(总销售额/sum(总销售额)*100, 1), "%")),
            position = position_stack(vjust = 0.5))

# 保存图表3
plot3_path <- here("output", "plots", "product_category_pie_chart.png")
ggsave(plot3_path, p3, width = 10, height = 8, dpi = 300)
cat("产品类别销售占比饼图已保存至：", plot3_path, "\n")

# ============================================================================
# 第九部分：生成项目报告
# ============================================================================

cat("\n=== 生成项目报告 ===\n")

# 创建项目报告内容
report_content <- paste0(
  "# here包文件路径管理演示报告\n\n",
  "## 项目概述\n",
  "本项目演示了如何使用here包进行跨平台文件路径管理。\n\n",
  "## 项目结构\n",
  "- 项目根目录：", project_root, "\n",
  "- 输入数据目录：", input_dir, "\n", 
  "- 输出数据目录：", output_dir, "\n\n",
  "## 数据文件\n",
  "### 输入文件\n",
  "- 学生成绩数据：student_scores.csv\n",
  "- 销售数据：raw_data/sales_data.xlsx\n\n",
  "### 输出文件\n",
  "- 学生成绩统计：processed_data/student_summary_by_gender.csv\n",
  "- 销售统计：processed_data/sales_summary_by_category.csv\n",
  "- 每日销售趋势：processed_data/daily_sales_trend.csv\n",
  "- 详细学生数据：processed_data/detailed_student_scores.xlsx\n\n",
  "## 可视化图表\n",
  "- 学科成绩分布图：plots/subject_scores_distribution.png\n",
  "- 每日销售趋势图：plots/daily_sales_trend.png\n",
  "- 产品类别占比图：plots/product_category_pie_chart.png\n\n",
  "## here包的优势\n",
  "1. 跨平台兼容性：自动处理不同操作系统的路径分隔符\n",
  "2. 项目根目录定位：自动识别项目根目录，无需手动设置\n",
  "3. 相对路径构建：基于项目根目录构建相对路径\n",
  "4. 代码可移植性：确保代码在不同环境下都能正确运行\n\n",
  "## 生成时间\n",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n"
)

# 保存项目报告
report_path <- here("output", "project_report.md")
writeLines(report_content, report_path, useBytes = TRUE)
cat("项目报告已保存至：", report_path, "\n")

# ============================================================================
# 第十部分：路径管理最佳实践演示
# ============================================================================

cat("\n=== here包最佳实践演示 ===\n")

# 演示1：动态路径构建
create_timestamped_file <- function(base_name, extension = "csv") {
  # 创建带时间戳的文件名
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- paste0(base_name, "_", timestamp, ".", extension)
  
  # 使用here包构建完整路径
  full_path <- here("output", "processed_data", filename)
  
  return(full_path)
}

# 创建带时间戳的备份文件
backup_path <- create_timestamped_file("data_backup")
write_csv(detailed_student_data, backup_path)
cat("备份文件已创建：", backup_path, "\n")

# 演示2：条件路径创建
create_conditional_path <- function(data_type, create_dir = TRUE) {
  # 根据数据类型创建不同的子目录
  subdir <- switch(data_type,
                   "raw" = "raw_data",
                   "processed" = "processed_data", 
                   "temp" = "temp_data",
                   "archive" = "archive_data",
                   "processed_data")  # 默认值
  
  # 使用here包构建路径
  dir_path <- here("output", subdir)
  
  # 如果需要，创建目录
  if (create_dir && !dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
    cat("已创建目录：", dir_path, "\n")
  }
  
  return(dir_path)
}

# 创建临时数据目录
temp_dir <- create_conditional_path("temp")
archive_dir <- create_conditional_path("archive")

# 演示3：文件存在性检查
check_file_exists <- function(relative_path) {
  # 使用here包构建绝对路径
  full_path <- here(relative_path)
  
  # 检查文件是否存在
  if (file.exists(full_path)) {
    cat("文件存在：", full_path, "\n")
    # 获取文件信息
    file_info <- file.info(full_path)
    cat("  文件大小：", round(file_info$size / 1024, 2), "KB\n")
    cat("  修改时间：", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"), "\n")
  } else {
    cat("文件不存在：", full_path, "\n")
  }
  
  return(file.exists(full_path))
}

# 检查关键文件
cat("\n文件存在性检查：\n")
check_file_exists("input/student_scores.csv")
check_file_exists("output/processed_data/student_summary_by_gender.csv")
check_file_exists("output/plots/subject_scores_distribution.png")

# ============================================================================
# 第十一部分：清理和总结
# ============================================================================

cat("\n=== 脚本执行总结 ===\n")

# 统计创建的文件数量
output_files <- list.files(here("output"), recursive = TRUE, full.names = TRUE)
input_files <- list.files(here("input"), recursive = TRUE, full.names = TRUE)

cat("项目文件统计：\n")
cat("  输入文件数量：", length(input_files), "\n")
cat("  输出文件数量：", length(output_files), "\n")
cat("  总文件数量：", length(input_files) + length(output_files), "\n")

# 显示项目目录结构
cat("\n项目目录结构：\n")
cat("项目根目录：", here(), "\n")
cat("├── input/\n")
for (file in input_files) {
  relative_path <- gsub(paste0(here(), "/"), "", file)
  cat("│   ├──", relative_path, "\n")
}
cat("└── output/\n")
for (file in output_files) {
  relative_path <- gsub(paste0(here(), "/"), "", file)
  cat("    ├──", relative_path, "\n")
}

# 显示here包的关键函数使用示例
cat("\n=== here包关键函数使用示例 ===\n")
cat("1. here() - 获取项目根目录：\n")
cat("   ", here(), "\n")
cat("2. here('input') - 构建input目录路径：\n")
cat("   ", here("input"), "\n")
cat("3. here('output', 'plots') - 构建嵌套目录路径：\n")
cat("   ", here("output", "plots"), "\n")
cat("4. here('input', 'student_scores.csv') - 构建文件路径：\n")
cat("   ", here("input", "student_scores.csv"), "\n")

# 显示脚本运行时间
end_time <- Sys.time()
cat("\n脚本执行完成时间：", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n")

cat("\n=== here包文件路径管理演示完成 ===\n")
cat("所有文件已成功创建并保存到相应目录中。\n")
cat("请查看output文件夹中的处理结果和可视化图表。\n")