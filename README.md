# Disease Progression Analytics Dashboard

An interactive R Shiny dashboard for analyzing diabetes progression using longitudinal electronic health records from 130 U.S. hospitals (1999-2008).

---

## 🚀 Quick Start

### Prerequisites
- R version 4.0+
- RStudio (optional but recommended)

### Installation

Install required packages:
```r
install.packages(c(
  "shiny", "shinydashboard", "tidyverse", "plotly", "DT",
  "lme4", "lmerTest", "cmprsk", "tidymodels", "DALEXtra",
  "RColorBrewer", "janitor", "forcats"
))
```

### Run the Dashboard

```bash
cd /path/to/Healthcare-Data-Science-Project
Rscript -e "shiny::runApp('app.R')"
```

Or in RStudio: Open `app.R` → Click **Run App**

---

## 📊 Dashboard Overview

### 7 Interactive Tabs

| Tab | Description |
|-----|-------------|
| **Overview** | Project description, dataset statistics, research questions |
| **Data Exploration** | 8 visualizations + 3D cohort explorer |
| **RQ1: Glycemic Control** | HbA1c trajectories over time (LME model + 3D plot) |
| **RQ2: Competing Risks** | Complication incidence accounting for mortality |
| **RQ3: Prediction Models** | SMOTE before/after comparison (LR, RF, XGBoost) |
| **SMOTE Analysis** | Class imbalance handling & impact on metrics |
| **Summary Report** | Key findings & clinical recommendations |

---

## 📈 Key Features

✅ **3D Visualizations** - Interactive rotating plots for multi-dimensional data  
✅ **SMOTE Comparison** - Before/After class balancing analysis  
✅ **Color-Coded** - Professional Blues, Heat, and Magma palettes  
✅ **Real-Time Computation** - On-demand model fitting  
✅ **Responsive Design** - Works on desktop, tablet, mobile  

---

## 🎯 Research Questions

**RQ1: Glycemic Control Trajectories**
- How does HbA1c evolve over repeated hospitalizations?
- Finding: Increases ~0.1-0.15% per encounter (disease progression)

**RQ2: Competing Risks Analysis**
- Cumulative incidence of major complications accounting for death
- Finding: Aalen-Johansen method essential for unbiased prognosis

**RQ3: Dynamic Prediction**
- Can we predict readmission at next visit?
- Finding: XGBoost + SMOTE achieves 87% ROC-AUC with 82% sensitivity

---

## 📊 Dataset

- **Source**: Diabetes 130-US Hospitals Dataset (UCI ML Repository)
- **Time Period**: 1999-2008
- **Total Encounters**: 101,766
- **Unique Patients**: 71,490
- **Longitudinal Cohort**: 55,453 patients with ≥2 encounters (78%)

---

## 🔬 Methods

| Research Question | Method |
|-------------------|--------|
| RQ1 | Linear Mixed-Effects Model (random intercepts) |
| RQ2 | Aalen-Johansen Cumulative Incidence |
| RQ3 | SMOTE + 3 ML Models (LR, RF, XGBoost) |

**Validation**: 5-fold CV with 2 repeats (10 folds), patient-level grouping

---

## 📚 Key Findings

| Metric | Before SMOTE | After SMOTE | Change |
|--------|------------|-----------|--------|
| ROC-AUC | 0.78 | 0.87 | +9% |
| Sensitivity | 42.7% | 82.1% | +39% |
| Specificity | 96.8% | 80.7% | -16% |

**Interpretation**: SMOTE essential for clinical deployment - dramatically improves detection of readmission risk while maintaining reasonable specificity.

---

## 💡 Clinical Recommendations

1. **Monitoring**: Track HbA1c between encounters for early intervention
2. **Screening**: Use competing risks model for complication risk assessment
3. **Risk Stratification**: Deploy SMOTE-trained XGBoost for readmission prediction
4. **Personalization**: Integrate predictive scores with clinical judgment

---

## 📁 File Structure

```
├── app.R                          # Main Shiny dashboard
├── README.md                      # This file
├── Project.Rmd                    # Original analysis code
├── dataset_diabetes/
│   ├── diabetic_data.csv
│   └── IDs_mapping.csv
└── cumulative_incidence_competing_risks.png
```

---

## 🎨 Color Schemes

- **Data Exploration**: RColorBrewer Blues
- **RQ3 (Prediction)**: RColorBrewer Heat (YlOrRd)
- **SMOTE Analysis**: Viridis Magma

---

## 📖 Documentation

Comprehensive documentation available in the dashboard:
- **Overview Tab**: Detailed project description & methods
- **Each Analysis Tab**: Method explanation & interpretation
- **Summary Tab**: Clinical implications & recommendations

---

## 🔐 Privacy

All patient identifiers removed - HIPAA compliant, de-identified benchmark dataset.

---

## 📝 Citation

```
Pawar, D. (2025). Disease Progression Analytics and Dynamic Risk Prediction 
of Diabetic Complications Using Longitudinal Electronic Health Records.
```

---

## 👤 Author

**Devashree Pawar** | BIOS Project, 2025

---

## 📞 Support

For questions, refer to:
- **Dashboard**: Overview tab has detailed project description
- **Methods**: Project.Rmd file contains original analysis code
- **Interpretation**: Summary tab provides clinical context

---

**Last Updated**: May 5, 2026
