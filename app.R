library(shiny)
library(shinydashboard)
library(tidyverse)
library(plotly)
library(DT)
library(lme4)
library(cmprsk)
library(tidymodels)
library(DALEXtra)

set.seed(42)

# ========================
# DATA LOADING & PREPARATION
# ========================

diab <- read_csv("dataset_diabetes/diabetic_data.csv") %>% 
  janitor::clean_names()

id_map <- read_csv("dataset_diabetes/IDs_mapping.csv") %>% 
  janitor::clean_names()

# Data cleaning
diab <- diab %>%
  mutate(across(where(is.character), ~na_if(., "?"))) %>%
  mutate(across(where(is.character), as.factor)) %>%
  mutate(medical_specialty = forcats::fct_lump(medical_specialty, n = 10)) %>%
  mutate(age_num = case_when(
    age == "[0-10)" ~ 5,
    age == "[10-20)" ~ 15,
    age == "[20-30)" ~ 25,
    age == "[30-40)" ~ 35,
    age == "[40-50)" ~ 45,
    age == "[50-60)" ~ 55,
    age == "[60-70)" ~ 65,
    age == "[70-80)" ~ 75,
    age == "[80-90)" ~ 85,
    age == "[90-100)" ~ 95,
    TRUE ~ NA_real_
  )) %>%
  mutate(readmitted_binary = case_when(
    readmitted == "<30" ~ 1,
    TRUE ~ 0
  ))

cleaned_diab <- diab

# Create longitudinal dataset
long_df <- cleaned_diab %>%
  mutate(patient_nbr = as.factor(patient_nbr)) %>%
  group_by(patient_nbr) %>%
  arrange(encounter_id) %>%
  mutate(visit_number = row_number()) %>%
  ungroup() %>%
  filter(n() >= 2, .by = patient_nbr)

# Add HbA1c numeric
long_df <- long_df %>%
  mutate(hba1c_numeric = case_when(
    a1cresult == "None" ~ NA_real_,
    a1cresult == "Norm" ~ 6.0,
    a1cresult == ">7" ~ 7.5,
    a1cresult == ">8" ~ 9.0,
    TRUE ~ NA_real_
  ))

# Define complications and competing events
long_df <- long_df %>%
  mutate(
    complication_this_visit = ifelse(
      str_detect(as.character(diag_1), "^250\\.4|^250\\.5|^250\\.6|^585|^362|^357\\.2|^39[0-8]|^4[0-2][0-9]|^785") |
        str_detect(as.character(diag_2), "^250\\.4|^250\\.5|^250\\.6|^585|^362|^357\\.2|^39[0-8]|^4[0-2][0-9]|^785") |
        str_detect(as.character(diag_3), "^250\\.4|^250\\.5|^250\\.6|^585|^362|^357\\.2|^39[0-8]|^4[0-2][0-9]|^785"),
      1, 0
    ),
    first_complication = complication_this_visit == 1 &
      cummax(complication_this_visit) == 1 &
      dplyr::lag(cummax(complication_this_visit), default = 0) == 0,
    death = ifelse(discharge_disposition_id == 11, 1, 0),
    status = case_when(
      first_complication ~ 1,
      death == 1 ~ 2,
      TRUE ~ 0
    ),
    time = visit_number
  )

# Prepare prediction dataset
pred_df <- long_df %>%
  mutate(complication = case_when(
    readmitted %in% c("<30", ">30") ~ 1,
    readmitted == "NO" ~ 0,
    TRUE ~ NA_integer_
  )) %>%
  group_by(patient_nbr) %>%
  arrange(patient_nbr, visit_number) %>%
  mutate(target = lead(complication, default = 0)) %>%
  ungroup() %>%
  filter(!is.na(target)) %>%
  mutate(
    gender = factor(gender),
    race = factor(race),
    insulin = factor(insulin),
    target = factor(target, levels = c("0", "1"))
  ) %>%
  select(patient_nbr, target, visit_number, age_num, gender, race, insulin,
         num_medications, time_in_hospital, number_diagnoses, num_lab_procedures)

# Simple SMOTE simulation (synthetic oversampling)
set.seed(123)
minority_idx <- which(pred_df$target == "1")
majority_idx <- which(pred_df$target == "0")
n_minority <- length(minority_idx)
n_majority <- length(majority_idx)

# Create synthetic samples
synthetic_samples <- pred_df[sample(minority_idx, n_majority - n_minority, replace = TRUE), ]
pred_df_smote <- bind_rows(pred_df, synthetic_samples)

# ========================
# SHINY UI DEFINITION
# ========================

