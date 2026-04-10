#to insall packages in your local renv repository
# use renv::restore()

#load the packages
source("R/loadpackages.R")
#load the functions  
source("R/functions.R")
#load the additional learners
source("R/learners.R")

#load the additional measures
source("R/measure.R")


#prepare the data
prepare_data()

#load the data
load("data/mydata.rdata")


# define the variables which will be subject to a hot-deck transformation
variables_onehot <- c(
  "HDMI",
  "TD"
)


variables_impact <- c( "BRAND")



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
  # the features that will be transformed using impact encoding
  variables_impact = variables_impact,
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
  # target variable: here the price
  target_var = "P", 
  # the time variable
  time_var = "TD",
  # the variable that identifies a product
  id = "JAN", 
  # the model
  learner = model_lm
) 


# price index calculations

index_lm <- price_index(
                        #name of the dataframe obtained with the imputations function
                        imputations = impdata_lm,
                        # target variable: here the price
                        target_var = "P", 
                        # the time variable
                        time_var = "TD",
                        #the name of the index
                        name_index = "LM"
)




####################
## Random Forest#####
####################



# Define the parameter space for random forest
search_space_ranger = ps(
  base_learner.mtry = p_int(1, 10),
  base_learner.sample.fraction = p_dbl(0.5, 1),
  base_learner.num.trees = p_int(50, 500))

#Obtain a model using Random Forest
model_rf <- ML_model(data = mydata, 
                     target_var = "P", 
                     time_var = "TD", 
                     id = "JAN",
                     variables_onehot = variables_onehot, 
                     variables_impact = variables_impact,
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
  learner = model_rf
) 




# price index calculations
index_rf <- price_index(  imputations = impdata_rf,
                          target_var = "P", 
                          time_var = "TD",
                          name_index = "RF")





####################
##XGBoost #####
####################



# Define the parameter space for XGBoost
search_space_xgboost =ps(
  base_learner.nrounds           = p_int(16, 1000),
  base_learner.eta               = p_dbl(1e-4, 1, logscale = TRUE),
  base_learner.max_depth         = p_int(1, 20),
  base_learner.colsample_bytree  = p_dbl(1e-1, 1),
  base_learner.colsample_bylevel = p_dbl(1e-1, 1),
  base_learner.lambda            = p_dbl(1e-3, 1e3, logscale = TRUE),
  base_learner.alpha             = p_dbl(1e-3, 1e3, logscale = TRUE),
  base_learner.subsample         = p_dbl(1e-1, 1)
  
)

#run the ML pipeline with XGBoost
model_xg <- ML_model(data = mydata, 
                     target_var = "P", 
                     time_var = "TD", 
                     id = "JAN",
                     variables_onehot = variables_onehot, 
                     variables_impact = variables_impact,
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
  learner = model_xg
) 



# price index calculations

index_xg <- price_index(imputations = impdata_xg,
                        target_var = "P", 
                        time_var = "TD",
                        name_index = "XG")






########################
##Closest price #####
########################



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
                     TP_pipeline = TRUE,
                     folds = 5,
                     n= 2) 



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
  learner = model_cp
) 

# price index calculations
index_cp <- price_index(imputations = impdata_cp,
                        target_var = "P", 
                        time_var = "TD",
                        name_index = "CP")
