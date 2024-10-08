---
  # title: "**Detecting Fraud**"
  # subtitle: "Part 2: Supervised and Unsupervised Learning"
  
  # Libraries
  library(ggplot2) # plot library
library(tidyverse) # for data manipulation
library(gridExtra) # multiple plots in 1
library(ggrepel) # for graph repel (labels)
library(scales) # for % in density plots

# Predefined personal color schemes
colorsBasketball <- c("#F57E00", "#FFA90A", "#FFCE72", "#3AAFF9", "#0087DC", "#005991")
colors60s <- c("#BF4402", "#94058E", "#005DD7", "#2690C3", "#F5C402", "#CE378E")

# Predefined theme
my_theme <- theme(plot.background = element_rect(fill = "grey97", color = "grey25"),
                  panel.background = element_rect(fill = "grey97"),
                  panel.grid.major = element_line(colour = "grey87"),
                  text = element_text(color = "grey25"),
                  plot.title = element_text(size = 18),
                  plot.subtitle = element_text(size = 14),
                  axis.title = element_text(size = 11),
                  legend.box.background = element_rect(color = "grey25", fill = "grey97", size = 0.5),
                  legend.box.margin = margin(t = 5, r = 5, b = 5, l = 5))
getwd()

# Read in the data
data <- read.csv("C:/Users/siboham/Desktop/yourfile.csv")


# Preprocessing steps
data <- data %>% 
  # remove columns with 1 constant value
  dplyr::select(-zipcodeOri, -zipMerchant) %>% 
  
  # remove comas
  mutate(customer = gsub("^.|.$", "", customer),
         age = gsub("^.|.$", "", age),
         gender = gsub("^.|.$", "", gender),
         merchant = gsub("^.|.$", "", merchant),
         category = gsub("^.|.$", "", category)) %>% 
  
  # remove es_ from "category"
  mutate(category = sub("es_", "", category)) %>% 
  
  # remove Unknown from Gender
  filter(gender != "U")


# Replace U in Age with "7"
data$age[which(data$age == "U")]<-"7"

# Create Amount Thresholds
data <- data %>% 
  mutate(amount_thresh = ifelse(amount<= 500, "0-500",
                                ifelse(amount<= 1000, "500-1000",
                                       ifelse(amount<= 1500, "1000-1500",
                                              ifelse(amount<= 2000, "1500-2000",
                                                     ifelse(amount<= 2500, "2000-2500",
                                                            ifelse(amount<= 3000, "2500-3000", ">3000")))))))
```


# Classifying Fraud (Supervised Learning)
# The purpose of building a fraud classification model is to assign to each new incoming transaction with a high certainty a probability of it being a fraud. Hence, any illegal attempt can be avoided.

```{r message=FALSE, warning=FALSE}
# Libraries
library(fastDummies) # to create dummy variables
library(caret) # for models
install.packages("caretEnsemble")
library(caretEnsemble) # to create ensembles
library(FactoMineR)
library(factoextra)
library(RANN)
library(NbClust)
library(doParallel) # enables parallel training
library(ROSE) # for oversampling
library(imbalance) # also for oversampling
library(smotefamily) # also for oversampling


