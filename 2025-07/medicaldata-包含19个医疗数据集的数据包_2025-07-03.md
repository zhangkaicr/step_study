
![教程首页](https://files.mdnice.com/user/36552/f4affc63-a892-4d05-b718-42288d839a75.png)

教程地址：https://higgi13425.github.io/medicaldata/


## 概述

这是一个包含19个医疗数据集的数据包，用于借助R语言教授可重复的医学研究相关知识。这个数据包对于任何向医疗专业人员（包括医生、护士、药剂师、实习生和学生）教授R语言的人来说都非常有用。

这些数据集涵盖范围广泛，既有詹姆斯·林德1757年的坏血病数据集的重构版本、1948年原始的链霉素治疗肺结核试验数据，也有2012年吲哚美辛预防ERCP术后胰腺炎的随机对照试验数据，还有关于SARS-CoV2检测结果的队列数据等。许多数据集来自美国统计协会的TSHS（健康科学统计学教学）资源门户，该门户由马萨诸塞大学的卡罗尔·比奇洛维护（已获得许可）。开发版本中越来越多的数据集是由弗兰克·哈雷尔从其网站慷慨捐赠的，这些数据集目前仅存在于GitHub上的开发版本包中，预计将于2023年6月纳入CRAN。

## 如何安装和使用{medicaldata}数据集

1. 使用`install.packages("medicaldata")`安装稳定的、当前的CRAN版本。如果想尝试开发中的版本（可能包含新的数据集和 vignettes，但也可能偶尔出现问题），可以使用以下命令安装：`remotes::install_github("higgi13425/medicaldata")`

2. 然后使用`library(medicaldata)`加载该包。

3. 之后，可以使用`data(package = "medicaldata")`列出可用的数据集。

4. 再通过以下方式将特定的数据集分配给环境中一个已命名的对象：
`covid <- medicaldata::covid_testing`
其中`covid`是新对象的名称，`covid_testing`是数据集的名称。

5. 关于如何使用这些数据集的文章（vignettes），可以在pkgdown网站的“文章”选项卡下找到。

6. 你可以点击下面的链接查看每个数据集的描述文档和/或代码手册。这些信息也可以在上面的“参考”选项卡下找到，或者在R中使用`help(dataset_name)`获取。

## 请捐赠数据集
如果你能获取随机对照临床试验、前瞻性队列研究甚至病例对照研究的数据，请考虑获得适当的许可、对数据进行匿名化处理，并为教学目的捐赠该数据集以添加到这个包中。在GitHub页面（右上角的源代码链接）上提出一个问题，来开启关于数据捐赠的讨论。我很乐意协助进行匿名化处理。

## 数据集列表
点击下面的链接，可在描述文档中了解数据集本身的更多详细信息，在代码手册中了解数据集中包含的变量的更多详细信息。请注意，每个数据集都有一个帮助文件，你可以在R或RStudio中使用，在控制台面板中输入`help("dataset_name")`即可。如下表的第四列（向右滚动或加宽浏览器窗口）描述了研究设计，这是应{gtsummary}的知名人士丹·舍贝里的要求而设置的。

| 数据集 | 描述文档 | 代码手册 | 设计 |
| ---- | ---- | ---- | ---- |
| strep_tb | strep_tb_desc | strep_tb_codebook | 随机对照试验（RCT） |
| scurvy | scurvy_desc | scurvy_codebook | 随机对照试验（RCT） |
| indo_rct | indo_rct_desc | indo_rct_codebook | 随机对照试验（RCT） |
| polyps | polyps_desc | polyps_codebook | 随机对照试验（RCT） |
| cervical dystonia (dev) | cdystonia_desc | cdystonia_codebook | 随机对照试验（RCT） |
| covid_testing | covid_desc | covid_codebook | 回顾性横断面研究 |
| blood_storage | blood_storage_desc | blood_storage_codebook | 回顾性队列研究 |
| cytomegalovirus | cytomegalovirus_desc | cytomegalovirus_codebook | 回顾性队列研究 |
| esoph_ca | esoph_ca_desc | esoph_ca_codebook | 病例对照研究 |
| laryngoscope | laryngoscope_desc | laryngoscope_codebook | 随机对照试验（RCT） |
| licorice_gargle | licorice_gargle_desc | licorice_gargle_codebook | 随机对照试验（RCT） |
| opt | opt_desc | opt_codebook | 随机对照试验（RCT） |
| cath (dev) | cath_desc | cath_codebook | 回顾性队列研究 |
| smartpill | smartpill_desc | smartpill_codebook | 前瞻性队列研究 |
| supraclavicular | supraclavicular_desc | supraclavicular_codebook | 随机对照试验（RCT） |
| indometh | indometh_desc | indometh_codebook | 前瞻性队列药代动力学（PK）研究 |
| theoph | theoph_desc | theoph_codebook | 前瞻性队列药代动力学（PK）研究 |
| diabetes (dev) | diabetes_desc | diabetes_codebook | 前瞻性纵向队列研究 |
| thiomon (dev) | thiomon_desc | thiomon_codebook | 回顾性队列研究，适用于机器学习 |
| abm (dev) | abm_desc | abm_codebook | 回顾性队列研究 |

## 杂乱的数据集
我正在对杂乱的数据集进行beta测试，这些数据集主要是Excel格式的，具有许多令人烦恼的非整洁和非矩形特征，这将有助于教授数据清理/整理知识。这些数据集实际上并不在包本身中（因为它们不是R文件），但可以在GitHub仓库中找到。

你可以通过点击下表中的URL链接，从GitHub仓库下载并打开这些杂乱的Excel格式的数据集。你也可以在GitHub仓库的列表中找到它们，在那里你可以点击其中一个*.xlsx文件，然后点击“View Raw”按钮进行下载。

你可以使用下面代码块中的示例代码，直接从下表中的url将这些数据集读入R中，该代码读入`messy_infarct`数据集并将其分配给对象`infarct`。最简单的方法是将鼠标悬停在右上角的复制图标上，然后点击复制整个代码块。
```
# install.packages('openxlsx')
# 如果尚未安装
library(openxlsx)
url <- "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_infarct.xlsx"
# 将这个长url路径末尾的文件名“messy_infarct.xlsx”替换为你想要加载的文件名。
# 或者直接从下面的URL列复制整个路径。
infarct <- openxlsx::read.xlsx(url)
head(infarct)
```

## 可用的杂乱数据集（beta版）

| 数据集 | 统一资源定位符（URL） | 杂乱类型 |
| ---- | ---- | ---- |
| messy_cirrhosis | "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_cirrhosis.xlsx" | 数据透视表 |
| messy_infarct | "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_infarct.xlsx" | 数据透视表 |
| messy_aki | "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_aki.xlsx" | 唯一标识符、页眉和页脚行、空行和空列、杂乱的变量名、无单位、因子中的拼写错误、标题中的就诊日期、日期 |
| messy_bp | "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_bp.xlsx" | 合并和分离、无单位的变量、标题中的就诊编号、数据输入错误 |
| messy_glucose | "https://github.com/higgi13425/medicaldata/raw/master/data-raw/messy_data/messy_glucose.xlsx" | 因子、无单位的变量、标题中的就诊编号、页眉行、空行/列 |