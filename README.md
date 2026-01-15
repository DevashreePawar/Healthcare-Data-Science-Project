Diabetes Readmission and Disease Progression Analysis
This project analyzes a real-world longitudinal hospital dataset to study disease progression and predict 30-day readmissions in high-risk type 2 diabetes patients. It combines statistical trajectory modeling, competing-risks survival analysis, and interpretable machine learning to provide clinical insights and actionable risk stratification.
Project Overview
Title: Dynamic 30-Day Readmission Prediction in High-Risk Diabetes Patients: A Longitudinal EHR Study
Main goals:

Understand how glycemic control evolves over repeated hospital admissions (RQ1)
Estimate the cumulative incidence of first major diabetic complications while accounting for competing mortality (RQ2)
Build and compare dynamic models that predict 30-day readmission at the next encounter after every discharge (RQ3)

Key findings (spoiler):

HbA1c modestly improves with each additional admission (~0.03% decrease per visit)
Major complications accumulate very early: ~30% by the 5th admission
XGBoost achieves best-in-class performance (ROC-AUC 0.714, PR-AUC 0.806) and identifies modifiable drivers (polypharmacy, insulin escalation, comorbidity burden)

Dataset
Source: UCI Machine Learning Repository – Diabetes 130-US Hospitals for years 1999–2008
Link: https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008

101,766 inpatient encounters
71,518 unique patients
55,453 patients (78%) with ≥2 visits → 305,298 total observations used in longitudinal analysis
Variables include demographics, admission/discharge info, up to 3 diagnosis codes (ICD-9), 24 medication indicators, lab results (HbA1c), length of stay, etc.

Citation (please include in any publication or report):
Strack, B., DeShazo, J. P., Gennings, C., et al. (2014). Impact of HbA1c measurement on hospital readmission rates: analysis of 70,000 clinical database patient records. Journal of Biomedical Informatics, 50, 203–212. https://doi.org/10.1016/j.jbi.2014.01.007
Project Structure
textproject-root/
├── Project.Rmd               # Main R Markdown report (source)
├── Healthcare presentation.pptx  # Final presentation slides
├── README.md                 # This file
├── dataset_diabetes/         # Original data files
│   ├── diabetic_data.csv
│   └── IDs_mapping.csv
└── (output files generated on knit)
    ├── Project.pdf           # Rendered report
    └── figures/              # Plots saved automatically
Installation & Dependencies
Required R packages (install via install.packages() or renv::restore() if using renv):
Rtidyverse, lubridate, lme4, lmerTest, ordinal, cmprsk, survival,
tidymodels, xgboost, vip, DALEXtra, ggplot2, dplyr, scales, patchwork, janitor,
RColorBrewer, doParallel
Recommended: run with parallel processing enabled (see code blocks using registerDoParallel()).
How to Reproduce

Clone or download the repository
Place diabetic_data.csv and IDs_mapping.csv in a subfolder dataset_diabetes/
Open Project.Rmd in RStudio
Knit to PDF (or HTML) – all chunks should run sequentially
(Optional) Run presentation slides in PowerPoint

All code is self-contained and uses relative paths.
Key Results Summary
RQ1 – Glycemic Trajectories

Linear mixed-effects model
HbA1c ↓ ~0.03% per additional admission (p = 0.004)
Modest improvement likely due to hospital-based intensification

RQ2 – Complication Onset

Aalen–Johansen competing-risks estimator
~20% by 3rd admission, ~30% by 5th, plateau ~33–35%
Rapid early onset in high-utilizers

RQ3 – Readmission Prediction

Dynamic target: next visit <30 days
10-fold grouped CV (no leakage)
XGBoost best: ROC-AUC 0.714, PR-AUC 0.806, Brier 0.202
Top SHAP drivers: # medications, # lab procedures, time in hospital, # diagnoses, insulin changes

License
MIT License – feel free to use, modify, and share for educational or research purposes.
Please cite the original dataset (Strack et al., 2014) and this repository if used.
Acknowledgments

Original dataset authors: Strack et al. (2014)
R community & package authors (tidymodels, DALEXtra, cmprsk, lme4, etc.)
Course instructors & peers in BIOS/EPID 511 for feedback and inspiration

Happy modeling!
If you find bugs or improvements, please open an issue or pull request.
— Devashree Pawar
