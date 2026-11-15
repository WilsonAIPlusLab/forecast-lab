export interface Chapter {
  n: number; slug: string; title: string; short: string; question: string;
  part: string; accent: string; ready?: boolean; minutes?: number;
}
export const parts = [
  'Foundations', 'Classic Toolkit', 'Economic Signals', 'Machine Learning & Big Data', 'Ship It',
];
export const chapters: Chapter[] = [
  { n: 0, slug: 'first-forecast', title: 'Your First Forecast in 60 Seconds', short: 'First forecast', question: 'Can I forecast something real right now?', part: 'Foundations', accent: '#7c5cff' },
  { n: 1, slug: 'time-series-data', title: 'Time Series Data & the Forecasting Workflow', short: 'Time series data', question: 'What exactly is a forecast — and where does the data come from?', part: 'Foundations', accent: '#22d3ee' },
  { n: 2, slug: 'decomposition', title: 'Trend, Seasonality & Decomposition', short: 'Decomposition', question: 'Is the December spike real growth, or just December?', part: 'Foundations', accent: '#34d399' },
  { n: 3, slug: 'benchmarks', title: 'Benchmarks & Honest Evaluation', short: 'Benchmarks', question: 'Is our forecast actually better than a naive guess?', part: 'Foundations', accent: '#f59e0b' },
  { n: 4, slug: 'regression', title: 'Regression for Forecasting', short: 'Regression', question: 'How much do drivers move demand — and what if gas hits $5?', part: 'Classic Toolkit', accent: '#f472b6' },
  { n: 5, slug: 'nonlinear-regression', title: 'Nonlinear Regression: Logistic & Poisson', short: 'Logistic & Poisson', question: 'Will this customer say yes — and how many bikes will we rent tomorrow?', part: 'Classic Toolkit', accent: '#bef264' },
  { n: 6, slug: 'exponential-smoothing', title: 'Exponential Smoothing: The Industry Workhorse', short: 'Exponential smoothing', question: 'How do I forecast 500 products every Monday morning?', part: 'Classic Toolkit', accent: '#60a5fa' },
  { n: 7, slug: 'arima', title: 'Stationarity & ARIMA', short: 'ARIMA', question: 'Where is inflation heading over the next 12 months?', part: 'Classic Toolkit', accent: '#a78bfa' },
  { n: 8, slug: 'dynamic-regression', title: 'Leading Indicators & Dynamic Regression', short: 'Leading indicators', question: 'Do jobless claims tell us where jobs are going?', part: 'Economic Signals', accent: '#fb923c' },
  { n: 9, slug: 'recession-probability', title: 'Binary Outcomes: Recession Probability', short: 'Recession probability', question: 'What is the chance of a recession in the next 12 months?', part: 'Economic Signals', accent: '#f87171' },
  { n: 10, slug: 'var', title: 'VAR, Granger Causality & Impulse Responses', short: 'VAR & impulse responses', question: 'If rates jump, what happens to jobs and prices — and when?', part: 'Economic Signals', accent: '#2dd4bf' },
  { n: 11, slug: 'uncertainty', title: 'Uncertainty: Intervals, Combination & Conformal', short: 'Uncertainty', question: 'How much safety stock should we hold?', part: 'Economic Signals', accent: '#facc15' },
  { n: 12, slug: 'random-forests', title: 'Machine Learning I: Features & Random Forests', short: 'Random forests', question: 'Can machine learning beat our statistical models?', part: 'Machine Learning & Big Data', accent: '#4ade80' },
  { n: 13, slug: 'boosting-shap', title: 'Machine Learning II: Gradient Boosting & SHAP', short: 'Boosting & SHAP', question: 'Can I explain an ML forecast to my manager?', part: 'Machine Learning & Big Data', accent: '#e879f9' },
  { n: 14, slug: 'nowcasting', title: 'Big Data, Many Series & Nowcasting', short: 'Nowcasting', question: 'What is the economy doing this month — before the data are out?', part: 'Machine Learning & Big Data', accent: '#38bdf8' },
  { n: 15, slug: 'forecast-studio', title: 'The Forecast Studio', short: 'Forecast Studio', question: 'Can I ship a forecast an employer would actually use?', part: 'Ship It', accent: '#c084fc' },
];
export const bySlug = (s: string) => chapters.find((c) => c.slug === s)!;
