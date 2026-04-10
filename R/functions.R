


prepare_data <-function(){
  
  # the data included in the Annex of the folliwng paper is stored in a csv file and saved in the data folder 
  # Diewert, W. E., & Shimizu, C. (2023). Scanner Data, Product Churn and Quality Adjustment. 
  # Meeting of the Group of Experts on Consumer Price Indices. United Nations Economic Commission for Europe
  # Available  here https://unece.org/sites/default/files/2023-06/6.3%20Diewert%20and%20Shimizu%20Scanner%20Data%20Product%20Churn%20and%20Quality%20Adjustment%E3%80%80new.pdf
  
  mydata <- read.csv("data/laptop_jp.csv")
  
  #we reomve the E (expenditure) and Q (quantity) columns - not used in this project
  mydata$E <- mydata$Q <- NULL
  
  # we remove the firt column with row numbers
  mydata$OBS <- NULL 
  
  
  # we code td and jan as factor variables 
  mydata$TD <- as.factor(mydata$TD)
  mydata$JAN <- as.factor(mydata$JAN)
  
  # we code CPU and brand as factor variables for impact encoding 
  mydata$BRAND <- as.factor(mydata$BRAND)
  
  
  #we recode the timeperiods and keep only the 13 first periods
  levels(mydata$TD) = 1:24
  mydata <- subset(mydata, mydata$TD %in% 1:13)
  mydata$TD <- droplevels(mydata$TD)

  # log transfromations
  mydata$CLOCK <- log(mydata$CLOCK)
  mydata$PIX <- log(mydata$PIX)
  
  
  save(mydata,file = "data/mydata.rdata")
  rm(list = ls())
  
}


#The function that prepares the data for the pipeline

