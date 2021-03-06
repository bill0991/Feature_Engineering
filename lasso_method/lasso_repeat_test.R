#! /usr/bin/env Rscript

# Rscript /home/jinsheng_tao/code/R/feature_selection_by_LASSO.R /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/rpm.matrix.2017-10-17.txt /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/train_pathology.list /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/feature_by_LASSO.txt >/Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/feature_by_LASSO.log 2>/Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/feature_by_LASSO.err
# 
# 
# /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/rpm.matrix.2017-10-17.txt 
# /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/train_pathology.list 
# /Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/feature_by_LASSO.txt

library(glmnet)
library(sampling)
library(methods)

feature_selection <- function(train_x,train_y,sampling_times = 50){
  beta_cal = data.frame(feature_name=colnames(train_x))
  train_y_sort = data.frame(rank=seq(length(train_y)),label=train_y)
  train_y_sort = train_y_sort[order(train_y),]
  train_x = train_x[train_y_sort$rank,]
  train_y = train_y_sort$label
  for (i in seq_len(sampling_times)){
    set_myseed = as.integer(paste(1017,i,sep = ""))
    set.seed(set_myseed)
    # sampling
    #sub1 =  sample(nrow(train_x), as.integer(nrow(train_x)*0.75), replace = F)
    sub1 = strata(train_y_sort, stratanames="label",
                  size = as.integer(c(table(train_y)[1]*0.75,table(train_y)[2]*0.75)), method =  "srswor")
    train_x_sample = train_x[sub1$ID_unit,]
    train_y_sample = train_y[sub1$ID_unit]
    # tuning parameter by 10 fold cv
    # glmnet(train_x_sample, train_y_sample, family="binomial",alpha=1);stop()
    fit_cv = cv.glmnet(train_x_sample, train_y_sample, family="binomial",alpha=1,nfolds=10, type.measure = "auc") # run the model and get the parameter lambda.1se
    
    # fit model
    fit_model = glmnet(train_x_sample, train_y_sample, family="binomial",
                       alpha=1, lambda = fit_cv$lambda.1se) # model
    
    feature_important = as.data.frame(as.matrix(fit_model$beta))
    feature_important = feature_important[colnames(train_x),]
    beta_cal = cbind(beta_cal,feature_important)
    colnames(beta_cal)[i+1] = paste('time_',i,sep = "")
    

  }
  return(beta_cal)
}

#输入
train_x = read.delim('/Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/rpm.matrix.2017-10-17.txt',
                     as.is=T,row.names=1,check.names=F)
train_x = train_x[rowSums(train_x!=0)>=30,] #keep rows with >=30 non-zero observations
print(dim(train_x))
train_x = t(train_x) # transpose to make sample as row and feature as column
train_x = train_x/max(train_x)


print(train_x[1:10,1:10])
response = read.delim('/Src_Data1/analysis/Ironman/0.byProjects/LC002/bamfiles/20170504/publication/train/train_pathology.list',
                      as.is=T,check.names=F)
colnames(response) = c("sample","group")
#df = data.frame(sample=rownames(train_x))
#df = merge(df,response,by="sample")
response = response[match(rownames(train_x),response$sample),] #reorder sample order by matrix sample order
train_y = response$group
# print(train_y)
# print(class(train_x))
# print(class(train_y))
# print(table(train_y))
#output = feature_selection(data.matrix(train_x),train_y,sampling_times = 500)
output = feature_selection(train_x,train_y,sampling_times = 1000)
# write.table(output,file=args[3],sep="\t",quote=F)
count_feature = data.frame(feature_name=output$feature_name,count=apply(output[2:ncol(output)]!=0,1,sum))


dat = as.data.frame(train_x)
dat$label = train_y
# write.table(dat,file='/home/binyang_ni/Feature_Engineering/LC002.txt',sep = '\t',quote = F)



beta_cal = data.frame(feature_name=colnames(train_x))
train_y_sort = data.frame(rank=seq(length(train_y)),label=train_y)
train_y_sort = train_y_sort[order(train_y),]
train_x = train_x[train_y_sort$rank,]
train_y = train_y_sort$label
for (i in seq_len(50)){
  set_myseed = as.integer(paste(1017,i,sep = ""))
  set.seed(set_myseed)
  # sampling
  #sub1 =  sample(nrow(train_x), as.integer(nrow(train_x)*0.75), replace = F)
  sub1 = strata(train_y_sort, stratanames="label",
                size = as.integer(c(table(train_y)[1]*0.75,table(train_y)[2]*0.75)), method =  "srswor")
  train_x_sample = train_x[sub1$ID_unit,]
  train_y_sample = train_y[sub1$ID_unit]

  # tuning parameter by 10 fold cv
  # glmnet(train_x_sample, train_y_sample, family="binomial",alpha=1);stop()
  fit_cv = cv.glmnet(train_x_sample, train_y_sample, family="binomial",alpha=1,nfolds=10, type.measure = "deviance") # run the model and get the parameter lambda.1se

  tLL <- fit_cv$glmnet.fit$nulldev - deviance(fit_cv$glmnet.fit)
  k <- fit_cv$glmnet.fit$df
  n <- fit_cv$glmnet.fit$nobs
  AICc <- -tLL+2*k+2*k*(k+1)/(n-k-1)
  
  getmin = function(lambda,AIC){
    AICmin=min(AIC,na.rm=TRUE)
    idmin=AIC<=AICmin
    lambda_selected=max(lambda[idmin],na.rm=TRUE)
    lambda_selected
  }
  
  lambda_selected = getmin(fit_cv$glmnet.fit$lambda,AICc)
  # fit model
  fit_model = glmnet(train_x_sample, train_y_sample, family="binomial",
                     alpha=1, lambda =lambda_selected) # model

  feature_important = as.data.frame(as.matrix(fit_model$beta))
  feature_important = feature_important[colnames(train_x),]
  beta_cal = cbind(beta_cal,feature_important)
  colnames(beta_cal)[i+1] = paste('time_',i,sep = "")

}



count_feature = data.frame(feature_name=beta_cal$feature_name,count=apply(beta_cal[2:ncol(beta_cal)]!=0,1,sum))
table(count_feature$count)