# Predefined draw confusion matrix function
draw_confusion_matrix <- function(cm) {
  
  layout(matrix(c(1,1,2)))
  par(mar=c(2,2,2,2))
  plot(c(100, 345), c(300, 450), type = "n", xlab="", ylab="", xaxt='n', yaxt='n')
  title('CONFUSION MATRIX', cex.main=2)
  
  # create the matrix 
  rect(150, 430, 240, 370, col=colorsBasketball[2])
  text(195, 435, 'Fraud', cex=1.2)
  rect(250, 430, 340, 370, col=colorsBasketball[4])
  text(295, 435, 'Not Fraud', cex=1.2)
  text(125, 370, 'Predicted', cex=1.3, srt=90, font=2)
  text(245, 450, 'Actual', cex=1.3, font=2)
  rect(150, 305, 240, 365, col=colorsBasketball[4])
  rect(250, 305, 340, 365, col=colorsBasketball[2])
  text(140, 400, 'Fraud', cex=1.2, srt=90)
  text(140, 335, 'Not Fraud', cex=1.2, srt=90)
  
  # add in the cm results 
  res <- as.numeric(cm$table)
  text(195, 400, res[1], cex=1.6, font=2, col='white')
  text(195, 335, res[2], cex=1.6, font=2, col='white')
  text(295, 400, res[3], cex=1.6, font=2, col='white')
  text(295, 335, res[4], cex=1.6, font=2, col='white')
  
  # add in the specifics 
  plot(c(100, 0), c(100, 0), type = "n", xlab="", ylab="", main = "DETAILS", xaxt='n', yaxt='n')
  text(10, 85, names(cm$byClass[1]), cex=1.2, font=2)
  text(10, 70, round(as.numeric(cm$byClass[1]), 3), cex=1.2)
  text(30, 85, names(cm$byClass[2]), cex=1.2, font=2)
  text(30, 70, round(as.numeric(cm$byClass[2]), 3), cex=1.2)
  text(50, 85, names(cm$byClass[5]), cex=1.2, font=2)
  text(50, 70, round(as.numeric(cm$byClass[5]), 3), cex=1.2)
  text(70, 85, names(cm$byClass[6]), cex=1.2, font=2)
  text(70, 70, round(as.numeric(cm$byClass[6]), 3), cex=1.2)
  text(90, 85, names(cm$byClass[7]), cex=1.2, font=2)
  text(90, 70, round(as.numeric(cm$byClass[7]), 3), cex=1.2)
  
  # add in the accuracy information 
  text(30, 35, names(cm$overall[1]), cex=1.5, font=2)
  text(30, 20, round(as.numeric(cm$overall[1]), 3), cex=1.4)
  text(70, 35, names(cm$overall[2]), cex=1.5, font=2)
  text(70, 20, round(as.numeric(cm$overall[2]), 3), cex=1.4)
}  
```


## Feature Engineering
# The feature engineering could arguably be the utmost important step during the preprocessing part of a modeling problem. It has the purpose to transform raw data into dimensionalities that can be better understood by a predictive model, hence it remarkably improves the evaluation metrics. Another important step in the feature engineering process is making sure that there are no features used to train the model that would not be available when a new case would come.

# **Steps:**
# 
#   * recode character variables to numeric
#   * convert characters to double
#   * create `IDs` for Merchant and Customer (current ID is too long)
#   * create new variables `total_transactions` for Customer, Merchant, Age, Gender, Category and Amount Thresh
#   * these new variables to be transformed into percentages from total (easier to read and compute afterwards)
#   * remove `step`
#   * create `Dummy` variables for Age, Gender, Category and Amount Thresh
#   
# ```{r message=FALSE, warning=FALSE}
# ======== Create ID and Total Trans for Customer and Merchant ========
customer <- data %>% 
  group_by(customer) %>% 
  summarise(customer_total_trans = n()) %>% 
  mutate(customer_ID = seq(1, 4109, 1))

merchant <- data %>% 
  group_by(merchant) %>% 
  summarise(merchant_total_trans = n()) %>% 
  mutate(merchant_ID = seq(1, 50, 1))

category <- data %>% 
  group_by(category) %>% 
  summarise(category_total_trans = n()) %>% 
  mutate(category_ID = seq(1, 15, 1))

amount_thresh <- data %>% 
  group_by(amount_thresh) %>% 
  summarise(amount_thresh_total_trans = n()) %>% 
  mutate(amount_thresh_ID = seq(1, 7, 1))


# -------------------------
data <- data %>% 
  # add the 4 new variables
  inner_join(customer, by = "customer") %>% 
  inner_join(merchant, by = "merchant") %>% 
  select(-customer, - merchant) %>% 
  
  
  # age type from chr to dbl
  mutate(age = as.double(age)) %>% 
  # gender coding and type change from chr to dbl
  mutate(gender = ifelse(gender == "M", 1,
                         ifelse(gender == "F", 2, 3))) %>% 
  
  # recode category and add total_category_trans column
  inner_join(category, by = "category") %>% 
  mutate(category = category_ID) %>% 
  select(- category_ID) %>% 
  
  # recode amount_thresh
  inner_join(amount_thresh, by = "amount_thresh") %>% 
  mutate(amount_thresh = amount_thresh_ID) %>% 
  select(-amount_thresh_ID)


# Add also for age and gender total_trans
age <- data %>% 
  group_by(age) %>% 
  summarise(age_total_trans = n())

gender <- data %>% 
  group_by(gender) %>% 
  summarise(gender_total_trans = n())

# ------------------------
data <- data %>%
  inner_join(age, by = "age") %>% 
  inner_join(gender, by = "gender")



