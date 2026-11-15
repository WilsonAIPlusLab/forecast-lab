# The marketing team can afford to call only the top 20% of the next list.
# 1. Fit the logit on the training clients
# blank: the statsmodels formula function for logistic regression
logit = smf.______("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)

# 2. Predict a PROBABILITY of "yes" for every test client
# blank: the fitted model's method that returns predictions for new data
p = logit.______(test)

# 3. Call the 20% of clients with the highest probabilities
call = p >= p.quantile(0.80)               # True for clients at or above the 80th percentile

# 4. Recall: share of all subscribers that the calls reach
#    Precision: share of calls that end in a subscription
# blank: how many test clients really subscribed (called or not)?
recall = (call & (test["yes"] == 1)).sum() / ______
precision = (call & (test["yes"] == 1)).sum() / call.sum()   # subscribers reached / calls made
print({"recall": recall, "precision": precision})
