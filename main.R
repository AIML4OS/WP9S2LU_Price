#load the packages
source("R/loadpackages.R")
#load the functions  
source("R/functions.R")
#load the additional learners
source("R/learners.R")


#prepare the data
prepare_data()

#load the data
load("data/mydata.rdata")


# define the variables which will be subject to a hot-deck transformation
variables_onehot <- c(
  "HDMI",
  "BRAND"
)

####################
## Linear model#####
####################


#Obtain a model using as a learner a linear model
model_lm <- ML_model(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the features that will be transformed using hotdeck encoding
  variables_onehot = variables_onehot, 
  # the learner that we use: here linear regression
  learner = lrn("regr.lm"),
  #the parameters of the cross-validation: folds and number of time periods 
  folds = 5,
  n= 2
) 


#Obtain imputations with the ML_model
impdata_lm <- imputations(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the Model
  model = model_lm
) 



####################
## Random Forest#####
####################



# Define the parameter space for random forest
search_space_ranger = ps(
  regr.ranger.mtry = p_int(1, 10),
  regr.ranger.sample.fraction = p_dbl(0.5, 1),
  regr.ranger.num.trees = p_int(50, 500))

#Obtain a model using Random Forest
model_rf <- ML_model(data = mydata, 
                  target_var = "P", 
                  time_var = "TD", 
                  id = "JAN",
                  variables_onehot = variables_onehot, 
                  learner = lrn("regr.ranger"),
                  folds = 5,
                  n= 2,
                  search_space = search_space_ranger) 



#Obtain imputations with the ML_model
impdata_rf <- imputations(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the Model
  model = model_rf
) 



####################
##XGBoost #####
####################



# Define the parameter space for XGBoost
search_space_xgboost =ps(
  regr.xgboost.nrounds           = p_int(16, 1000),
  regr.xgboost.eta               = p_dbl(1e-4, 1, logscale = TRUE),
  regr.xgboost.max_depth         = p_int(1, 20),
  regr.xgboost.colsample_bytree  = p_dbl(1e-1, 1),
  regr.xgboost.colsample_bylevel = p_dbl(1e-1, 1),
  regr.xgboost.lambda            = p_dbl(1e-3, 1e3, logscale = TRUE),
  regr.xgboost.alpha             = p_dbl(1e-3, 1e3, logscale = TRUE),
  regr.xgboost.subsample         = p_dbl(1e-1, 1)
  
)

#run the ML pipeline with XGBoost
model_xg <- ML_model(data = mydata, 
                  target_var = "P", 
                  time_var = "TD", 
                  id = "JAN",
                  variables_onehot = variables_onehot, 
                  learner = lrn("regr.xgboost"),
                  folds = 5,
                  n= 2,
                  search_space = search_space_xgboost) 




#Obtain imputations with the ML_model
impdata_xg <- imputations(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the Model
  model = model_xg
) 




########################
##Residual modelling#####
########################



# inititate a custom learner with residual modelling

learner_linrf = LearnerRegrLinRegRF$new()

#obtain model with residual modelling
model_linrf <- ML_model(data = mydata, 
                          target_var = "P", 
                          time_var = "TD", 
                          id = "JAN",
                          variables_onehot = variables_onehot, 
                          learner = learner_linrf,
                          folds = 5,
                          n= 2) 


#Obtain imputations with the ML_model
impdata_linrf <- imputations(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the Model
  model = model_linrf
)




########################
##Closest price #####
########################



# initiate a custom learner that selects the closest price by product 


learner_cp <- LearnerClosestPrice$new(
  time_col = "TD",
  price_col = "P",
  code_col = "JAN"
)

#obtain model with closest price
model_cp <- ML_model(data = mydata,
                  target_var = "P",
                  time_var = "TD",
                  id = "JAN",
                  learner = learner_cp,
                  folds = 5,
                  n= 2,
                  TP_pipeline = TRUE)


#Obtain imputations with the ML_model
impdata_cp <- imputations(
  # name of the datafranme
  data = mydata,  
  # target variable: here the log price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the Model
  model = model_cp
)