# ======== Transform the total_trans numbers into weights ========
# This is done so the numbers will be smaller (except customer_total_trans)
total_freq = 591746

data <- data %>% 
  mutate(merchant_total_trans = round((merchant_total_trans/total_freq)*100, 5),
         category_total_trans = round((category_total_trans/total_freq)*100, 5),
         amount_thresh_total_trans = round((amount_thresh_total_trans/total_freq)*100, 5),
         age_total_trans = round((age_total_trans/total_freq)*100, 5),
         gender_total_trans = round((gender_total_trans/total_freq)*100, 5))



# ======== Remove Step ========
data <- data %>% 
  select(-step) %>% 
  select(fraud, everything())


# ======== Create Dummy Varables for Gender, Age, Category and Amount_Thresh ========
data <- dummy_cols(data, select_columns = c("age", "gender", "category", "amount_thresh"))


# ======== Recode Fraud column ========
data <- data %>% 
  mutate(fraud = ifelse(fraud == "1", "F", "NF"))

dim(data)
```



## Principal Component Analysis
# The purpose of creating a PCA before applying any classification technique is to visualize in 2D how the fraud and non-fraud transactions are grouping and if there is any clear separation between them. 

# * using `age`, `gender`, `category`, `amount`, `amount thresh`
# * first 2 PCs explain ~ 47% of variability
# * all non-fraud values are extremely concentrated over PC2, while fraud is more spread over the PC1 dimensionality
# * there are some cases of non-fraud that have strong fraud "behaviour" (might lead to issues for unsupervised learning)
# 
# ```{r message=FALSE, warning=FALSE}
# Principal Component object (using )
pca_object <- prcomp(data[,c(2:6)], center = TRUE,scale. = TRUE)

# Eigenvalues for Dimensions variability explained
eigenvalues <- get_eig(pca_object)
eigenvalues

# Keep only first 2 PCs and append target column
pca_data <- pca_object$x[, c(1:2)] %>% 
  as.data.frame() %>% 
  mutate(fraud = data$fraud)

# Visualise Fraud
pca_data %>% 
  ggplot(aes(x = PC1, y = PC2)) +
  geom_point(aes(color = fraud, shape = fraud)) +
  my_theme +
  scale_color_manual(values = c(colors60s[1], colors60s[4])) +
  labs(x = "PC1", y = "PC2", title = "Fraud Spread over the first 2 Dimensionalities", subtitle = "frauds & non-frauds have clear different behaviours",
       color = "Fraud", shape = "Fraud")

#ggsave("pca result.jpeg")
```


## Class Imbalance
# As stated before, the fraud and non-fraud cases available in the present dataset have extremely imbalanced weights, with only 1.2% out of the total cases being fraud. Therefore, there are only 7,000 observations labeled as fraud, while the rest 580,000 observations are labeled as clean transactions.

# In a classification problem, this would create difficulties for a model to correctly identify the fraud label, because it is so scarce throughout the dataset. 
# 
# This data structure issue can be solved by using two different sampling techniques: undersampling or oversampling. 

## Undersampling - Splitting the data 65% - 35%

# Undersampling method consists of keeping all available fraud transactions, while undersampling the non-fraud transactions to around the same number.
# 
#   * the split is made so that proportions within the data for `age`, `gender`, `category`, `amount_thresh` and `merchant` remain the same
#   * final table dimension is fraud data: 7,160 and non fraud data: 9,647
#   * we split 65%-35% to be sure that the model classifies as correct as possible non frauds as well (very important for the relationship with the customer)

```{r message=FALSE, warning=FALSE}
set.seed(123)

# ===================================== SPLIT DATA 65% - 35% =====================================
# Because the data is very unbalanced (fraud transactions are only 1.4% from total transactions)

# Creating the fraud dataframe
fraud_data <- data %>% filter(fraud == "F")
dim(fraud_data)

# Creating the non-fraud dataframe
non_fraud_data <- data %>% filter(fraud == "NF")
dim(non_fraud_data)

# Create data Partition
index <- createDataPartition(c(non_fraud_data$age, non_fraud_data$gender, non_fraud_data$category, non_fraud_data$amount_thresh,
                               non_fraud_data$merchant_ID), p = 0.9834, list = F)

good_data <- non_fraud_data[-index, ]
dim(good_data)

# rewrite the non fraud table
non_fraud_data <- good_data

# full data 
undersampling_data <- bind_rows(non_fraud_data, fraud_data)