# The function that extecutes the ML pipeline
ML_model <- function(data,
                     target_var,
                     time_var,
                     id,
                     variables_onehot = NA,
                     variables_impact = NA,
                     learner,
                     folds = 5,
                     n = 2,
                     search_space = NA,
                     TP_pipeline = FALSE,
                     seed_value = 1234){
  
  set.seed(seed_value)
  
  # Define the regression task
  mytask <- as_task_regr(data, target = target_var)
  
  # Prepare the learner
  base_lrn <- learner$clone()
  base_lrn$predict_type <- "response"         # Ensure it produces numeric predictions
  
  # Define the pipeline
  
  if (TP_pipeline){
    #basic pipeline if basic learner
    pipeline <-   po("select",  
                     param_vals = list(selector = selector_name(c(target_var,id,time_var)))
    )%>>%
      learner
    
  }    else  {
    
    
    # --- PipeOps ---
    po_encimpact = po("encodeimpact",
                      affect_columns = selector_name(c(variables_impact))
    )
    
    po_onehot = po("encode",
                   method = "one-hot",
                   affect_columns = selector_name(c(time_var, variables_onehot))
    )
    
    po_removeid = po("select",
                     selector = selector_invert(selector_name(id))
    )
    
    po_base = po("learner_cv",
                 base_lrn,
                 id = "base_learner",
                 resampling.method = "insample"
    )
    
    po_union = po("featureunion")
    
    po_select_bias = po("select", id = "select_bias")   
    
    po_bias = po("learner", lrn("regr.lm"), id = "bias_adjustment")
    
    # --- Build Graph ---
    pipeline <- Graph$new()
    
    pipeline$add_pipeop(po_encimpact)
    pipeline$add_pipeop(po_onehot)
    pipeline$add_pipeop(po_removeid)
    pipeline$add_pipeop(po_base)
    pipeline$add_pipeop(po_union)
    pipeline$add_pipeop(po_select_bias)
    pipeline$add_pipeop(po_bias)
    
    # --- Edges ---
    pipeline$add_edge("encodeimpact", "encode")
    pipeline$add_edge("encode", "select")
    
    # encoded features → featureunion
    pipeline$add_edge("select", "featureunion")
    
    # base learner prediction → featureunion
    pipeline$add_edge("select", "base_learner")
    pipeline$add_edge("base_learner", "featureunion")
    
    # featureunion → select_bias → final regression
    pipeline$add_edge("featureunion", "select_bias")
    pipeline$add_edge("select_bias", "bias_adjustment")
    
    pipeline$pipeops$select_bias$param_set$values$selector <- selector_union(
      selector_grep("^base_learner\\."),
      selector_grep(paste0("^",time_var,"\\."))
    )
    
  }
  
  # Add the logarithmic trnasformation to the graph 
  
  g_ppl <- ppl("targettrafo", graph = pipeline)
  g_ppl$param_set$values$targetmutate.trafo <- function(x) log(x)
  g_ppl$param_set$values$targetmutate.inverter <- function(x) {
    list(response = exp(x$response))
  }
  
  # visualize and convert to a learner
  g_ppl$plot()
 mylearner <- as_learner(g_ppl)
  
  
  
  # Instantiate custom resampling 
  
  
  
  # 1) Create custom resampling and instantiate on THIS task
  resampling_method <- rsmp("custom")
  
  folds_obj <- tpcv(
    mytask,
    target_var = target_var,
    time_var   = time_var,
    id         = id,
    folds      = folds,
    n          = n
  )
  
  # Sanity checks 
  stopifnot(all(unlist(folds_obj$train_sets) %in% mytask$row_ids))
  stopifnot(all(unlist(folds_obj$test_sets)  %in% mytask$row_ids))
  
  resampling_method$instantiate(
    task       = mytask,
    train_sets = folds_obj$train_sets,
    test_sets  = folds_obj$test_sets
  )
  
  # 2) Tuning OR default modeling
  if (missing(search_space)) {
    
    # No tuning: just train the learner directly
    mylearner$train(mytask)
    tuned_learner <- mylearner
    
  } else {
    
    # Tuning with custom resampling on the same task
    ml_tuned <- AutoTuner$new(
      learner      = mylearner,
      resampling   = resampling_method,         
      measure      = msr("regr.rmse"),
      tuner        = tnr("mbo"),
      terminator   = trm("evals", n_evals = 5),
      search_space = search_space
    )
    
    # select the best hyperparameters, and refit on the full 'mytask'.
    ml_tuned$train(mytask)
    tuned_learner <- ml_tuned$learner
  }
  # Model evaluation
  
  rr <- resample(
    task = mytask,
    learner =tuned_learner,
    resampling = resampling_method,
    store_models = TRUE)
  
  
  #evaluate model performance
  
  mpe = MeasureRegrMPE$new()
  cod = MeasureRegrCOD$new()
  lmdpe = MeasureRegrLMDPE$new()
  lrmse = MeasureRegrLRMSE$new()
  mmper = MeasureRegrmmPER$new()
  
  rmse = msr("regr.rmse")
  mae = msr("regr.mae")
  mape = msr("regr.mape")
  
  model_performance <- rr$aggregate(list(rmse, mae, mape,mpe,cod,lmdpe,lrmse,mmper))
  
  #print and save model performance
  print("Model performance")
  print(model_performance)
  model_performance <- data.frame(measure= c("rmse", "mae", "mape","mpe","cod","lmdpe","lrmse","mmper"), perf = model_performance)
  save(model_performance, file=paste0("outputs/modelperformance",learner$id,".Rdata"))

  
  #return  tuned learner trained on the full data set
  return(tuned_learner)
  
}


imputations <- function(data,
                        target_var,
                        time_var,
                        id,
                        learner
)
{
  
  
  
  
  #define the task 
  mytask = as_task_regr(data, 
                        target = target_var)
  
  
  # Extract data and factor levels
  X = as.data.table(mytask$data())
  time_var = time_var
  time_levels = levels(X[[time_var]])
  
  
  # Make one prediction column per time level
  pred_cols = lapply(time_levels, function(tlev) {
    
    tmp = copy(X)
    
    # Overwrite the time variable for all units
    tmp[[time_var]] = factor(tlev, levels = time_levels)
    
    # Temporary task for prediction
    task_tmp = TaskRegr$new(
      id = paste0("cf_", tlev),
      backend = tmp,
      target = mytask$target_names
    )
    
    # Predict
    preds = learner$predict(task_tmp)
    
    # Return vector of predictions
    preds$response
  })
  
  #  Bind as columns
  pred_matrix = as.data.table(pred_cols)
  setnames(pred_matrix, paste0("pred_time_", time_levels))
  
  # Combine with original unit identifiers 
  cols <- c(id,target_var,time_var)
  final_result = cbind(X[,..cols], pred_matrix)
  
  
  #test orthogonality property
  test_predictions <- learner$predict(mytask)
  esp <- log(test_predictions$truth)-log(test_predictions$response)
  test_df <- data.frame (esp = esp, time = X[[time_var]])
  
  ortho_test <- tapply(test_df$esp, test_df$time, mean)
  print("Applying model on observed data: Average error by time period")
  print(ortho_test)
  rm(test_df)
  
  
  
  
  return(final_result)
}



