

#The function that prepares the data for the pipeline

prepare_data <-function(){

# the data included in the Annex of the folliwng paper is stored in a csv file and saved in the data folder 
# Diewert, W. E., & Shimizu, C. (2023). Scanner Data, Product Churn and Quality Adjustment. 
# Meeting of the Group of Experts on Consumer Price Indices. United Nations Economic Commission for Europe
# Available  here https://unece.org/sites/default/files/2023-06/6.3%20Diewert%20and%20Shimizu%20Scanner%20Data%20Product%20Churn%20and%20Quality%20Adjustment%E3%80%80new.pdf

mydata <- read.csv("data/laptop_jp.csv")
  
#we reomve the E (expenditure) and Q (quantity) columns - not used in this project
mydata$E <- mydata$Q <- NULL


#log transformation of the price
mydata$P <-log(mydata$P)

# we code td and jan as factor variables 
mydata$TD <- as.factor(mydata$TD)
mydata$JAN <- as.factor(mydata$JAN)


#we recode the timeperiods and keep only the 13 first periods
levels(mydata$TD) = 1:24
mydata <- subset(mydata, mydata$TD %in% 1:13)
mydata$TD <- droplevels(mydata$TD)


# Extract unique values
time_periods <- unique(mydata$TD)
product_list <- unique(mydata$JAN)

# Create full grid of TD and JAN
mydatafull <- expand.grid(TD = time_periods, JAN = product_list)

# Extract product characteristics
mydata_charac <- unique(mydata[, !names(mydata) %in% c("P", "TD")])

# Merge pricing data
mydatafull <- merge(mydatafull, mydata[, c("P", "TD", "JAN")], by = c("TD", "JAN"), all.x = TRUE)

# Merge product characteristics
mydatafull <- merge(mydatafull, mydata_charac, by = "JAN", all.x = TRUE)

mydata <- mydatafull

save(mydata,file = "data/mydata.rdata")
rm(list = ls())

}



# The function that extecutes the ML pipeline
ML_model <- function(data,
                        target_var,
                        time_var,
                        id,
                        variables_onehot = NA,
                        learner,
                        folds = 5,
                        n = 2,
                        search_space = NA,
                        TP_pipeline = FALSE){
  
  #duplicate the time variable
  data$time_var2 <- data[[time_var]]
  
  # Subset the data to exclude rows with missing target variable
  data_clean <- subset(data, !is.na(data[[target_var]]))
  # Define the regression task
  mytask <- as_task_regr(data_clean, target = target_var)
  
  # Define the pipeline: 1) one-hot encoding, 2) mean encoding, 3) remove ID variable, 4) ML method
  
  if (TP_pipeline){
    
    pipeline <- po("select",  
                   param_vals = list(selector = selector_name(c(target_var,id,time_var)))
                   )%>>%
                learner
    
    
  }    else  {
  
            pipeline <- po("encode", 
                          method = "one-hot",
                          affect_columns = selector_name(c("time_var2",variables_onehot))
                          ) %>>%
                        po("encodeimpact",
                          affect_columns = selector_name(time_var)
                          )%>>%
                        po("select", 
                          param_vals = list(selector = selector_invert(selector_name(id)))
                          )%>>%
                        learner
  }
  
  #plot the pipeline
  pipeline$plot()

  
  # Create the final learner
  mylearner <- as_learner(pipeline)


  # Initiate the time-product cross-validation resampling method
  resampling_method <- rsmp("custom")
  folds_obj <- tpcv(mytask, target_var = target_var, time_var = time_var, id = id, folds = folds, n = n)
  resampling_method$instantiate(mytask, train_sets = folds_obj$train_sets, test_sets = folds_obj$test_sets)

  
  if (missing(search_space))  {
      tuned_learner <- mylearner
  }  else {    
  
      # Define the tuning strategy
      ml_tuned <- AutoTuner$new(
        learner = mylearner,
        resampling = resampling_method,
        measure = msr("regr.rmse"),
        tuner = tnr("mbo"),
        terminator = trm("evals", n_evals = 5),
        search_space = search_space
      )
    
      # Conduct the HPO
      ml_tuned$train(mytask)
    
      # Assign the optimal parameters to the final model
      tuned_learner <- mylearner
      best_params <- ml_tuned$tuning_result$learner_param_vals[[1]]
      tuned_learner$param_set$values <- modifyList(tuned_learner$param_set$values, best_params)
  }
  
  
  # train the model using the optimal parameters. If no HPO is conducted, the default parameters are used.
  rr <- resample(task = mytask,
                 learner = tuned_learner,
                 resampling = resampling_method,
                 store_models = TRUE
  )
  
  #evaluate and print model performance (Root mean Square Error)
  model_performance <- rr$aggregate(msr("regr.rmse"))
  print("Model performance")
  print(model_performance)
  return(rr)
  
}


