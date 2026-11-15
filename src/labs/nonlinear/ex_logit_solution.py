# The marketing team can afford to call only the top 20% of the next list.
# 1. Fit the logit on the training clients
logit = smf.logit("yes ~ age + contact + campaign + poutcome + euribor3m", train).fit(disp=0)

# 2. Predict a PROBABILITY of "yes" for every test client
p = logit.predict(test)

# 3. Call the 20% of clients with the highest probabilities
call = p >= p.quantile(0.80)

# 4. Recall: share of all subscribers that the calls reach
#    Precision: share of calls that end in a subscription
recall = (call & (test["yes"] == 1)).sum() / (test["yes"] == 1).sum()
precision = (call & (test["yes"] == 1)).sum() / call.sum()
print({"recall": recall, "precision": precision})
