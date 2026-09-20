# B2B SaaS Sales Performance & Commercial Analytics

End-to-end commercial analytics project on a 9,994-row, 4-year B2B SaaS transactional dataset
(48 countries, 3 regions, 3 customer segments, 14 products). Built to demonstrate the analytics,
SQL, and Excel automation skill set required for a **B2B Sales Products & Programs / Sales
Operations** function: pricing governance, CRM-ready reporting, and commercial decision support.

## Repository Structure

```
├── B2B_SaaS_Sales_Analysis.ipynb   # Main analysis notebook (Python)
├── SaaS-Sales.csv                  # Raw source data
├── data/
│   └── SaaS_Sales_Cleaned.csv      # Cleaned, feature-engineered export
├── images/                         # All charts exported as standalone PNGs
├── sql/
│   └── mysql_queries.sql           # MySQL: DDL, QA checks, KPIs, RFM, cohort, BI views
└── vba/
    └── Dashboard_Builder.bas       # One-click Excel VBA executive dashboard generator
```

## What's in the Notebook

1. **Data Quality Assessment**: nulls, duplicates, type/range validation.
2. **Data Cleaning & Feature Engineering**: dates, profit margin, discount bands, RFM inputs.
3. **Exploratory Data Analysis**: revenue/profit trend, region × segment breakdown, product &
   industry performance, order-value distribution, seasonality heatmap, correlation matrix.
4. **Discount & Margin Analysis**: quantifies (with a Welch's t-test) how discount depth erodes
   profitability, directly supporting a discount-governance policy recommendation.
5. **Pareto / Account Concentration**: validates the 80/20 revenue concentration across customers
   and products.
6. **Customer Segmentation**: rule-based RFM scoring plus K-Means clustering (with elbow-method
   validation) to derive data-driven account tiers.
7. **Time-Series Forecasting**: two independently implemented models (seasonal regression and
   Holt's linear exponential smoothing), validated on a 6-month holdout, used to forecast the next
   6 months of revenue.
8. **Executive Summary**: insight → recommendation table connecting each finding to a concrete
   commercial/pricing action.

## Running the Notebook

```bash
pip install pandas numpy matplotlib seaborn scikit-learn scipy
jupyter notebook B2B_SaaS_Sales_Analysis.ipynb
```

The notebook only depends on the standard PyData stack (no `statsmodels`/`prophet` required),
so it runs anywhere out of the box. Update `DATA_PATH` in Section 2 if you move the CSV.

## SQL (MySQL)

`sql/mysql_queries.sql` recreates the schema, runs the same data-quality checks, and layers on
window-function analytics (rolling averages, MoM growth, rank-per-region), a pure-SQL RFM
segmentation using `NTILE`, a Pareto/concentration query, a cohort-retention query, and two views
(`vw_sales_enriched`, `vw_customer_rfm`) intended as the connection point for Tableau/Power BI.

## Excel Dashboard 

Excel Dashboard is a fully self-contained macro that builds an executive dashboard from
a `Data` sheet/table in any workbook: KPI cards, a monthly revenue trend chart, region/segment/
product charts, and cross-filtering slicers, all built from static formula ranges so custom colors and formatting survive slicer filtering. Import the module and run
`BuildDashboard`.

## Key Findings (see notebook Section 8 for full detail)

- Revenue grows consistently YoY with a strong Q4 seasonal peak (renewal/budget-cycle pattern).
- Average profit margin turns negative once discounts exceed ~20% (statistically significant).
- A small subset of enterprise accounts drives the large majority of revenue (Pareto pattern).
- RFM + clustering surfaces a clear "At Risk / Dormant" tier for targeted win-back outreach.
- A 6-month forward revenue forecast is produced and validated against a holdout period.