# Randomize - because data is chronological
set.seed(123)
undersampling_data <- undersampling_data[sample(1:nrow(undersampling_data)), ]

dim(undersampling_data)
```

### Models

# * 75% train and 25% test (and for the 75% uses cross validation)
# 
# * Generalized Linear Model `glm`
# * Linear Discriminant Analysis `lda`
# * Neural Network `nnet`
# * Flexible Discriminant Analysis `fda`
# * Support Vector Machines with Class Weights `svmRadialWeights`
# * k-Nearest Neighbors `knn`
# * Naive Bayes `naive_bayes`
# * Classification and Regression Trees CART `rpart`
# * C4.5-like Trees `J48`
# * Rule-Based Classifier `PART`
# * Random Forest `ranger`
# * AdaBoost Classification Trees `adaboost`
# * eXtreme Gradient Boosting `xgbDART`, `xgbLinear`, `xgbTree`

# For the purpose of this analysis, I will exclude most models from the `caretList()`.
```{r message=FALSE, warning=FALSE, echo = T, results = 'hide'}
set.seed(123)

# Splitting the data into training and testing data
in_train <- createDataPartition(undersampling_data$fraud, p = 0.75, list = F)

train <- undersampling_data[in_train, ]
test <- undersampling_data[-in_train, ]

# Split data into Target and Feature variable
X_train <- train %>% select(-fraud)
y_train <- train$fraud

X_test <- test %>% select(-fraud)
y_test <- test$fraud

# KFolds
myFolds <- createFolds(y_train, k = 5)

# Train Control variable
my_control <- trainControl(method = 'cv', number = 5, index = myFolds,
                           savePredictions = T, classProbs = T, verboseIter = T, summaryFunction = twoClassSummary,
                           preProcOptions = c(thresh = 0.8), allowParallel = T)

# ================== Train and Validation Models ==================
# Models to try
model_list <- caretList(X_train, y_train, trControl = my_control, 
                        methodList = c("fda", "ranger", "xgbTree"),
                        tuneList = NULL, continue_on_fail = FALSE, preProcess = c("zv", "center", "scale"))
```

```{r message=FALSE, warning=FALSE}
# -------------------- Inspect results
resamples <- resamples(model_list)
dotplot(resamples, metric = "Sens")
dotplot(resamples, metric = "Spec")

# -------------------- Create Ensemble (not a better solution, so it won't be showed)
```

# Now check on completely new data to see which performed the best:

```{r message=FALSE, warning=FALSE}
# ============= TESTING DATA ===============
# Final Predictions
pred_xgbTree <- predict.train(model_list$xgbTree, newdata = X_test)
pred_fda <- predict.train(model_list$fda, newdata = X_test)

# Check Sens
preds_sens <- data.frame(xgbTree = sensitivity(as.factor(pred_xgbTree), as.factor(y_test)),
                         fda = sensitivity(as.factor(pred_fda), as.factor(y_test)))
print(preds_sens)

# Plot confusion Matrix
cm <- confusionMatrix(as.factor(pred_xgbTree), as.factor(y_test))
draw_confusion_matrix(cm)

# Create feature importance
var_imp <- varImp(model_list$xgbTree)
var_imp$importance %>% head(10) %>% 
  rownames_to_column("Feature") %>% 
  
  ggplot(aes(x = reorder(Feature, Overall), y = Overall)) +
  geom_bar(stat = "identity", aes(fill = Overall)) +
  coord_flip() +
  geom_label(aes(label = round(Overall, 0)), size = 3) +
  scale_fill_gradient(low = colors60s[4], high = colors60s[2], guide = "none") +
  my_theme +
  labs(x = "Feature", y = "Importance", title = "Most Important Features in Fraud Classification", subtitle = "top 10 in order")
```


## Oversampling - fraud

# Another technique to deal with class imbalance is oversampling. Because using undersampling the model is training on just a fiew observations from the dataset (7,000 + 9,000 = 16,000 obs where the full data has almost 600,000 obs), we chose to use oversampling, dealing with many more true non-fraud cases while oversampling the fraud cases.
# 
# Multiple Oversampling methods were used:

# * `ovun.sample`: it creates possibly balanced samples by randomly oversampling the minority examples
# * `rose`: it is believed to perform better than the first technique. It creates a larger sample of data by enlarging the features space of the minority class and the majority class.
# * `mwmote`: it is a modification of the SMOTE oversampling technique that it is also believed to be better performing. The difference between this and the other oversampling techniques is that it overcomes some issues regarding the noisy instances, avoiding duplicating them
# * `rwo`: abbreviation from “Random Walk Oversampling” method. It generates synthetic examples while trying to maintain the variance and mean of the minority class.

# Only `rwo()` method will be showed in this notebook.

```{r message=FALSE, warning=FALSE}
set.seed(123)

