# The marketing team can afford to call only the top 20% of the next list.
# 1. Fit the logit on the training clients
# family = binomial: a 0/1 outcome with the logistic link
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m,
             family = binomial, data = train)

# 2. Predict a PROBABILITY of "yes" for every test client
p <- predict(logit, newdata = test, type = "response")   # "response" = probabilities, not log-odds

# 3. Call the 20% of clients with the highest probabilities
call <- p >= quantile(p, 0.80)             # TRUE for clients at or above the 80th percentile

# 4. Recall: share of all subscribers that the calls reach
#    Precision: share of calls that end in a subscription
recall    <- sum(call & test$yes == 1) / sum(test$yes == 1)   # subscribers reached / all subscribers
precision <- sum(call & test$yes == 1) / sum(call)   # subscribers reached / calls made
c(recall = recall, precision = precision)
