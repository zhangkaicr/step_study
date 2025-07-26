library(precmed)
library(tidyverse)



# 1 计数结果----------------------------------
rm(list = ls())
data("countExample")

output_lm <- lm(y ~ trt, countExample)
output_lm


levels(countExample$trt)

output_atefit <- atefit(response = "count",
                        data = countExample,
                        cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
                        ps.model = trt ~ age + previous_treatment,
                        n.boot = 500, 
                        seed = 999,
                        verbose = 1)

output_atefit


rate.ratio <- exp(output_atefit$log.rate.ratio$estimate)
rate.ratio

CI.rate.ratio <- exp(output_atefit$log.rate.ratio$estimate + c(-1, 1) * qnorm(0.975) * sqrt(output_atefit$log.rate.ratio$SE))
CI.rate.ratio

plot(output_atefit)



t0 <- Sys.time()
output_catefit <- catefit(response = "count",
                          data = countExample,
                          score.method = c("poisson", "boosting", "twoReg", "contrastReg", "negBin"),
                          cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
                          ps.model = trt ~ age + previous_treatment,
                          initial.predictor.method = "poisson",
                          higher.y = FALSE, 
                          seed = 999)


t1 <- Sys.time()
t1 - t0

length(output_catefit$score.contrastReg)

head(output_catefit$score.contrastReg)


output_catefit$coefficients


output_catefit$ate.contrastReg


dataplot <- data.frame(score = factor(rep(c("Boosting", "Naive Poisson", "Two regressions", "Contrast regression", "Negative Binomial"), each = length(output_catefit$score.boosting))),
                       value = c(output_catefit$score.boosting, output_catefit$score.poisson, output_catefit$score.twoReg, output_catefit$score.contrastReg, output_catefit$score.negBin))
dataplot %>% 
  ggplot(aes(x = value, fill = score)) + 
  geom_density(alpha = 0.5) +
  theme_classic() + 
  labs(x = "Estimated CATE score", y = "Density", fill = "Method")


output_catecv <- catecv(response = "count",
                        data = countExample,
                        score.method = c("poisson", "contrastReg", "negBin"),
                        cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
                        ps.model = trt ~ age + previous_treatment, 
                        initial.predictor.method = "poisson",
                        higher.y = FALSE,
                        cv.n = 5, 
                        seed = 999,
                        plot.gbmperf = FALSE,
                        verbose = 1)


output_catecv$ate.contrastReg$ate.est.train.high.cv

output_catecv$ate.contrastReg$ate.est.valid.high.cv

output_catecv$ate.contrastReg$ate.est.train.low.cv



output_catecv$ate.contrastReg$ate.est.train.group.cv

output_catecv$ate.contrastReg$ate.est.valid.group.cv


output_abc <- abc(x = output_catecv)
output_abc


average_abc <- apply(output_abc, 1, mean)
average_abc

plot(x = output_catecv)


plot(x = output_catecv, 
     show.abc = FALSE, 
     ylab = c("Rate ratio of drug1 vs drug0 in each subgroup"))


plot(x = output_catecv, 
     cv.i = 2, 
     grayscale = TRUE, 
     ylab = c("Rate ratio of drug1 vs drug0 in each subgroup"))


boxplot(x = output_catecv,
        ylab = "Rate ratio of drug1 vs drug0 in each subgroup")



# 2.生存结果示例----------------------------------


rm(list = ls())

data(survivalExample)

head(survivalExample)

library(survival)
output_cox <- coxph(Surv(y, d) ~ trt, data = survivalExample)
summary(output_cox)



#define tau0
tau0 <- with(survivalExample,
             min(quantile(y[trt == "drug1"], 0.95), quantile(y[trt == "drug0"], 0.95)))

#run atefit
output_atefit <- atefit(response = "survival",
                        data = survivalExample,
                        cate.model = survival::Surv(y, d) ~ age + female + previous_cost + previous_number_relapses,
                        ps.model = trt ~ age + previous_treatment,
                        tau0 = tau0,verbose = 1)
output_atefit

output_atefit$warning

plot(output_atefit)



tau0 <- with(survivalExample,
             min(quantile(y[trt == "drug1"], 0.95), quantile(y[trt == "drug0"], 0.95)))

