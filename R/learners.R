

##Basic learner that repeats the price, of the closest time period, by product


LearnerClosestPrice <- R6::R6Class("LearnerClosestPrice",
                                   inherit = mlr3::LearnerRegr,
                                   
                                   public = list(
                                     train_data = NULL,
                                     time_col = NULL,
                                     price_col = NULL,
                                     code_col = NULL,
                                     
                                     initialize = function(time_col, price_col, code_col) {
                                       self$time_col <- time_col
                                       self$price_col <- price_col
                                       self$code_col <- code_col
                                       
                                       super$initialize(
                                         id = "regr.closest_price",
                                         feature_types = c("numeric", "factor", "integer"),
                                         predict_types = c("response"),
                                         packages = character(0),
                                         properties = c("missings")
                                       )
                                     }
                                   ),
                                   
                                   private = list(
                                     .train = function(task) {
                                       self$train_data <- task$data(rows = task$row_ids)
                                     },
                                     
                                     .predict = function(task) {
                                       test_data <- task$data(rows = task$row_ids)
                                       train_data <- self$train_data
                                       
                                       time_col <- self$time_col
                                       price_col <- self$price_col
                                       code_col <- self$code_col
                                       
                                       # Ensure columns exist
                                       required_cols <- c(time_col, price_col, code_col)
                                       if (!all(required_cols %in% names(train_data))) {
                                         stop("Missing required columns in training data.")
                                       }
                                       if (!all(c(time_col, code_col) %in% names(test_data))) {
                                         stop("Missing required columns in test data.")
                                       }
                                       
                                       # Convert time and code columns safely
                                       train_data[[time_col]] <- as.numeric(as.character(train_data[[time_col]]))
                                       test_data[[time_col]] <- as.numeric(as.character(test_data[[time_col]]))
                                       
                                       train_data[[code_col]] <- as.character(train_data[[code_col]])
                                       test_data[[code_col]] <- as.character(test_data[[code_col]])
                                       
                                       global_mean <- mean(train_data[[price_col]], na.rm = TRUE)
                                       
                                       predictions <- sapply(seq_len(nrow(test_data)), function(i) {
                                         code_i <- test_data[[code_col]][i]
                                         time_i <- test_data[[time_col]][i]
                                         
                                         subset <- train_data[train_data[[code_col]] == code_i, ]
                                         
                                         if (nrow(subset) > 0) {
                                           time_diffs <- abs(subset[[time_col]] - time_i)
                                           closest_index <- which.min(time_diffs)
                                           prediction <- subset[[price_col]][closest_index]
                                         } else {
                                           prediction <- global_mean
                                         }
                                         
                                         return(prediction)
                                       })
                                       
                                       return(list(response = unname(as.numeric(predictions))))
                                     }
                                   )
)



#Learner with residual modelling : Linear model + random forest

LearnerRegrLinRegRF = R6::R6Class("LearnerRegrLinRegRF",
                                 inherit = mlr3::LearnerRegr,
                                 public = list(
                                   linear_model = NULL,
                                   rf_model = NULL,
                                   
                                   initialize = function() {
                                     
                                     ps = ps(
                                       always.split.variables       = p_uty(tags = "train"),
                                       holdout                      = p_lgl(default = FALSE, tags = "train"),
                                       importance                   = p_fct(c("none", "impurity", "impurity_corrected", "permutation"), tags = "train"),
                                       keep.inbag                   = p_lgl(default = FALSE, tags = "train"),
                                       max.depth                    = p_int(default = NULL, lower = 1L, special_vals = list(NULL), tags = "train"),
                                       min.bucket                   = p_int(1L, default = 1L, tags = "train"),
                                       min.node.size                = p_int(1L, default = 5L, special_vals = list(NULL), tags = "train"),
                                       mtry                         = p_int(lower = 1L, special_vals = list(NULL), tags = "train"),
                                       mtry.ratio                   = p_dbl(lower = 0, upper = 1, tags = "train"),
                                       na.action                    = p_fct(c("na.learn", "na.omit", "na.fail"), default = "na.learn", tags = "train"),
                                       node.stats                   = p_lgl(default = FALSE, tags = "train"),
                                       num.random.splits            = p_int(1L, default = 1L, tags = "train", depends = quote(splitrule == "extratrees")),
                                       num.threads                  = p_int(1L, default = 1L, tags = c("train", "predict", "threads")),
                                       num.trees                    = p_int(1L, default = 500L, tags = c("train", "predict", "hotstart")),
                                       oob.error                    = p_lgl(default = TRUE, tags = "train"),
                                       poisson.tau                  = p_dbl(default = 1, tags = "train", depends = quote(splitrule == "poisson")),
                                       regularization.factor        = p_uty(default = 1, tags = "train"),
                                       regularization.usedepth      = p_lgl(default = FALSE, tags = "train"),
                                       replace                      = p_lgl(default = TRUE, tags = "train"),
                                       respect.unordered.factors    = p_fct(c("ignore", "order", "partition"), tags = "train"),
                                       sample.fraction              = p_dbl(0L, 1L, tags = "train"),
                                       save.memory                  = p_lgl(default = FALSE, tags = "train"),
                                       scale.permutation.importance = p_lgl(default = FALSE, tags = "train", depends = quote(importance == "permutation")),
                                       se.method                    = p_fct(c("jack", "infjack"), default = "infjack", tags = "predict"), # FIXME: only works if predict_type == "se". How to set dependency?
                                       seed                         = p_int(default = NULL, special_vals = list(NULL), tags = c("train", "predict")),
                                       split.select.weights         = p_uty(default = NULL, tags = "train"),
                                       splitrule                    = p_fct(c("variance", "extratrees", "maxstat", "beta", "poisson"), default = "variance", tags = "train"),
                                       verbose                      = p_lgl(default = TRUE, tags = c("train", "predict")),
                                       write.forest                 = p_lgl(default = TRUE, tags = "train")
                                     )
                                     
                                     ps$set_values(num.threads = 1L)
                                     
                                     super$initialize(
                                       id = "regr.linreg_rf",
                                       param_set = ps,
                                       feature_types = c("logical", "integer", "numeric", "character", "factor", "ordered"),
                                       predict_types = c("response"),
                                       properties = c("missings", "weights"),
                                       packages = c("mlr3learners", "ranger"),
                                       label = "Linear Random Forest"
                                     )
                                   }),
                                 private = list(
                                   .train = function(task) {
                                     data = task$data()
                                     target = task$target_names
                                     
                                     # Fit linear regression model
                                     self$linear_model = lm(as.formula(paste(target, "~ .")), data = data)
                                     
                                     # Compute residuals
                                     residuals = residuals(self$linear_model)
                                     data$residuals = residuals
                                     data <- select(data,-target)
                                     
                                     # get hyperparameters of random forest
                                     pv = self$param_set$get_values(tags = "train")
                                    
                                     # Fit random forest model on residuals
                                     
                                     self$rf_model <- invoke(ranger::ranger,
                                                             dependent.variable.name = "residuals",
                                                             data = data,
                                                             case.weights = task$weights$weight,
                                                             .args = pv
                                     )
                                     
                                     
                                   },
                                   
                                   .predict = function(task) {
                                     newdata = task$data(cols = task$feature_names)
                                     
                                     # Predict with linear regression model
                                     linreg_pred = predict(self$linear_model, newdata)
                                     
                                     # Predict residuals with random forest model
                                     rf_pred = predict(self$rf_model, newdata)$predictions
                                     
                                     # Combine predictions
                                     response = linreg_pred + rf_pred
                                     list(response = response)
                                   }
                                 ))


