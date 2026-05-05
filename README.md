# Disease Progression Analytics Dashboard

**🚀 [View Live Dashboard](https://8etlvn-devashree-pawar.shinyapps.io/healthcare-data-science-project/)**

This is an interactive dashboard I built to explore how diabetes progresses over time in patients. It's built with R Shiny and uses data from over 100,000 hospital encounters across 130 US hospitals from 1999-2008.

## Getting Started

You'll need R installed first. Then grab these packages:

```r
install.packages(c(
  "shiny", "shinydashboard", "tidyverse", "plotly", "DT",
  "lme4", "lmerTest", "cmprsk", "tidymodels", "DALEXtra",
  "RColorBrewer", "janitor", "forcats"
))
```

Then just run:

```bash
cd /path/to/Healthcare-Data-Science-Project
Rscript -e "shiny::runApp('app.R')"
```

The dashboard will open in your browser.

## What's Inside

I split the analysis into 7 main sections:

**Overview** - The big picture. What this project is about, dataset details, and the main research questions.

**Data Exploration** - Just poking around the data. Charts for readmission rates, age, HbA1c levels, medications, etc. There's also a 3D visualization where you can see how age, medications, and hospital stay length interact.

**RQ1: Glycemic Control** - I fit a linear mixed-effects model to see how blood sugar control (HbA1c) changes across repeat hospitalizations. The main finding? It gets worse with each visit. There's also a 3D plot showing this from different angles.

**RQ2: Competing Risks** - This is about major complications like kidney disease, eye damage, nerve damage, and heart problems. The tricky part is that some patients die before they develop complications, so I had to use a competing risks approach to get honest numbers.

**RQ3: Prediction Models** - Can we predict if a patient will be readmitted at their next visit? I tried three models (logistic regression, random forest, XGBoost) on both unbalanced and balanced data. The balanced data (using SMOTE) performs way better.

**SMOTE Analysis** - Deep dive into class imbalance. Original data is like 85-15 (no readmission vs readmission). SMOTE synthetically creates more readmission cases to balance it out. Huge difference in model sensitivity.

**Summary** - What did we actually learn? What should clinicians do with this?

## The Data

It's the Diabetes 130-US Hospitals dataset from the UCI Machine Learning Repository. 101,766 encounters from 71,490 patients. Most patients (78%) come back multiple times, which is why we can do longitudinal analysis.

Key variables include demographics, what meds they're on, lab results (especially HbA1c), ICD-9 diagnosis codes, and whether they got readmitted.

## What I Found

**Glycemic Control Gets Worse Over Time**
- HbA1c increases about 0.1-0.15% with each hospitalization
- This suggests disease progression and probably inadequate management between visits

**Competing Risks Matter**
- About 2-5% of patients die in the hospital
- If you just ignore this and use standard survival analysis, you overestimate complication rates
- Using Aalen-Johansen instead gives you the real picture

**SMOTE Dramatically Improves Prediction**
- Before: High accuracy but misses most of the readmissions we actually care about
- After: Lower accuracy overall, but catches 82% of readmissions vs only 43% before
- XGBoost works best (ROC-AUC of 0.87)

## Technical Stuff

For RQ1 I used linear mixed-effects models to account for the fact that we have multiple visits per patient. For RQ2 I implemented Aalen-Johansen cumulative incidence estimation. For RQ3 I did 5-fold cross-validation with 2 repeats and tested it on both imbalanced and SMOTE-balanced data.

The color schemes are a mix of Blues for the exploratory stuff, Heat colors for the prediction models (to show intensity), and Magma for the SMOTE comparison.

## Running It Locally

The app loads your data from the CSV files in the `dataset_diabetes/` folder and does all computations on the fly. First load might take 30-60 seconds while it builds the models, but after that it's responsive.

## Files

- `app.R` - The actual dashboard
- `Project.Rmd` - The original analysis where I worked through all this
- `dataset_diabetes/` - The actual data files

## Notes

All patient identifiers have been stripped out, so this is a de-identified dataset. It's a good benchmark for diabetes research.

If you want to understand the details better, check out the Project.Rmd file where I documented everything as I went.

# In RStudio console
install.packages("rsconnect")
library(rsconnect)

# Authorize (get token from shinyapps.io account settings)
rsconnect::setAccountInfo(
  name = "YOUR_USERNAME",
  token = "YOUR_TOKEN", 
  secret = "YOUR_SECRET"
)

# Deploy
rsconnect::deployApp("app.R")