output_catefit <- catefit(response = "survival",
                          data = survivalExample,
                          score.method = c( "randomForest", "contrastReg"),
                          cate.model = survival::Surv(y, d) ~ age + female + previous_cost + previous_number_relapses,
                          ps.model = trt ~ age + previous_treatment,
                          initial.predictor.method = "logistic",
                          tau0 = tau0, verbose = 1,
                          higher.y = TRUE,
                          seed = 999,
                          plot.gbmperf = FALSE)

length(output_catefit$score.contrastReg)

head(output_catefit$score.contrastReg)

output_catefit$coefficients

output_catefit$ate.contrastReg

dataplot <- data.frame(score = factor(rep(c("Random Forest", "Contrast regression"),
                                          each = length(output_catefit$score.randomForest))), 
                       value = c(output_catefit$score.randomForest,output_catefit$score.contrastReg))

dataplot %>% 
  ggplot(aes(x = value, fill = score)) + 
  geom_density(alpha = 0.5) +
  theme_classic() + 
  labs(x = "Estimated CATE score", y = "Density", fill = "Method")

tau0 <- with(survivalExample,
             min(quantile(y[trt == "drug1"], 0.95), quantile(y[trt == "drug0"], 0.95)))

output_catecv <- catecv(response = "survival",
                        data = survivalExample,
                        score.method = c("randomForest", "contrastReg"),
                        cate.model = survival::Surv(y, d) ~ age + female +
                          previous_cost + previous_number_relapses,
                        ps.model = trt ~ age + previous_treatment,
                        initial.predictor.method = "logistic",
                        followup.time = NULL,
                        tau0 = tau0,
                        higher.y = TRUE,
                        surv.min = 0.025,
                        prop.cutoff = seq(0.6, 1, length = 5),
                        prop.multi = c(0, 0.5, 0.6, 1),
                        cv.n = 5,
                        seed = 999,
                        plot.gbmperf = FALSE,
                        verbose = 1)


output_catecv$ate.randomForest$ate.est.train.high.cv


output_catecv$ate.randomForest$ate.est.valid.high.cv


output_catecv$hr.randomForest$hr.est.train.high.cv

output_catecv$ate.randomForest$ate.est.train.low.cv


output_catecv$`errors/warnings`$randomForest$est.train.low.cv$cv1

output_catecv$`errors/warnings`$randomForest$est.valid.low.cv$cv1

output_catecv$ate.randomForest$ate.est.train.group.cv

output_catecv$ate.randomForest$ate.est.valid.group.cv

output_abc <- abc(x = output_catecv)
output_abc

average_abc <- apply(output_abc, 1, mean)
average_abc

plot(x = output_catecv)


plot(x = output_catecv, 
     show.abc = FALSE, 
     ylab = c("每个亚组中drug1与drug0的RMTL比率"))

plot(x = output_catecv, 
     cv.i = 2, 
     grayscale = TRUE, 
     ylab = c("每个亚组中drug1与drug0的RMTL比率"))


boxplot(x = output_catecv,
        ylab = "每个亚组中drug1与drug0的RMTL比率")



# 3.附加示例-count情况-----------------------

# 使用GBM作为初始预测方法的示例
catecv(response = "count",
       data = countExample,
       score.method = c("poisson", "boosting", "twoReg", "contrastReg", "negBin"),
       cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
       ps.model = trt ~ age + previous_treatment, 
       higher.y = FALSE,
       initial.predictor.method = "boosting",       # 新增
       cv.n = 5, 
       seed = 999,
       plot.gbmperf = FALSE,
       verbose = 0)


# 使用GBM作为初始预测方法的示例
catecv(response = "count",
       data = countExample,
       score.method = c("poisson", "boosting", "twoReg", "contrastReg", "negBin"),
       cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
       ps.model = trt ~ age + previous_treatment, 
       higher.y = FALSE,
       initial.predictor.method = "boosting",       # 新增
       cv.n = 5, 
       seed = 999,
       plot.gbmperf = FALSE,
       verbose = 0)



output_catecv2 <- catecv(response = "count",
                         data = countExample,
                         score.method = c("poisson", "contrastReg", "negBin"),
                         cate.model = y ~ age + female + previous_treatment + previous_cost + previous_number_relapses + offset(log(years)),
                         ps.model = trt ~ age + previous_treatment,
                         higher.y = FALSE,
                         prop.cutoff = seq(0.5, 1, length = 11), # 新增
                         prop.multi = c(0, 1/4, 2/4, 3/4, 1),    # 新增
                         initial.predictor.method = "poisson", 
                         cv.n = 5, 
                         seed = 999,
                         plot.gbmperf = FALSE,
                         verbose = 1)