# ===================================== SPLIT DATA =====================================

# Creating the fraud dataframe
fraud_data <- data %>% filter(fraud == "F")
dim(fraud_data)

# Creating the non-fraud dataframe
non_fraud_data <- data %>% filter(fraud == "NF")
dim(non_fraud_data)

# Create data Partition (for non-fraud)
index <- createDataPartition(c(non_fraud_data$age, non_fraud_data$gender, non_fraud_data$category, non_fraud_data$amount_thresh,
                               non_fraud_data$merchant_ID), p = 0.90, list = F)

good_data <- non_fraud_data[-index, ]
dim(good_data)

# rewrite the non fraud table
non_fraud_data <- good_data

# interm data (adding both imbalanced classes)
interm_data <- bind_rows(non_fraud_data, fraud_data)

# ===================================== OVERSAMPLING =====================================

# Create dataset with fctr target column + positive/negative values 
rwo_data <- interm_data %>% 
  mutate(Class = as.factor(ifelse(fraud == "NF", "negative", "positive"))) %>% 
  select(-fraud) %>% 
  select(Class, everything()) %>% 
  as.data.frame()

# 50,000 samples
y <- rwo(rwo_data, numInstances = 50000, classAttr = "Class")

# bind the new samples with the existing data
rwo_data <- rbind(rwo_data, y)
table(rwo_data$Class)

# Randomize the data
set.seed(123)
rwo_data <- rwo_data[sample(1:nrow(rwo_data)), ]
```

```{r message=FALSE, warning=FALSE, echo = T, results = 'hide'}
# ===================================== CREATE MODEL =====================================

set.seed(123)

# Splitting the data into training and testing data
in_train5 <- createDataPartition(rwo_data$Class, p = 0.75, list = F)

train5 <- rwo_data[in_train5, ]
test5 <- rwo_data[-in_train5, ]

# Split data into Target and Feature variable
X_train5 <- train5 %>% select(-Class)
y_train5 <- train5$Class

X_test5 <- test5 %>% select(-Class)
y_test5 <- test5$Class

# KFolds
myFolds <- createFolds(y_train5, k = 5)

# Train Control variable
my_control <- trainControl(method = 'cv', number = 5, index = myFolds,
                           savePredictions = T, classProbs = T, verboseIter = T, summaryFunction = twoClassSummary,
                           preProcOptions = c(thresh = 0.8), allowParallel = T)

# ------------------------- Train and Validation Models -------------------------

# XGBTree Model
xgbTree_rwo <- train(X_train5, y_train5, method = 'xgbTree', trControl = my_control,
                     preProcess = c('zv', 'center', 'scale'))

# fda Model
fda_rwo <- train(X_train5, y_train5, method = 'fda', trControl = my_control,
                 preProcess = c('zv', 'center', 'scale'))
```

```{r message=FALSE, warning=FALSE}                         
# -------------------- Inspect results
xgbTree_rwo$bestTune
xgbTree_rwo$results[which.max(xgbTree_rwo$results$Sens), ]
plot(xgbTree_rwo)

fda_rwo$bestTune
fda_rwo$results[which.max(fda_rwo$results$Sens), ]
plot(fda_rwo)

resamples_rwo <- resamples(c(xgbTree = xgbTree_rwo, fda = fda_rwo))
dotplot(resamples_rwo, metric = "Sens")
dotplot(resamples_rwo, metric = "Spec")


# ===================================== TESTING DATA =====================================
# Final Predictions
pred_xgbTree_rwo <- predict.train(xgbTree_rwo, newdata = X_test5)
pred_fda_rwo <- predict.train(fda_rwo, newdata = X_test5)

# Check Sens
preds_sens_rwo <- data.frame(xgbTree = sensitivity(as.factor(pred_xgbTree_rwo), as.factor(y_test5)),
                             fda = sensitivity(as.factor(pred_fda_rwo), as.factor(y_test5)))
print(preds_sens_rwo)


