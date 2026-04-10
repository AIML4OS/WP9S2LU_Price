#Custom measure that implements Diewerts D2

MeasureRegrD2 = R6::R6Class(
  "MeasureRegrD2",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.d2",
        range = c(0, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "D2"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      mean((yhat/y-1)^2+(y/yhat-1)^2, na.rm = TRUE)
    }
  )
)


#Custom measure that implements Mean prediction error

MeasureRegrMPE = R6::R6Class(
  "MeasureRegrMPE",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.mpe",
        range = c(0, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "mpe"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      mean(y/yhat-1, na.rm = TRUE)
    }
  )
)


#Custom measure that implements Coefficient of dispersion

MeasureRegrCOD = R6::R6Class(
  "MeasureRegrCOD",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.cod",
        range = c(0, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "cod"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      mean((y/yhat)/median(y/yhat, na.rm=TRUE)-1, na.rm = TRUE)
    }
  )
)


#Custom measure that implements LMDPE

MeasureRegrLMDPE = R6::R6Class(
  "MeasureRegrLMDPE",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.lmdpe",
        range = c(-10, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "lmdpe"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      median(log(y/yhat), na.rm=TRUE)
    }
  )
)



#Custom measure that implements LRMSE

MeasureRegrLRMSE = R6::R6Class(
  "MeasureRegrLMPDE",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.lrmse",
        range = c(0, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "lrmse"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      sqrt(mean((log(y/yhat))^2, na.rm=TRUE))
    }
  )
)




#Custom measure that implements mmPER

MeasureRegrmmPER = R6::R6Class(
  "MeasureRegrmmPER",
  inherit = mlr3::MeasureRegr,
  public = list(
    initialize = function() {
      super$initialize(
        id = "regr.mmper",
        range = c(0, 10),
        minimize = TRUE,
        predict_type = "response",
        label = "mmper"
      )
    }
  ),
  private = list(
    .score = function(prediction, ...) {
      y = prediction$truth
      yhat = prediction$response
      mmper_values = mapply(function(t, r) {
        max_val = max(t, r)
        min_val = min(t, r)
        if (min_val == 0) return(Inf)  # avoid division by zero
        return((max_val / min_val - 1)>0.1)
      }, y, yhat)
      return(mean(mmper_values, na.rm = TRUE))
    }
    
  )
)