### function calculates a GEKS (Gini–Eltetö–Köves–Szulc) multilateral price index 
### using imputed prices across multiple time periods. Bilateral price relatives are computed using geometric means and
### subsequently aggregated into a GEKS index normalized to the first period.


price_index <- function(imputations, 
                        target_var, 
                        time_var,
                        name_index = NA) {
  
  # Extract time levels and number of periods
  time_levels <- levels(imputations[[time_var]])
  T <- length(time_levels)
  
  # Initialize matrices
  bilateral <- matrix(1, nrow = T, ncol = T)
  Index_bil <- matrix(1, nrow = T, ncol = T)
  GEKS <- numeric(T)
  
  # Identify imputed price columns
  pred_cols <- grep("^pred_time_", names(imputations), value = TRUE)
  
  # --------------------------------------------------
  # Step 1: Compute bilateral price relatives
  # --------------------------------------------------
  i <- 1
  for (t in time_levels) {
    j <- 1
    for (pred_price in pred_cols) {
      
      # Subset data for time period t
      temp <- subset(imputations, imputations[[time_var]] == t)
      
      # Geometric mean price ratio
      bilateral[i, j] <-
        exp(mean(log(temp[[pred_price]]))) /
        exp(mean(log(temp[[target_var]])))
      
      j <- j + 1
    }
    i <- i + 1
  }
  
  # --------------------------------------------------
  # Step 2: Symmetrize bilateral indices
  # --------------------------------------------------
  
  i <- 1
  for (t in time_levels) {
    j <- 1
    for (s in time_levels) {
      
      Index_bil[i, j] <-
        (bilateral[i, j] * 1 / bilateral[j, i])^0.5
      
      j <- j + 1
    }
    i <- i + 1
  }
  
  # --------------------------------------------------
  # Step 3: Compute GEKS index
  # --------------------------------------------------
  i <- 1
  for (t in time_levels) {
    
    GEKS[i] <-
      exp(mean(log(Index_bil[, i]))) /
      exp(mean(log(Index_bil[, 1])))
    
    i <- i + 1
  }
  
  #save the index
  index <- data.frame(time = time_levels, GEKS = GEKS)
  save(index, file=paste0("outputs/index",name_index,".Rdata"))
  
  return(GEKS)
}



### function that creates a test/train split according to the time product cross validation method



tpcv <- function(task, target_var, time_var, id, folds = 5, n = 2, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  
  data <- task$data()
  row_ids <- task$row_ids
  
  # Filter rows with non-missing target
  data_non_na <- data[!is.na(data[[target_var]]), ]
  
  # Assign folds to IDs
  ids <- unique(data_non_na[[id]])
  fold_ids <- sample(rep(1:folds, length.out = length(ids)))
  
  train_sets <- vector("list", folds)
  test_sets <- vector("list", folds)
  
  for (fold in seq_len(folds)) {
    test_ids <- ids[fold_ids == fold]
    
    # For each ID in test_ids, select n first OR n last rows
    test_indices <- integer(0)
    for (current_id in test_ids) {
      subset_rows <- which(data[[id]] == current_id & !is.na(data[[target_var]]))
      subset_rows <- subset_rows[order(data[[time_var]][subset_rows])]
      
      if (runif(1) < 0.5) {
        chosen_rows <- head(subset_rows, n)  # first n
      } else {
        chosen_rows <- tail(subset_rows, n)  # last n
      }
      
      test_indices <- c(test_indices, chosen_rows)
    }
    
    train_indices <- setdiff(seq_along(row_ids), test_indices)
    
    train_sets[[fold]] <- row_ids[train_indices]
    test_sets[[fold]] <- row_ids[test_indices]
  }
  
  list(train_sets = train_sets, test_sets = test_sets)
}