# Confusion Matrix
cm_tree_rwo <- confusionMatrix(as.factor(pred_xgbTree_rwo), as.factor(y_test5))
draw_confusion_matrix(cm_tree_rwo)


# Create feature importance
var_imp <- varImp(xgbTree_rwo)
var_imp$importance %>% head(10) %>% 
  rownames_to_column("Feature") %>% 
  
  ggplot(aes(x = reorder(Feature, Overall), y = Overall)) +
  geom_bar(stat = "identity", aes(fill = Overall)) +
  coord_flip() +
  geom_label(aes(label = round(Overall, 0)), size = 3) +
  scale_fill_gradient(low = colors60s[4], high = colors60s[2], guide = "none") +
  my_theme +
  labs(x = "Feature", y = "Importance", title = "Most Important Features in Classification", subtitle = "top 10 in descending order")
```


# Unsupervised Learning
# 
#   * identifying suspicious behaviour
#   * using unlabeled data
#   
# **Normal Behaviour**
#                             
#   * transactions amount fairly small (under $500)
#   * payments for transportation and food transactions (don't have any fraud cases)
#   * there are some merchants that don't have any cases of fraud within their transactions
#   
# **Abnormal Behaviour**:
#                                                        
#   * transactions with high amounts (above $500)
#   * transactions made during travel or for leisure activities (like sports/toys expenditure, hotels etc.)
#   * there are some merchants where all transactions made to them are fraud
#   
#   
# **Customer Segmentation**:
#                                                        
#   * there is no need for customer segmentation
#   * as we saw in EDA, number of fraud cases are dp with the number of transactions in both gender and age
#   * so fraud does not really depend on the person who is making the transaction, but on the nature of transaction itself
#   
#   
# **Methodology**:
#                                                        
#   1. Find out which is the best number of clusters for the data
#   2. Perform Kmeans on the data using the best found number
#   3. Compute the distance between the points and the centroid (maybe visualise)
#   4. The outliers for each cluster distance have abnormal behaviour
#   5. How many of these outliers are actually fraud? For which are not fraud, what makes them so abnormal? Inspect.
#   6*. Perform other clustering methods and compare results

## Libraries and Predefined functions

```{r message=FALSE, warning=FALSE}
# Libraries
library(klaR) # used for Naive-Bayes. Must be called before tidyverse, otherwise it masks `select` method
library(FactoMineR)
library(factoextra)
library(mlbench)
library(RANN)
library(e1071)
library(arules)
library(arulesViz)
library(NbClust) # to find best number of clusters
library(dplyr)
library(plot3D) # to make 3D plot for PCA
library(dbscan) # for DBSCAN clustering

# Predefined draw confusion matrix function
draw_confusion_matrix <- function(cm) {
  
  layout(matrix(c(1,1,2)))
  par(mar=c(2,2,2,2))
  plot(c(100, 345), c(300, 450), type = "n", xlab="", ylab="", xaxt='n', yaxt='n')
  title('CONFUSION MATRIX', cex.main=2)
  
  # create the matrix 
  rect(150, 430, 240, 370, col=colorsBasketball[2])
  text(195, 435, 'Fraud', cex=1.2)
  rect(250, 430, 340, 370, col=colorsBasketball[4])
  text(295, 435, 'Not Fraud', cex=1.2)
  text(125, 370, 'Suspect Behaviour', cex=1.3, srt=90, font=2)
  text(245, 450, 'Actual Fraud', cex=1.3, font=2)
  rect(150, 305, 240, 365, col=colorsBasketball[4])
  rect(250, 305, 340, 365, col=colorsBasketball[2])
  text(140, 400, 'Fraud', cex=1.2, srt=90)
  text(140, 335, 'Not Fraud', cex=1.2, srt=90)
  
  # add in the cm results 
  res <- as.numeric(cm$table)
  text(195, 400, res[1], cex=1.6, font=2, col='white')
  text(195, 335, res[2], cex=1.6, font=2, col='white')
  text(295, 400, res[3], cex=1.6, font=2, col='white')
  text(295, 335, res[4], cex=1.6, font=2, col='white')
  
  # add in the specifics 
  plot(c(100, 0), c(100, 0), type = "n", xlab="", ylab="", main = "DETAILS", xaxt='n', yaxt='n')
  text(10, 85, names(cm$byClass[1]), cex=1.2, font=2)
  text(10, 70, round(as.numeric(cm$byClass[1]), 3), cex=1.2)
  text(30, 85, names(cm$byClass[2]), cex=1.2, font=2)
  text(30, 70, round(as.numeric(cm$byClass[2]), 3), cex=1.2)
  text(50, 85, names(cm$byClass[5]), cex=1.2, font=2)
  text(50, 70, round(as.numeric(cm$byClass[5]), 3), cex=1.2)
  text(70, 85, names(cm$byClass[6]), cex=1.2, font=2)
  text(70, 70, round(as.numeric(cm$byClass[6]), 3), cex=1.2)
  text(90, 85, names(cm$byClass[7]), cex=1.2, font=2)
  text(90, 70, round(as.numeric(cm$byClass[7]), 3), cex=1.2)
  
  # add in the accuracy information 
  text(30, 35, names(cm$overall[1]), cex=1.5, font=2)
  text(30, 20, round(as.numeric(cm$overall[1]), 3), cex=1.4)
  text(70, 35, names(cm$overall[2]), cex=1.5, font=2)
  text(70, 20, round(as.numeric(cm$overall[2]), 3), cex=1.4)
}  
```

## Choose best number of clusters

#  * because the data is too large, a sample of 6502 obs was extracted to obtain the best number of clusters
#  * 6424 NF, 78 F
#  * best number of clusters: 3
#                                                       
# > Note: Because the following chunk takes too much to run, I will leave it just commented

```{r}
# # ================= SCALE DATA =================
# # --------- Select only a sample of the data