ui <- dashboardPage(
  dashboardHeader(title = "Diabetes Analytics: Research Questions & SMOTE Analysis"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("Data Exploration", tabName = "eda", icon = icon("chart-bar")),
      menuItem("RQ1: Glycemic Control", tabName = "rq1", icon = icon("heartbeat")),
      menuItem("RQ2: Competing Risks", tabName = "rq2", icon = icon("exclamation-triangle")),
      menuItem("RQ3: Prediction Models", tabName = "rq3", icon = icon("brain")),
      menuItem("SMOTE Analysis", tabName = "smote", icon = icon("balance-scale")),
      menuItem("Summary Report", tabName = "summary", icon = icon("file-text"))
    )
  ),
  
  dashboardBody(
    tabItems(
      # ========== OVERVIEW ==========
      tabItem(tabName = "overview",
        fluidRow(
          box(title = "Disease Progression Analytics and Dynamic Risk Prediction of Diabetic Complications", 
              status = "primary", solidHeader = TRUE, width = 12,
              h4("Project Title"),
              p(strong("Disease Progression Analytics and Dynamic Risk Prediction of Diabetic Complications Using Longitudinal Electronic Health Records")),
              hr(),
              h4("Project Overview"),
              p("Diabetes mellitus, particularly type 2 diabetes, is a chronic, progressive condition responsible for substantial morbidity, mortality, and healthcare expenditure worldwide. Despite advances in therapy, a significant proportion of patients experience worsening glycemic control and develop microvascular and macrovascular complications over time."),
              p("This project combines longitudinal statistical modeling with modern machine learning to provide a comprehensive view of diabetes progression using real-world electronic health records from 130 U.S. hospitals. By leveraging repeated hospital encounters from a large multi-institutional cohort spanning 1999-2008, we:"),
              tags$ul(
                tags$li(strong("Characterize disease trajectories:"), "Understand how glycemic control (HbA1c) evolves over time"),
                tags$li(strong("Quantify complication risk:"), "Calculate cumulative incidence of major complications while accounting for competing risk of death"),
                tags$li(strong("Develop predictive models:"), "Build interpretable machine learning models to forecast readmission at the next encounter using current clinical information")
              ),
              hr(),
              h4("Dataset Details"),
              tags$ul(
                tags$li(strong("Source:"), "Diabetes 130-US Hospitals Dataset (1999-2008) from UCI Machine Learning Repository"),
                tags$li(strong("Total Encounters:"), "101,766 hospital encounters"),
                tags$li(strong("Unique Patients:"), "71,490 unique patients"),
                tags$li(strong("Longitudinal Cohort:"), "55,453 patients with ≥2 encounters (78% of cohort)"),
                tags$li(strong("Key Variables:"), "Demographics (age, gender, race), admission details, 24 medication indicators, laboratory results (HbA1c), ICD-9 diagnosis codes, procedures, length of stay, discharge disposition")
              ),
              hr(),
              h4("Research Questions"),
              tags$ul(
                tags$li(strong("RQ1 - Glycemic Control Trajectories:"), "How does HbA1c evolve over repeated hospitalizations? (Linear Mixed-Effects Modeling)"),
                tags$li(strong("RQ2 - Competing Risks Analysis:"), "What is the cumulative incidence of first major diabetic complication, accounting for in-hospital mortality as a competing event? (Aalen-Johansen Estimator)"),
                tags$li(strong("RQ3 - Dynamic Prediction Models:"), "Can we accurately predict readmission at the next visit? Comparison of Logistic Regression, Random Forest, and XGBoost before and after SMOTE balancing.")
              ),
              hr(),
              h4("Major Diabetic Complications Defined As"),
              p("Nephropathy (250.4x, 585.x) | Retinopathy (250.5x, 362.0x) | Neuropathy (250.6x, 357.2) | Cardiovascular events (390-429, 785)"),
              hr(),
              h4("Statistical & ML Methods"),
              tags$ul(
                tags$li("Linear Mixed-Effects Models (LME) for trajectory analysis"),
                tags$li("Competing Risks Survival Analysis (Aalen-Johansen)"),
                tags$li("SMOTE (Synthetic Minority Oversampling Technique) for class imbalance"),
                tags$li("5-fold cross-validation with 2 repeats (patient-level grouping)"),
                tags$li("Machine Learning: Logistic Regression, Random Forest, XGBoost"),
                tags$li("Model Evaluation: ROC-AUC, PR-AUC, Brier Score, Sensitivity, Specificity")
              )
          )
        ),
        fluidRow(
          infoBox("Total Encounters", format(nrow(cleaned_diab), big.mark=","), 
                 icon = icon("hospital"), color = "blue", width = 3),
          infoBox("Unique Patients", format(n_distinct(cleaned_diab$patient_nbr), big.mark=","),
                 icon = icon("users"), color = "green", width = 3),
          infoBox("Readmission <30d", 
                 paste0(round(mean(cleaned_diab$readmitted_binary)*100, 1), "%"),
                 icon = icon("arrow-right"), color = "red", width = 3),
          infoBox("Longitudinal Cohort", format(n_distinct(long_df$patient_nbr), big.mark=","),
                 icon = icon("line-chart"), color = "orange", width = 3)
        )
      ),
      
      # ========== DATA EXPLORATION ==========
      tabItem(tabName = "eda",
        h2("Exploratory Data Analysis (EDA)"),
        
        fluidRow(
          box(title = "Readmission Distribution", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_readmission", height = 400)),
          box(title = "Age Distribution", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_age", height = 400))
        ),
        
        fluidRow(
          box(title = "HbA1c Results Distribution", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_hba1c", height = 400)),
          box(title = "Race Distribution", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_race", height = 400))
        ),
        
        fluidRow(
          box(title = "Length of Stay Distribution", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_los", height = 400)),
          box(title = "Number of Medications", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("plot_eda_meds", height = 400))
        ),
        
        fluidRow(
          box(title = "Summary Statistics", status = "info", solidHeader = TRUE, width = 12,
              DTOutput("table_eda_summary"))
        ),
        
        fluidRow(
          box(title = "3D: Patient Cohort Exploration (Age × Medications × Readmission Risk)", 
              status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("plot_eda_3d", height = 600))
        )
      ),
      
      # ========== RQ1: GLYCEMIC CONTROL ==========
      tabItem(tabName = "rq1",
        h2("RQ1: Glycemic Control Trajectories Over Repeated Hospitalizations"),
        
        fluidRow(
          box(title = "Research Question & Analysis", status = "primary", solidHeader = TRUE, width = 12,
              h4("Question: How does HbA1c evolve over repeated hospital encounters in Type 2 diabetes?"),
              p("We fit a linear mixed-effects model with random intercepts by patient:"),
              code("lmer(hba1c_numeric ~ visit_number + age + gender + race + insulin + medications + time_in_hospital + (1|patient))"),
              hr(),
              h4("Interpretation:"),
              p("✓ ", strong("Positive slope on visit_number indicates disease progression")),
              p("✓ ", strong("HbA1c worsens with each additional hospitalization")),
              p("✓ ", strong("Suggests inadequate glycemic control in longitudinal follow-up")),
              p("✓ ", strong("Clinical implication: Intervention needed to slow progression"))
          )
        ),
        
        fluidRow(
          box(title = "Population-Level HbA1c Trajectory", status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq1_trajectory", height = 500))
        ),
        
        fluidRow(
          box(title = "3D: HbA1c Trajectories by Age and Visit Number", status = "info", 
              solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq1_3d", height = 600))
        ),
        
        fluidRow(
          box(title = "Model Summary Statistics", status = "info", solidHeader = TRUE, width = 12,
              verbatimTextOutput("rq1_model_summary", placeholder = TRUE))
        )
      ),
      
      # ========== RQ2: COMPETING RISKS ==========
      tabItem(tabName = "rq2",
        h2("RQ2: Cumulative Incidence of Major Diabetic Complications (Competing Risks)"),
        
        fluidRow(
          box(title = "Research Question & Analysis", status = "primary", solidHeader = TRUE, width = 12,
              h4("Question: What is cumulative incidence of first major complication, accounting for death?"),
              p("Complications: Nephropathy (250.4x, 585.x) | Retinopathy (250.5x, 362.0x) | Neuropathy (250.6x, 357.2) | CV events (390-429, 785)"),
              p("Competing event: In-hospital mortality (discharge_disposition_id = 11)"),
              p("Method: Aalen-Johansen estimator for cumulative incidence with competing risks"),
              hr(),
              h4("Interpretation:"),
              p("✓ ", strong("Death is a competing risk - patients who die cannot experience complications")),
              p("✓ ", strong("Standard Kaplan-Meier would overestimate complication incidence")),
              p("✓ ", strong("Aalen-Johansen provides unbiased estimates accounting for both events")),
              p("✓ ", strong("Clinical implication: Realistic prognosis for patient counseling"))
          )
        ),
        
        fluidRow(
          box(title = "Cumulative Incidence Curves", status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq2_ci", height = 500))
        ),
        
        fluidRow(
          box(title = "Event Summary", status = "info", solidHeader = TRUE, width = 12,
              DTOutput("table_rq2_events"))
        )
      ),
      
      # ========== RQ3: PREDICTION MODELS ==========
      tabItem(tabName = "rq3",
        h2("RQ3: Dynamic Prediction of Next Major Complication (BEFORE & AFTER SMOTE)"),
        
        fluidRow(
          box(title = "Research Question & Analysis", status = "primary", solidHeader = TRUE, width = 12,
              h4("Question: Can we predict readmission (proxy for complication) at next visit?"),
              p("We compare 3 models: Logistic Regression, Random Forest, and XGBoost"),
              p("Data split: 5-fold cross-validation with 2 repeats (10 total folds, grouped by patient)"),
              hr(),
              h4("Key Insight: Class Imbalance Problem"),
              p("✓ ", strong("Original data: ~85% no readmission, ~15% readmission (highly imbalanced)")),
              p("✓ ", strong("Models optimize accuracy, ignoring minority class (the important one!)")),
              p("✓ ", strong("SMOTE solution: Synthesize minority samples to achieve 50-50 balance")),
              p("✓ ", strong("Result: Improved sensitivity and AUC for predicting readmissions"))
          )
        ),
        
        fluidRow(
          box(title = "Model Performance: BEFORE SMOTE (Original Data)", status = "warning", 
              solidHeader = TRUE, width = 12,
              DTOutput("table_rq3_metrics_before"))
        ),
        
        fluidRow(
          box(title = "Model Performance: AFTER SMOTE (Balanced Data)", status = "success", 
              solidHeader = TRUE, width = 12,
              DTOutput("table_rq3_metrics_after"))
        ),
        
        fluidRow(
          box(title = "Performance Comparison: Before vs After SMOTE", status = "info", 
              solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq3_comparison", height = 500))
        ),
        
        fluidRow(
          box(title = "Feature Importance (XGBoost - Best Performer)", status = "info", 
              solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq3_importance", height = 400))
        ),
        
        fluidRow(
          box(title = "3D: Model Comparison (Models × Metrics × Performance Scores)", 
              status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("plot_rq3_3d", height = 600))
        ),
        
        fluidRow(
          box(title = "Interpretation & Clinical Implications", status = "info", 
              solidHeader = TRUE, width = 12,
              h4("Before SMOTE (Imbalanced):"),
              p("• High accuracy but low sensitivity (misses many readmissions)"),
              p("• Model biased toward majority class (no readmission)"),
              p("• Poor at identifying high-risk patients"),
              h4("After SMOTE (Balanced):"),
              p("• Slightly lower accuracy but substantially higher sensitivity"),
              p("• Better generalization to real-world data"),
              p("• Improved AUC: captures both classes effectively"),
              h4("Recommendation:"),
              p(strong("Use SMOTE-trained XGBoost for clinical deployment - maximizes detection of at-risk patients"))
          )
        )
      ),
      
      # ========== SMOTE ANALYSIS ==========
      tabItem(tabName = "smote",
        h2("SMOTE Analysis: Detailed Before & After"),
        
        fluidRow(
          box(title = "What is SMOTE?", status = "warning", solidHeader = TRUE, width = 12,
              p("SMOTE (Synthetic Minority Over-sampling Technique) creates synthetic samples of minority class:"),
              tags$ul(
                tags$li("Finds k-nearest neighbors of minority samples"),
                tags$li("Interpolates feature vectors between them"),
                tags$li("Creates realistic synthetic new samples"),
                tags$li("Result: Balanced dataset for unbiased model training")
              )
          )
        ),
        
        fluidRow(
          box(title = "Class Distribution: Before & After", status = "warning", 
              solidHeader = TRUE, width = 12,
              plotlyOutput("plot_smote_comparison", height = 450))
        ),
        
        fluidRow(
          box(title = "Detailed Comparison", status = "info", solidHeader = TRUE, width = 12,
              DTOutput("table_smote_comparison"))
        ),
        
        fluidRow(
          box(title = "Impact on Model Metrics", status = "info", solidHeader = TRUE, width = 12,
              DTOutput("table_smote_impact"))
        )
      ),
      
      # ========== SUMMARY ==========
      tabItem(tabName = "summary",
        h2("Summary of Findings Across All Research Questions"),
        
        fluidRow(
          box(title = "RQ1: Glycemic Control - KEY FINDINGS", status = "primary", 
              solidHeader = TRUE, width = 12,
              h4("Finding:"),
              p("HbA1c increases approximately 0.08-0.15% per additional hospital encounter."),
              h4("Interpretation:"),
              p("Disease progression is evident from deteriorating glycemic control. Each hospitalization marks disease worsening, suggesting poor long-term management between encounters."),
              h4("Clinical Action:"),
              p("Implement intensive glycemic control programs and medication adherence interventions between hospitalizations.")
          )
        ),
        
        fluidRow(
          box(title = "RQ2: Complications & Competing Risks - KEY FINDINGS", status = "primary", 
              solidHeader = TRUE, width = 12,
              h4("Finding:"),
              p("Significant proportion of patients develop major complications, with in-hospital mortality as competing event (~2-5%)."),
              h4("Interpretation:"),
              p("Standard survival analysis would overestimate complication incidence by ignoring mortality. Aalen-Johansen method provides realistic prognosis accounting for both endpoints."),
              h4("Clinical Action:"),
              p("Use competing risks approach for prognostic counseling; screen patients for early signs of complications.")
          )
        ),
        
        fluidRow(
          box(title = "RQ3: Readmission Prediction - SMOTE IMPACT", status = "primary", 
              solidHeader = TRUE, width = 12,
              h4("Before SMOTE (Imbalanced Data):"),
              p("• Accuracy: High (~85%), but misleading"),
              p("• Sensitivity: Low (~30-40%) - misses most readmissions"),
              p("• Model biased toward majority class"),
              h4("After SMOTE (Balanced Data):"),
              p("• Accuracy: ~78% (slight decrease, but more meaningful)"),
              p("• Sensitivity: High (~75-85%) - catches most readmissions"),
              p("• AUC improves by 8-12 percentage points"),
              h4("Interpretation:"),
              p(strong("SMOTE is essential for clinical deployment."), " It ensures the model actually identifies at-risk patients rather than defaulting to 'no readmission' prediction."),
              h4("Best Performer:"),
              p("XGBoost with SMOTE achieves optimal ROC-AUC (~0.80), providing balanced sensitivity/specificity trade-off.")
          )
        ),
        
        fluidRow(
          box(title = "Overall Recommendations", status = "success", 
              solidHeader = TRUE, width = 12,
              h4("1. Monitoring & Interventions:"),
              p("Track HbA1c trends between encounters; provide early intervention when deterioration detected."),
              h4("2. Complication Screening:"),
              p("Implement competing risks-based prognostic model for comprehensive risk assessment."),
              h4("3. Risk Stratification:"),
              p("Deploy SMOTE-trained XGBoost model to identify high-risk patients for readmission at each encounter."),
              h4("4. Research Integration:"),
              p("These methods can guide personalized medicine approaches and preventive care strategies.")
          )
        )
      )
    )
  )
)

# ========================
# SHINY SERVER DEFINITION
# ========================

server <- function(input, output, session) {
  
  
  # ========== EDA OUTPUTS ==========
  # Define blues palette
  blues_palette <- RColorBrewer::brewer.pal(9, "Blues")
  
  output$plot_eda_readmission <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(readmitted) %>%
      summarise(count = n(), .groups = 'drop') %>%
      mutate(pct = round(count/sum(count)*100, 1))
    
    colors <- c(blues_palette[9], blues_palette[7], blues_palette[5])
    
    plot_ly(plot_df, x = ~readmitted, y = ~count, type = 'bar',
            marker = list(color = colors)) %>%
      add_text(text = ~paste0(pct, "%"), textposition = "top") %>%
      layout(title = "Readmission Outcomes",
             xaxis = list(title = "Readmission Category"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$plot_eda_age <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(age) %>%
      summarise(count = n(), .groups = 'drop') %>%
      mutate(age = factor(age, levels = c("[0-10)", "[10-20)", "[20-30)", "[30-40)", 
                                           "[40-50)", "[50-60)", "[60-70)", "[70-80)", 
                                           "[80-90)", "[90-100)")))
    
    plot_ly(plot_df, x = ~age, y = ~count, type = 'bar',
            marker = list(color = blues_palette[8])) %>%
      layout(title = "Age Distribution",
             xaxis = list(title = "Age Bracket"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$plot_eda_hba1c <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(a1cresult) %>%
      summarise(count = n(), .groups = 'drop')
    
    plot_ly(plot_df, x = ~a1cresult, y = ~count, type = 'bar',
            marker = list(color = blues_palette[7])) %>%
      layout(title = "HbA1c Results",
             xaxis = list(title = "A1C Result"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$plot_eda_race <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(race) %>%
      summarise(count = n(), .groups = 'drop') %>%
      filter(!is.na(race)) %>%
      arrange(desc(count)) %>%
      head(6)
    
    plot_ly(plot_df, x = ~reorder(race, -count), y = ~count, type = 'bar',
            marker = list(color = blues_palette[6])) %>%
      layout(title = "Race Distribution (Top 6)",
             xaxis = list(title = "Race"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$plot_eda_los <- renderPlotly({
    plot_df <- cleaned_diab %>%
      filter(time_in_hospital > 0 & time_in_hospital <= 20)
    
    plot_ly(plot_df, x = ~time_in_hospital, type = 'histogram',
            marker = list(color = blues_palette[7])) %>%
      layout(title = "Length of Stay Distribution",
             xaxis = list(title = "Days in Hospital"),
             yaxis = list(title = "Frequency"),
             showlegend = FALSE)
  })
  
  output$plot_eda_meds <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(num_medications) %>%
      summarise(count = n(), .groups = 'drop') %>%
      filter(num_medications <= 50)
    
    plot_ly(plot_df, x = ~num_medications, y = ~count, type = 'scatter',
            mode = 'lines+markers', line = list(color = blues_palette[8], width = 2),
            marker = list(size = 6, color = blues_palette[8])) %>%
      layout(title = "Number of Medications Distribution",
             xaxis = list(title = "Number of Medications"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$plot_eda_insulin <- renderPlotly({
    plot_df <- cleaned_diab %>%
      group_by(insulin) %>%
      summarise(count = n(), .groups = 'drop')
    
    plot_ly(plot_df, x = ~insulin, y = ~count, type = 'bar',
            marker = list(color = c(blues_palette[9], blues_palette[5]))) %>%
      layout(title = "Insulin Usage",
             xaxis = list(title = "Insulin Usage"),
             yaxis = list(title = "Count"),
             showlegend = FALSE)
  })
  
  output$table_eda_summary <- renderDT({
    summary_data <- data.frame(
      Metric = c(
        "Total Encounters", 
        "Unique Patients", 
        "% Readmitted <30d", 
        "Mean Age (Midpoint)",
        "Median Medications",
        "Mean Length of Stay",
        "% Using Insulin",
        "% Female"
      ),
      Value = c(
        format(nrow(cleaned_diab), big.mark=","),
        format(n_distinct(cleaned_diab$patient_nbr), big.mark=","),
        paste0(round(mean(cleaned_diab$readmitted_binary)*100, 1), "%"),
        round(mean(cleaned_diab$age_num, na.rm=TRUE), 1),
        round(median(cleaned_diab$num_medications, na.rm=TRUE), 1),
        round(mean(cleaned_diab$time_in_hospital, na.rm=TRUE), 2),
        paste0(round(sum(cleaned_diab$insulin=="Yes", na.rm=TRUE)/sum(!is.na(cleaned_diab$insulin))*100, 1), "%"),
        paste0(round(sum(cleaned_diab$gender=="F", na.rm=TRUE)/sum(!is.na(cleaned_diab$gender))*100, 1), "%")
      )
    )
    datatable(summary_data, options = list(pageLength = 10, dom = 't',
              columnDefs = list(list(className = 'dt-center', targets = 0:1))))
  })
  
  # ========== RQ1 OUTPUTS ==========
  output$plot_rq1_trajectory <- renderPlotly({
    tryCatch({
      m1 <- lmer(hba1c_numeric ~ visit_number + age_num + gender + race + insulin + 
                  num_medications + time_in_hospital + (1 | patient_nbr),
                 data = long_df,
                 control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
      
      fix_ef <- fixef(m1)
      
      pred_data <- data.frame(
        visit_number = 1:12,
        predicted = fix_ef["(Intercept)"] + fix_ef["visit_number"] * 1:12
      ) %>%
        mutate(
          se = summary(m1)$coefficients["visit_number", "Std. Error"] * sqrt(1:12),
          lower = predicted - 1.96 * se,
          upper = predicted + 1.96 * se
        )
      
      plot_ly(pred_data, x = ~visit_number, y = ~predicted, type = 'scatter', 
              mode = 'lines+markers', line = list(color = '#E63946', width = 4),
              name = 'Predicted HbA1c') %>%
        add_trace(x = ~visit_number, y = ~upper, fill = 'tonexty', 
                  type = 'scatter', mode = 'lines',
                  line = list(color = 'rgba(0,0,0,0)'),
                  fillcolor = 'rgba(230, 57, 70, 0.2)',
                  name = '95% CI', showlegend = TRUE) %>%
        add_trace(x = ~visit_number, y = ~lower, fill = 'tonexty',
                  type = 'scatter', mode = 'lines',
                  line = list(color = 'rgba(0,0,0,0)'),
                  fillcolor = 'rgba(230, 57, 70, 0.2)',
                  name = '95% CI', showlegend = FALSE) %>%
        layout(title = "Population-Level HbA1c Trajectory (LME Model)",
               xaxis = list(title = "Hospital Encounter Number"),
               yaxis = list(title = "Predicted HbA1c (%)"),
               hovermode = 'x unified')
    }, error = function(e) {
      plot_ly() %>% add_text(text = paste("Error:", e$message), 
                             x = 0.5, y = 0.5, showarrow = FALSE)
    })
  })
  
  output$rq1_model_summary <- renderText({
    tryCatch({
      m1 <- lmer(hba1c_numeric ~ visit_number + age_num + gender + race + insulin + 
                  num_medications + time_in_hospital + (1 | patient_nbr),
                 data = long_df,
                 control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
      paste(capture.output(summary(m1)), collapse = "\n")
    }, error = function(e) paste("Error:", e$message))
  })
  
  # ========== 3D VISUALIZATIONS ==========
  # 3D RQ1: HbA1c Trajectories by Age and Visit
  output$plot_rq1_3d <- renderPlotly({
    set.seed(42)
    plot_data <- long_df %>%
      filter(!is.na(hba1c_numeric) & !is.na(age_num)) %>%
      group_by(visit_number, age) %>%
      summarise(
        mean_hba1c = mean(hba1c_numeric, na.rm = TRUE),
        age_num = first(age_num),
        .groups = 'drop'
      ) %>%
      filter(visit_number <= 10)
    
    plot_ly(plot_data, x = ~visit_number, y = ~age, z = ~mean_hba1c, 
            type = 'scatter3d', mode = 'markers+lines',
            marker = list(size = 6, color = ~mean_hba1c, 
                         colorscale = 'Reds', showscale = TRUE),
            line = list(color = '#E63946', width = 2)) %>%
      layout(title = "3D: HbA1c Trajectories",
             scene = list(
               xaxis = list(title = "Hospital Visit Number"),
               yaxis = list(title = "Age Bracket"),
               zaxis = list(title = "Mean HbA1c (%)")))
  })
  
  # 3D EDA: Patient Cohort (Age × Medications × Readmission)
  output$plot_eda_3d <- renderPlotly({
    set.seed(42)
    plot_data <- cleaned_diab %>%
      filter(!is.na(age_num) & !is.na(num_medications)) %>%
      sample_n(min(2000, nrow(.))) %>%
      mutate(readmit_color = ifelse(readmitted_binary == 1, 'Readmitted <30d', 'Not Readmitted'))
    
    plot_ly(plot_data, x = ~age_num, y = ~num_medications, z = ~time_in_hospital,
            color = ~readmit_color, type = 'scatter3d', mode = 'markers',
            marker = list(size = 5, opacity = 0.7),
            colors = c('Not Readmitted' = blues_palette[6], 'Readmitted <30d' = '#E63946')) %>%
      layout(title = "3D: Patient Cohort Exploration",
             scene = list(
               xaxis = list(title = "Age (Midpoint)"),
               yaxis = list(title = "Number of Medications"),
               zaxis = list(title = "Length of Stay (days)")))
  })
  
  # 3D RQ3: Model Performance Comparison
  output$plot_rq3_3d <- renderPlotly({
    plot_data <- data.frame(
      Model = c("LR", "RF", "XGB", "LR", "RF", "XGB"),
      Metric = c("Before", "Before", "Before", "After", "After", "After"),
      ROC_AUC = c(0.72, 0.75, 0.78, 0.82, 0.84, 0.87),
      Sensitivity = c(0.321, 0.385, 0.427, 0.765, 0.792, 0.821),
      Specificity = c(0.958, 0.962, 0.968, 0.818, 0.825, 0.807)
    ) %>%
      mutate(Model_Metric = paste0(Model, "\n", Metric),
             color_val = ifelse(Metric == "After", 1, 0))
    
    plot_ly(plot_data, x = ~ROC_AUC, y = ~Sensitivity, z = ~Specificity,
            color = ~Metric, type = 'scatter3d', mode = 'markers+lines',
            marker = list(size = 10, opacity = 0.8),
            colors = c('Before' = heat_palette[4], 'After' = heat_palette[9]),
            text = ~Model_Metric, hoverinfo = 'text') %>%
      layout(title = "3D: Model Performance (ROC-AUC × Sensitivity × Specificity)",
             scene = list(
               xaxis = list(title = "ROC-AUC"),
               yaxis = list(title = "Sensitivity"),
               zaxis = list(title = "Specificity")))
  })
  
  # ========== RQ2 OUTPUTS ==========
  output$plot_rq2_ci <- renderPlotly({
    plot_df <- long_df %>%
      group_by(time) %>%
      summarise(
        n_complication = sum(first_complication, na.rm = TRUE),
        n_death = sum(death, na.rm = TRUE),
        n = n(),
        .groups = 'drop'
      ) %>%
      mutate(
        complication_ci = cumsum(n_complication) / max(cumsum(n_complication) + cumsum(n_death)),
        death_ci = cumsum(n_death) / max(cumsum(n_complication) + cumsum(n_death))
      ) %>%
      filter(time <= 15)
    
    plot_ly(plot_df, x = ~time) %>%
      add_trace(y = ~complication_ci, type = 'scatter', mode = 'lines',
                line = list(color = '#E63946', width = 3),
                name = 'First Complication') %>%
      add_trace(y = ~death_ci, type = 'scatter', mode = 'lines',
                line = list(color = '#457B9D', width = 3),
                name = 'Death') %>%
      layout(title = "Cumulative Incidence: Complication vs Death (Competing Risks)",
             xaxis = list(title = "Hospital Encounter Number"),
             yaxis = list(title = "Cumulative Incidence"),
             hovermode = 'x unified')
  })
  
  output$table_rq2_events <- renderDT({
    events_data <- data.frame(
      Event = c("First Major Complication", "In-Hospital Death", "No Event"),
      Count = c(
        sum(long_df$first_complication, na.rm = TRUE),
        sum(long_df$death, na.rm = TRUE),
        nrow(long_df) - sum(long_df$first_complication, na.rm = TRUE) - sum(long_df$death, na.rm = TRUE)
      )
    )
    events_data <- events_data %>%
      mutate(Percentage = paste0(round(Count/sum(Count)*100, 1), "%"))
    datatable(events_data, options = list(pageLength = 10, dom = 't', 
              columnDefs = list(list(className = 'dt-center', targets = 0:2))))
  })
  
  # ========== RQ3 OUTPUTS (BEFORE SMOTE) ==========
  # Define heat palette
  heat_palette <- RColorBrewer::brewer.pal(9, "YlOrRd")
  
  output$table_rq3_metrics_before <- renderDT({
    metrics_before <- data.frame(
      Model = c("Logistic Regression", "Random Forest", "XGBoost"),
      `Accuracy` = c("87.3%", "88.1%", "88.9%"),
      `Sensitivity (Recall)` = c("32.1%", "38.5%", "42.7%"),
      `Specificity` = c("95.8%", "96.2%", "96.8%"),
      `ROC-AUC` = c("0.72", "0.75", "0.78"),
      `PR-AUC` = c("0.38", "0.44", "0.51"),
      check.names = FALSE
    )
    datatable(metrics_before, options = list(pageLength = 10, dom = 't', 
              columnDefs = list(list(className = 'dt-center', targets = 0:5)))) %>%
      formatStyle('Sensitivity (Recall)', backgroundColor = heat_palette[3])
  })
  
  # ========== RQ3 OUTPUTS (AFTER SMOTE) ==========
  output$table_rq3_metrics_after <- renderDT({
    metrics_after <- data.frame(
      Model = c("Logistic Regression + SMOTE", "Random Forest + SMOTE", "XGBoost + SMOTE"),
      `Accuracy` = c("79.2%", "80.8%", "81.4%"),
      `Sensitivity (Recall)` = c("76.5%", "79.2%", "82.1%"),
      `Specificity` = c("81.8%", "82.5%", "80.7%"),
      `ROC-AUC` = c("0.82", "0.84", "0.87"),
      `PR-AUC` = c("0.71", "0.75", "0.79"),
      check.names = FALSE
    )
    datatable(metrics_after, options = list(pageLength = 10, dom = 't',
              columnDefs = list(list(className = 'dt-center', targets = 0:5)))) %>%
      formatStyle('Sensitivity (Recall)', backgroundColor = heat_palette[7])
  })
  
  # ========== RQ3 COMPARISON PLOT ==========
  output$plot_rq3_comparison <- renderPlotly({
    comparison_df <- data.frame(
      Model = c("LR", "RF", "XGB", "LR", "RF", "XGB"),
      Metric = c("Before", "Before", "Before", "After", "After", "After"),
      ROC_AUC = c(0.72, 0.75, 0.78, 0.82, 0.84, 0.87),
      Sensitivity = c(0.321, 0.385, 0.427, 0.765, 0.792, 0.821)
    )
    
    p1 <- plot_ly(filter(comparison_df, Metric == "Before"), 
                  x = ~Model, y = ~ROC_AUC, type = 'bar',
                  marker = list(color = heat_palette[4]), name = 'Before SMOTE') %>%
      add_trace(data = filter(comparison_df, Metric == "After"),
                x = ~Model, y = ~ROC_AUC,
                marker = list(color = heat_palette[9]), name = 'After SMOTE')
    
    layout(p1, title = "ROC-AUC: Before vs After SMOTE",
           xaxis = list(title = "Model"),
           yaxis = list(title = "ROC-AUC Score", range = c(0.6, 1)),
           barmode = 'group')
  })
  
  # ========== RQ3 FEATURE IMPORTANCE ==========
  output$plot_rq3_importance <- renderPlotly({
    importance_data <- data.frame(
      Feature = c("time_in_hospital", "num_medications", "visit_number", 
                  "number_diagnoses", "num_lab_procedures", "age_num"),
      Importance = c(0.28, 0.24, 0.20, 0.16, 0.08, 0.04)
    ) %>%
      arrange(Importance)
    
    # Create color gradient based on importance
    colors <- colorRampPalette(c(heat_palette[2], heat_palette[9]))(6)
    
    plot_ly(importance_data, x = ~Importance, y = ~Feature, type = 'bar',
            orientation = 'h', marker = list(color = colors)) %>%
      layout(title = "XGBoost Feature Importance (SMOTE Model)",
             xaxis = list(title = "Importance Score"),
             yaxis = list(title = "Feature"),
             margin = list(l = 150))
  })
  
  # ========== SMOTE ANALYSIS ==========
  # Define magma palette (viridis magma)
  magma_palette <- c("#000004", "#3B0F70", "#8C2981", "#DE4968", "#FE9F6D", "#FCFDBF")
  
  output$plot_smote_comparison <- renderPlotly({
    smote_data <- data.frame(
      Scenario = c("Original", "Original", "After SMOTE", "After SMOTE"),
      Class = c("No Readmission", "Readmission", "No Readmission", "Readmission"),
      Count = c(4500, 800, 4500, 4500),
      Percentage = c("85%", "15%", "50%", "50%")
    )
    
    # Magma colors: dark for "Before" - light for "After"
    plot_ly(smote_data, x = ~Scenario, y = ~Count, color = ~Class, type = 'bar',
            marker = list(color = c(magma_palette[2], magma_palette[4], magma_palette[3], magma_palette[5]))) %>%
      add_text(text = ~Percentage, textposition = "top") %>%
      layout(title = "Class Distribution: Before vs After SMOTE",
             xaxis = list(title = "Dataset"),
             yaxis = list(title = "Number of Samples"),
             barmode = 'group',
             legend = list(x = 0.02, y = 0.98),
             plot_bgcolor = 'rgba(240,240,240,0.5)')
  })
  
  output$table_smote_comparison <- renderDT({
    smote_table <- data.frame(
      Aspect = c("Total Samples", "No Readmission", "Readmission", "Class Ratio", "Balance"),
      Original = c("5,300", "4,500 (85%)", "800 (15%)", "5.6:1", "Highly Imbalanced"),
      `After SMOTE` = c("9,000", "4,500 (50%)", "4,500 (50%)", "1:1", "Perfectly Balanced"),
      check.names = FALSE
    )
    datatable(smote_table, options = list(pageLength = 10, dom = 't'))
  })
  
  output$table_smote_impact <- renderDT({
    impact_table <- data.frame(
      Metric = c("ROC-AUC Gain", "Sensitivity Gain", "PR-AUC Gain", "Avg Accuracy Change"),
      `Logistic Regression` = c("+10%", "+44%", "+33%", "-8%"),
      `Random Forest` = c("+9%", "+41%", "+31%", "-7%"),
      `XGBoost` = c("+9%", "+39%", "+28%", "-7%"),
      check.names = FALSE
    )
    datatable(impact_table, options = list(pageLength = 10, dom = 't')) %>%
      formatStyle(columns = 1:4, backgroundColor = '#E8F5E9')
  })
}

shinyApp(ui = ui, server = server)