imputations <- function(data,
                        target_var,
                        time_var,
                        id,
                        model
                        )
  {
  
  
  
  #duplicate the time variable
  data$time_var2 <- data[[time_var]]
  
  #define the task for imputation using the full data set 
  mytaskimp = as_task_regr(data, 
                           target = target_var)
  
  
  # Get predictions from all learners from the different folds
  predicted_prices <- lapply(model$learners, function(learner) {
    learner$predict(mytaskimp)$response
  })
  
  # Name the columns if the imputed target variable dynamically
  names(predicted_prices) <- paste0("imp_price_f", seq_along(predicted_prices))
  
  # Convert to data.frame
  imputation_df <- as.data.frame(predicted_prices)
  
  # Compute row-wise average of imputations
  imputation_df$imp_price_avg <- rowMeans(imputation_df, na.rm = TRUE)
  

  # add a dummy to indicate if a unit was part of the test set in a specific fold
  clean_idx <- which(!is.na(data[[target_var]]))
  for (i in 1:model$iters) {
    test_indices_clean <- model$resampling$test_set(i)
    test_indices_full <- clean_idx[test_indices_clean]
    imputation_df[[paste0("test_", i)]] <- seq_len(nrow(data)) %in% test_indices_full
  }
  

  # Combine with original data
  result <- cbind(
    code = data[[id]],
    time = data[[time_var]],
    obs_price = data[[target_var]],
    imputation_df
  )
  

  return(result)
}



### function that creates a test/train split according to the time product cross validation method

tpcv <- function(task, target_var, time_var, id, folds = 5, n = 3) {
  data <- task$data()
  
  # Create test_first
  data_first <- data %>%
    filter(!is.na(.data[[target_var]])) %>%
    group_by(.data[[id]]) %>%
    arrange(.data[[time_var]]) %>%
    slice_head(n = n) %>%
    select(all_of(c(id, time_var))) %>%
    mutate(test_first = TRUE) %>%
    right_join(data, by = setNames(c(id, time_var), c(id, time_var))) %>%
    mutate(test_first = tidyr::replace_na(test_first, FALSE))
  
  # Create test_last
  data_last <- data %>%
    filter(!is.na(.data[[target_var]])) %>%
    group_by(.data[[id]]) %>%
    arrange(desc(.data[[time_var]])) %>%
    slice_head(n = n) %>%
    select(all_of(c(id, time_var))) %>%
    mutate(test_last = TRUE) %>%
    right_join(data, by = setNames(c(id, time_var), c(id, time_var))) %>%
    mutate(test_last = tidyr::replace_na(test_last, FALSE))
  
  # Assign folds to unique IDs
  ids <- unique(data[[id]])
  fold_ids <- sample(rep(1:folds, length.out = length(ids)))
  train_sets <- vector("list", folds)
  test_sets <- vector("list", folds)
  
  for (fold in seq_len(folds)) {
    test_ids <- ids[fold_ids == fold]
    if (runif(1) < 0.5) {
      test_set <- task$row_ids[data_first[[id]] %in% test_ids & data_first$test_first]
    } else {
      test_set <- task$row_ids[data_last[[id]] %in% test_ids & data_last$test_last]
    }
    train_set <- setdiff(task$row_ids, test_set)
    train_sets[[fold]] <- train_set
    test_sets[[fold]] <- test_set
  }
  
  list(train_sets = train_sets, test_sets = test_sets)
}



