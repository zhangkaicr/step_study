calculate_q_score <- function(X, Y, W, T, max_quantiles = 8) {
  
  # Calculate Q-score for causal inference model evaluation
  # 
  # Parameters:
  # X: Feature matrix (n x p)
  # Y: Outcome vector (n x 1) 
  # W: Treatment assignment vector (n x 1), 0 for control, 1 for treatment
  # T: Predicted individual treatment effects (n x 1)
  # max_quantiles: Maximum number of quantiles to consider (default 8)
  # 
  # Returns:
  # Q-score value

  
  n <- length(Y)
  
  # Sort data by predicted treatment effects
  order_idx <- order(T)
  T_sorted <- T[order_idx]
  Y_sorted <- Y[order_idx]
  W_sorted <- W[order_idx]
  
  # Calculate overall ATE
  ATE <- mean(Y[W == 1]) - mean(Y[W == 0])
  
  # Initialize loss functions
  L_Q_total <- 0
  L_ATE_total <- 0
  weight_total <- 0
  
  # Loop through different quantile cuts (powers of 2)
  for (i in 2:max_quantiles) {
    if (i > n/10) break  # Ensure sufficient samples per quantile
    
    # Create quantiles
    quantile_breaks <- quantile(T_sorted, probs = seq(0, 1, length.out = i + 1))
    
    # Calculate loss for this quantile cut
    L_Qi <- 0
    L_ATEi <- 0
    
    for (j in 1:i) {
      # Define quantile range
      if (j == 1) {
        q_mask <- T_sorted <= quantile_breaks[j + 1]
      } else if (j == i) {
        q_mask <- T_sorted > quantile_breaks[j]
      } else {
        q_mask <- T_sorted > quantile_breaks[j] & T_sorted <= quantile_breaks[j + 1]
      }
      
      # Skip if quantile is empty or has insufficient data
      if (sum(q_mask) < 2 || sum(W_sorted[q_mask]) == 0 || sum(1 - W_sorted[q_mask]) == 0) {
        next
      }
      
      # Calculate observed quantile treatment effect
      Y_treated_q <- Y_sorted[q_mask & W_sorted == 1]
      Y_control_q <- Y_sorted[q_mask & W_sorted == 0]
      
      if (length(Y_treated_q) > 0 && length(Y_control_q) > 0) {
        observed_qte <- mean(Y_treated_q) - mean(Y_control_q)
        
        # Calculate expected quantile treatment effect
        T_quantile <- T_sorted[q_mask]
        expected_qte <- mean(T_quantile)
        
        # Calculate losses
        L_Qij <- (observed_qte - expected_qte)^2
        L_ATEij <- (ATE - expected_qte)^2
        
        L_Qi <- L_Qi + L_Qij
        L_ATEi <- L_ATEi + L_ATEij
      }
    }
    
    # Average over quantiles for this cut
    L_Qi <- L_Qi / i
    L_ATEi <- L_ATEi / i
    
    # Weight function (equal weights for simplicity)
    weight <- 1
    
    L_Q_total <- L_Q_total + weight * L_Qi
    L_ATE_total <- L_ATE_total + weight * L_ATEi
    weight_total <- weight_total + weight
  }
  
  # Calculate final Q-score
  if (L_ATE_total > 0) {
    Q_score <- 1 - (L_Q_total / weight_total) / (L_ATE_total / weight_total)
  } else {
    Q_score <- 0
  }
  
  return(list(
    Q_score = Q_score,
    L_Q = L_Q_total / weight_total,
    L_ATE = L_ATE_total / weight_total
  ))
}

# Simple Causal Forest Implementation for demonstration
# This is a simplified version for educational purposes

# Function to simulate causal forest predictions
simulate_causal_forest <- function(X, Y, W, n_trees = 100) {
  # Simplified causal forest that predicts treatment effects
  # In practice, you would use the grf package or similar
  
  n <- nrow(X)
  p <- ncol(X)
  
  # Calculate simple treatment effects based on features
  # This is a simplified approach - real causal forest is much more complex
  
  # Base treatment effect
  base_effect <- mean(Y[W == 1]) - mean(Y[W == 0])
  
  # Feature-based modifications
  feature_effects <- rep(0, n)
  
  # Simple linear combination with some randomness
  for (i in 1:p) {
    # Normalize features
    x_norm <- scale(X[, i])
    # Add feature effect with some noise
    feature_effects <- feature_effects + x_norm * rnorm(1, 0, 0.1)
  }
  
  # Combine base effect with feature effects
  T_pred <- base_effect + feature_effects * 0.5
  
  return(T_pred)
}

# Function to generate synthetic test data
generate_test_data <- function(n = 1000, p = 5, seed = 42) {
  set.seed(seed)
  
  # Generate features
  X <- matrix(rnorm(n * p), nrow = n, ncol = p)
  colnames(X) <- paste0("X", 1:p)
  
  # Generate treatment assignment (randomized)
  W <- rbinom(n, 1, 0.5)
  
  # Generate true treatment effects (heterogeneous)
  true_effects <- 2 + X[, 1] * 0.5 + X[, 2] * 0.3 + rnorm(n, 0, 0.2)
  
  # Generate outcomes
  Y0 <- 10 + X[, 1] * 2 + X[, 2] * 1.5 + X[, 3] * 0.8 + rnorm(n, 0, 1)  # Control potential outcome
  Y1 <- Y0 + true_effects  # Treatment potential outcome
  
  # Observed outcomes
  Y <- ifelse(W == 1, Y1, Y0)
  
  return(list(
    X = X,
    Y = Y,
    W = W,
    true_effects = true_effects,
    Y0 = Y0,
    Y1 = Y1
  ))
}

# Generate test data
print("Generating synthetic test data...")
test_data <- generate_test_data(n = 1000, p = 5)

print(paste("Generated data with", nrow(test_data$X), "observations and", ncol(test_data$X), "features"))
print(paste("Treatment group size:", sum(test_data$W)))
print(paste("Control group size:", sum(1 - test_data$W)))
print(paste("True ATE:", round(mean(test_data$true_effects), 3)))



# Apply causal forest and calculate Q-score
print("Applying Causal Forest to predict treatment effects...")

# Predict treatment effects using simplified causal forest
T_pred <- simulate_causal_forest(test_data$X, test_data$Y, test_data$W)

print(paste("Predicted treatment effects range:", 
            round(min(T_pred), 3), "to", round(max(T_pred), 3)))

# Calculate Q-score
print("Calculating Q-score...")
q_result <- calculate_q_score(test_data$X, test_data$Y, test_data$W, T_pred)

print("Q-Score Results:")
print("================")
print(paste("Q-score:", round(q_result$Q_score, 4)))
print(paste("L_Q (Model loss):", round(q_result$L_Q, 4)))
print(paste("L_ATE (Baseline loss):", round(q_result$L_ATE, 4)))

# Compare with true treatment effects for validation
correlation_true_pred <- cor(test_data$true_effects, T_pred)
print(paste("Correlation between true and predicted effects:", round(correlation_true_pred, 4)))
