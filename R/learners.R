

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

