# The marketing team can afford to call only the top 20% of the next list.
# 1. Fit the logit on the training clients
logit <- glm(yes ~ age + contact + campaign + poutcome + euribor3m,
             family = ______, data = train)

# 2. Predict a PROBABILITY of "yes" for every test client
p <- predict(logit, newdata = test, type = "______")

# 3. Call the 20% of clients with the highest probabilities
call <- p >= quantile(p, 0.80)

# 4. Recall: share of all subscribers that the calls reach
#    Precision: share of calls that end in a subscription
recall    <- sum(call & test$yes == 1) / ______
precision <- sum(call & test$yes == 1) / sum(call)
c(recall = recall, precision = precision)