# # Create data Partition
# index <- createDataPartition(data$fraud, p = 0.989, list = F)

# good_data <- data[-index, ]
# dim(good_data)
# table(good_data$fraud)


# # ------ Scale the data
# scaled_data <- good_data %>%
#   # select only columns that have a lot of information in predicting fraud
#   dplyr::select(amount, gender, age, category, merchant_total_trans, customer_total_trans, merchant_ID, category_total_trans,
#                 customer_ID, amount_thresh, amount_thresh_total_trans) %>% 
#   scale() %>% 
#   as.matrix()


# # ================= BEST NUMBER OF CLUSTERS =================
# set.seed(123)

# kmeans_automat <- scaled_data %>% 
#   NbClust(distance = 'euclidean', min.nc = 2, max.nc = 8, index = 'all', method = 'ward.D2')

# fviz_nbclust(kmeans_automat)
```

## KMEANS CLUSTERING

# * on the entire dataset
# * first 3 PCs = 77% variability

```{r message=FALSE, warning=FALSE}
# ================= SCALE DATA =================
# Total data
scaled_data_big <- data %>%
  # select only some columns
  dplyr::select(amount, gender, age, category, merchant_total_trans, customer_total_trans, merchant_ID, category_total_trans,
                customer_ID, amount_thresh, amount_thresh_total_trans) %>% 
  scale() %>% 
  as.matrix()

# ================= KMEANS =================
set.seed(123)
kmeans_clust_3 <- kmeans(scaled_data_big, centers = 3, nstart = 25)

# Append cluster No. 
kmeans_data <- scaled_data_big %>% 
  as.data.frame() %>% 
  mutate(cluster = kmeans_clust_3$cluster)

# Check the clusters against the fraud label
x <- kmeans_data %>% 
  mutate(fraud = data$fraud)
table(x$cluster, x$fraud)

# Compute the mean of each variable by cluster
aggregate(kmeans_data, by = list(cluster = kmeans_clust_3$cluster), mean)

# ================ PCA =====================
# Principal Component object
pca_object <- prcomp(kmeans_data[,c(1:4)], center = TRUE,scale. = TRUE)

# Eigenvalues for Dimensions variability explained
eigenvalues <- get_eig(pca_object)
eigenvalues

# Keep only first 3 PCs and append cluster column
pca_data <- pca_object$x[, c(1:3)] %>% 
  as.data.frame() %>% 
  mutate(cluster = kmeans_data$cluster)

# x, y and z coordinates
x <- pca_data$PC1
y <- pca_data$PC2
z <- pca_data$PC3

# Visualise the clusters
scatter3D(x, y, z, col.var = as.integer(pca_data$cluster), col = c(colorsBasketball[1], colorsBasketball[2], colorsBasketball[4]),
          colkey = FALSE, main ="Kmeans clusters", phi = 0, bty ="g", pch = 20, cex = 2,
          xlab = "PC1", ylab = "PC2", zlab = "PC3")