print(output_catecv2$ate.contrastReg$ate.est.train.high.cv) 

plot(output_catecv2) 

print(output_catecv2$ate.contrastReg$ate.est.train.group.cv)


boxplot(output_catecv2)


output_catecv3 <- catecv(response = "count",
                         data = countExample,
                         score.method = c("poisson", "contrastReg", "negBin"),
                         cate.model = y ~ age + female + previous_treatment
                         + previous_cost + previous_number_relapses 
                         + offset(log(years)),
                         ps.model = trt ~ age + previous_treatment, 
                         initial.predictor.method = "poisson", 
                         higher.y = FALSE,
                         prop.cutoff = c(0, 0.01, 0.30, 0.75, 1), # 新增
                         cv.n = 5, 
                         seed = 999,
                         plot.gbmperf = FALSE,
                         verbose = 1)

output_catecv3$ate.contrastReg$ate.est.valid.high.cv


plot(output_catecv3) 


# 4.生存结果附加示例---------------------------
# 9个嵌套二元亚组和4类互斥亚组的示例
tau0 <- with(survivalExample,
             min(quantile(y[trt == "drug1"], 0.95), quantile(y[trt == "drug0"], 0.95)))

output_catecv2 <- catecv(response = "survival",
                         data = survivalExample,
                         score.method = c("randomForest", "contrastReg"),
                         
                         cate.model = survival::Surv(y, d) ~ age + female
                         + previous_cost + previous_number_relapses,
                         ps.model = trt ~ age + previous_treatment,
                         initial.predictor.method = "logistic",
                         ipcw.model = NULL,
                         followup.time = NULL,
                         tau0 = tau0,
                         surv.min = 0.025,
                         higher.y = TRUE,
                         prop.cutoff = seq(0.6, 1, length = 9), # 新增
                         prop.multi = c(0, 0.4, 0.5, 0.6, 1),   # 新增
                         cv.n = 5,
                         seed = 999,
                         plot.gbmperf = FALSE,
                         verbose = 0)

print(output_catecv2$ate.contrastReg$ate.est.train.high.cv) 

plot(output_catecv2) 

print(output_catecv2$ate.contrastReg$ate.est.train.group.cv)

boxplot(output_catecv2)



# 很少嵌套二元亚组的示例
output_catecv3 <- catecv(response = "survival",
                         data = survivalExample,
                         score.method = c("contrastReg"),
                         cate.model = survival::Surv(y, d) ~ age + female + previous_cost + previous_number_relapses,
                         ps.model = trt ~ age + previous_treatment,
                         initial.predictor.method = "logistic",
                         ipcw.model = NULL,
                         followup.time = NULL,
                         tau0 = tau0,
                         surv.min = 0.025,
                         higher.y = TRUE,
                         prop.cutoff = c(0, 0.1, 0.75, 1), # 新增
                         prop.multi = c(0, 0.5, 0.6, 1),
                         cv.n = 5,
                         seed = 999,
                         plot.gbmperf = FALSE,
                         verbose = 1)

output_catecv3$ate.contrastReg$ate.est.valid.high.cv


plot(output_catecv3) 



# 与默认值具有不同协变量的IPCW模型示例
output_catecv4 <- catecv(response = "survival",
                         data = survivalExample,
                         score.method = c("poisson", "contrastReg"),
                         cate.model = survival::Surv(y, d) ~ age + female + previous_cost + previous_number_relapses,
                         ps.model = trt ~ age + previous_treatment,
                         initial.predictor.method = "logistic",
                         ipcw.model = ~ previous_number_symptoms + previous_number_relapses, # 新增
                         ipcw.method = "aft (weibull)", # 新增
                         followup.time = NULL,
                         tau0 = tau0,
                         surv.min = 0.025,
                         higher.y = TRUE,
                         prop.cutoff = seq(0.6, 1, length = 5), 
                         prop.multi = c(0, 0.5, 0.6, 1),
                         cv.n = 5,
                         seed = 999,
                         plot.gbmperf = FALSE,
                         verbose = 0)


library(medicaldata)

data(indo_rct)
medicaldata::indo_rct


write.csv(indo_rct,file = "indo_rct.csv")