```

### Determine the outliers

# **The clusters**:
#                                                        
#   * Cluster 1: It has the majority of observations, grouping 502,245 of the total observations. 5 of them are fraud
#   * Cluster 2: It has 86,838 observations, from which 81,745 are non fraud and 5,093 are fraud
#   * Cluster 3: The smallest cluster, with 2,250 observations, from which 2,062 are fraud and only 88 are non fraud
#   
#   
# **Determining the fraud**:
#                                                        
#   * one possible way is to examine the clusters above
#   * cluster 1 most definitely is the "non-fraud" cluster, with usual behaviour present (to examine the 5 frauds)
#   * cluster 2 has the most fraud cases (5k), but the other 80k non frauds need to be examined
#   * cluster 3 is the fraud cluster, with the most suspect behaviour (the 88 non frauds to be examined)
#   
#   * other possible way is to compute the outliers for each cluster and flag these as abnormal behaviour

```{r message=FALSE, warning=FALSE}
# ========== Computing the distance ============
# the Euclidean distance
distances <- sqrt(rowSums(scaled_data_big - fitted(kmeans_clust_3)) ^ 2)

# Finding the outliers
outliers <- boxplot.stats(distances)$out

# Finding the index positions of the outliers
index_outliers <- which(distances %in% outliers)

# Flag the outliers in the data and create final dataset
kmeans_data_final <- data %>%
  mutate(index = row_number(),
         cluster = kmeans_clust_3$cluster,
         suspect_behaviour = ifelse(index %in% index_outliers, "F", "NF"))


# ========== Assessing K MEANS ============
# Plotting Confusion Matrix
cm_kmeans <- confusionMatrix(reference = as.factor(kmeans_data_final$fraud), data = as.factor(kmeans_data_final$suspect_behaviour))
draw_confusion_matrix(cm_kmeans)
```

# * The sensitivity is quite low, so the outliers approach to identify **suspect behaviour** does not work that good
# 
# So lets analyse again the 3 clusters:

### Cluster 1 - the "non suspect behaviour" group

# * this cluster holds the majority of data: 502,245
# * The majority of the data is Non Fraud - 502,245
# * Only 5 fraud observations
# 
# * We already know the behaviour for non frauds from the EDA:
#                                                      
#   * very small amounts
#   * usually payments for transport, food or health
#   * payments done to the top 3 merchants (were the majority of transactions are) that have no fraud cases registered
# 
# * Because there is such a small number of `frauds`, lets inspect these
#                                                      
#   * they are all in category: Leisure (where almost all transactions are fraud)
#   * the amount is very low (around $50)
#   * so, thats why these observations were labeled in cluster 1

```{r message=FALSE, warning=FALSE}
# Filter only cluster 1
cluster_1 <- kmeans_data_final %>% 
  filter(cluster == 1)

# Inpect data
dim(cluster_1)
table(cluster_1$fraud)

# How do the 5 observations look?
cluster_1 %>% 
  filter(fraud == "F")
```


### Cluster 2 - the "somewhat suspect behaviour" group

# * this is a more omogenous cluster: the most fraud cases but also a lot of non fraud
# * this cluster is very small: 86,838 observations
# * There are the most fraud cases: 5,093
# * A lot of non-fraud cases as well: 81,745
# 
# * the behaviour is between the not suspect at all and extremely suspect behaviours
# 
# * The non-fraud cases:
#                                                      
#   * have many cases in the fashion, retsaurant and wellness and beauty categories, but these are non-fraud transactions
#   * the amounts spent are fairly low, ~$60
#   
# * The fraud cases:
#                                                      
#   * are the ones that have a lower amount (less than $500, usually around ~230)
#   * the transactions are spread throughout all categories

```{r message=FALSE, warning=FALSE}
# Filter only cluster 3
cluster_2 <- kmeans_data_final %>% 
  filter(cluster == 2)

# Inpect data
dim(cluster_2)
table(cluster_2$fraud)

# Inspect non fraud
cluster_2 %>% 
  filter(fraud == "NF") %>% 
  group_by(category) %>% 
  summarise(n())

cluster_2 %>% 
  filter(fraud == "NF") %>% 
  summarise(mean(amount))


# Inspect fraud
cluster_2 %>% 
  filter(fraud == "F") %>% 
  group_by(category) %>% 
  summarise(n())

cluster_2 %>% 
  filter(fraud == "F") %>% 
  summarise(mean(amount))
```

