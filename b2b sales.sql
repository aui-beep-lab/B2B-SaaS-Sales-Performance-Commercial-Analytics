USE `b2b sales`;

-- ============================================================================
-- 0. INDEX OPTIMIZATION (Speed & Query Performance)
-- ============================================================================

CREATE INDEX `idx_date_key` ON `saas-sales` (`Date Key`);
CREATE INDEX `idx_customer` ON `saas-sales` (`Customer`(50));
CREATE INDEX `idx_region_segment` ON `saas-sales` (`Region`(20), `Segment`(20));
CREATE INDEX `idx_product` ON `saas-sales` (`Product`(50));


-- ============================================================================
-- 1. DATA QUALITY CHECKS
-- ============================================================================

-- 1.1 Comprehensive Null & Logical Integrity Check Across All 19 Columns
SELECT
    -- Identifiers & Dates
    SUM(`Row ID` IS NULL)                 AS null_row_id,
    SUM(`Order ID` IS NULL)               AS null_order_id,
    SUM(`Order Date` IS NULL)             AS null_order_date,
    SUM(`Date Key` IS NULL)               AS null_date_key,

    -- Customer & Contact Information
    SUM(`Contact Name` IS NULL)           AS null_contact_name,
    SUM(`Customer` IS NULL)               AS null_customer,
    SUM(`Customer ID` IS NULL)            AS null_customer_id,

    -- Geography & Categorization
    SUM(`Country` IS NULL)                AS null_country,
    SUM(`City` IS NULL)                   AS null_city,
    SUM(`Region` IS NULL)                 AS null_region,
    SUM(`Subregion` IS NULL)              AS null_subregion,
    SUM(`Industry` IS NULL)               AS null_industry,
    SUM(`Segment` IS NULL)                AS null_segment,

    -- Product & Licensing
    SUM(`Product` IS NULL)                AS null_product,
    SUM(`License` IS NULL)                AS null_license,

    -- Financial Metrics (Null Checks)
    SUM(`Sales` IS NULL)                  AS null_sales,
    SUM(`Quantity` IS NULL)               AS null_quantity,
    SUM(`Discount` IS NULL)               AS null_discount,
    SUM(`Profit` IS NULL)                 AS null_profit,

    -- Logical Boundary & Business Rule Checks
    SUM(`Sales` < 0)                      AS invalid_negative_sales,
    SUM(`Quantity` <= 0)                  AS invalid_quantity,
    SUM(`Discount` NOT BETWEEN 0 AND 1)   AS invalid_discount_range
FROM `saas-sales`;

-- 1.2 Duplicate row check
SELECT `Row ID`, COUNT(*) AS n
FROM `saas-sales`
GROUP BY `Row ID`
HAVING COUNT(*) > 1;

-- 1.3 Orders mapped to multiple customers check
SELECT `Order ID`, COUNT(DISTINCT `Customer`) AS n_customers
FROM `saas-sales`
GROUP BY `Order ID`
HAVING COUNT(DISTINCT `Customer`) > 1;


-- ============================================================================
-- 2. CORE COMMERCIAL KPIs & GROWTH
-- ============================================================================

-- 2.1 Headline KPIs
SELECT
    COUNT(DISTINCT `Order ID`)                                      AS total_orders,
    COUNT(DISTINCT `Customer`)                                      AS total_customers,
    ROUND(SUM(`Sales`), 2)                                          AS total_revenue,
    ROUND(SUM(`Profit`), 2)                                         AS total_profit,
    ROUND(SUM(`Profit`) / NULLIF(SUM(`Sales`), 0) * 100, 2)         AS overall_margin_pct,
    ROUND(SUM(`Sales`) / NULLIF(COUNT(DISTINCT `Order ID`), 0), 2)  AS avg_order_value
FROM `saas-sales`;

-- 2.2 Year-over-Year (YoY) Performance
WITH yearly AS (
    SELECT 
        YEAR(STR_TO_DATE(CAST(`Date Key` AS CHAR), '%Y%m%d')) AS sales_year,
        SUM(`Sales`)  AS revenue,
        SUM(`Profit`) AS profit
    FROM `saas-sales`
    GROUP BY sales_year
)
SELECT 
    sales_year,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2)  AS profit,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY sales_year)) 
          / NULLIF(LAG(revenue) OVER (ORDER BY sales_year), 0) * 100, 1) AS yoy_revenue_growth_pct
FROM yearly
ORDER BY sales_year;

-- 2.3 Monthly Revenue Trend & MoM Growth
WITH monthly AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(CAST(`Date Key` AS CHAR), '%Y%m%d'), '%Y-%m-01') AS order_month,
        SUM(`Sales`)  AS revenue,
        SUM(`Profit`) AS profit
    FROM `saas-sales`
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    profit,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY order_month), 2) AS mom_change,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY order_month))
          / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0) * 100, 1) AS mom_growth_pct,
    ROUND(AVG(revenue) OVER (ORDER BY order_month
          ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3mo_avg
FROM monthly
ORDER BY order_month;

-- 2.4 Revenue & Margin by Region and Segment
SELECT
    `Region`,
    `Segment`,
    ROUND(SUM(`Sales`), 2)                                  AS revenue,
    ROUND(SUM(`Profit`), 2)                                 AS profit,
    ROUND(SUM(`Profit`) / NULLIF(SUM(`Sales`), 0) * 100, 1) AS margin_pct,
    COUNT(DISTINCT `Order ID`)                              AS orders
FROM `saas-sales`
GROUP BY `Region`, `Segment`
ORDER BY revenue DESC;

-- 2.5 Top 3 Products per Region
SELECT * FROM (
    SELECT
        `Region`,
        `Product`,
        ROUND(SUM(`Sales`), 2)  AS revenue,
        ROUND(SUM(`Profit`), 2) AS profit,
        RANK() OVER (PARTITION BY `Region` ORDER BY SUM(`Sales`) DESC) AS rank_in_region
    FROM `saas-sales`
    GROUP BY `Region`, `Product`
) ranked
WHERE rank_in_region <= 3
ORDER BY `Region`, rank_in_region;


-- ============================================================================
-- 3. PRICING, DISCOUNTS & CROSS-SELL ANALYSIS
-- ============================================================================

-- 3.1 Margin by Discount Band
SELECT
    CASE
        WHEN `Discount` = 0     THEN '0%'
        WHEN `Discount` <= 0.10 THEN '1-10%'
        WHEN `Discount` <= 0.20 THEN '11-20%'
        WHEN `Discount` <= 0.30 THEN '21-30%'
        ELSE '31%+'
    END AS discount_band,
    COUNT(*)                                                AS line_items,
    ROUND(SUM(`Sales`), 2)                                  AS revenue,
    ROUND(SUM(`Profit`), 2)                                 AS profit,
    ROUND(SUM(`Profit`) / NULLIF(SUM(`Sales`), 0) * 100, 2) AS margin_pct
FROM `saas-sales`
GROUP BY discount_band
ORDER BY discount_band;

-- 3.2 Loss-Making Products/Segments
SELECT
    `Product`,
    `Segment`,
    COUNT(*)                        AS loss_making_orders,
    ROUND(AVG(`Discount`) * 100, 1) AS avg_discount_pct,
    ROUND(SUM(`Profit`), 2)         AS total_loss
FROM `saas-sales`
WHERE `Profit` < 0
GROUP BY `Product`, `Segment`
ORDER BY total_loss ASC
LIMIT 15;

-- 3.3 Product Expansion & Cross-Sell Adoption
SELECT
    CASE 
        WHEN product_count = 1 THEN '1 Product'
        WHEN product_count = 2 THEN '2 Products'
        ELSE '3+ Products'
    END AS product_adoption_tier,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_revenue), 2) AS tier_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_spend_per_customer
FROM (
    SELECT 
        `Customer`,
        COUNT(DISTINCT `Product`) AS product_count,
        SUM(`Sales`)               AS total_revenue
    FROM `saas-sales`
    GROUP BY `Customer`
) customer_products
GROUP BY product_adoption_tier
ORDER BY total_customers DESC;


-- ============================================================================
-- 4. CUSTOMER RFM SEGMENTATION
-- ============================================================================

WITH customer_dates AS (
    SELECT
        `Customer`,
        `Sales`,
        `Order ID`,
        STR_TO_DATE(CAST(`Date Key` AS CHAR), '%Y%m%d') AS parsed_date
    FROM `saas-sales`
),
customer_agg AS (
    SELECT
        `Customer`,
        MAX(parsed_date)                                                           AS last_order_date,
        COUNT(DISTINCT `Order ID`)                                                 AS frequency,
        SUM(`Sales`)                                                               AS monetary,
        DATEDIFF((SELECT MAX(parsed_date) FROM customer_dates) + INTERVAL 1 DAY, MAX(parsed_date)) AS recency_days
    FROM customer_dates
    GROUP BY `Customer`
),
scored AS (
    SELECT
        `Customer`, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM customer_agg
)
SELECT
    `Customer`, recency_days, frequency, monetary,
    (r_score + f_score + m_score) AS rfm_score,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champion'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal / Growth'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Needs Attention'
        ELSE 'At Risk / Dormant'
    END AS rfm_tier
FROM scored
ORDER BY rfm_score DESC;


-- ============================================================================
-- 5. PARETO / ACCOUNT CONCENTRATION
-- ============================================================================

WITH customer_revenue AS (
    SELECT `Customer`, SUM(`Sales`) AS revenue
    FROM `saas-sales`
    GROUP BY `Customer`
),
ranked AS (
    SELECT
        `Customer`, revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS running_total,
        SUM(revenue) OVER ()                      AS grand_total,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rn
    FROM customer_revenue
)
SELECT
    `Customer`, 
    ROUND(revenue, 2) AS revenue,
    ROUND(running_total / NULLIF(grand_total, 0) * 100, 1) AS cumulative_pct_of_revenue,
    rn AS customer_rank
FROM ranked
ORDER BY revenue DESC
LIMIT 25;


-- ============================================================================
-- 6. COHORT-STYLE RETENTION
-- ============================================================================

WITH customer_dates AS (
    SELECT 
        `Customer`,
        STR_TO_DATE(CAST(`Date Key` AS CHAR), '%Y%m%d') AS parsed_date
    FROM `saas-sales`
),
first_purchase AS (
    SELECT 
        `Customer`, 
        DATE_SUB(MIN(parsed_date), INTERVAL DAYOFMONTH(MIN(parsed_date)) - 1 DAY) AS cohort_month
    FROM customer_dates
    GROUP BY `Customer`
),
activity AS (
    SELECT
        cd.`Customer`,
        fp.cohort_month,
        DATE_SUB(cd.parsed_date, INTERVAL DAYOFMONTH(cd.parsed_date) - 1 DAY) AS activity_month,
        TIMESTAMPDIFF(MONTH, fp.cohort_month, cd.parsed_date) AS months_since_first_purchase
    FROM customer_dates cd
    JOIN first_purchase fp ON cd.`Customer` = fp.`Customer`
)
SELECT
    cohort_month,
    months_since_first_purchase,
    COUNT(DISTINCT `Customer`) AS active_customers
FROM activity
GROUP BY cohort_month, months_since_first_purchase
ORDER BY cohort_month, months_since_first_purchase;


-- ============================================================================
-- 7. BI-READY VIEWS (for Tableau / Power BI)
-- ============================================================================

-- 7.1 Enriched Fact Sales View
CREATE OR REPLACE VIEW `vw_sales_enriched` AS
SELECT
    s.*,
    STR_TO_DATE(CAST(s.`Date Key` AS CHAR), '%Y%m%d')                   AS order_date_parsed,
    YEAR(STR_TO_DATE(CAST(s.`Date Key` AS CHAR), '%Y%m%d'))            AS order_year,
    QUARTER(STR_TO_DATE(CAST(s.`Date Key` AS CHAR), '%Y%m%d'))         AS order_quarter,
    DATE_FORMAT(STR_TO_DATE(CAST(s.`Date Key` AS CHAR), '%Y%m%d'), '%Y-%m') AS order_year_month,
    ROUND(s.`Profit` / NULLIF(s.`Sales`, 0), 4)                        AS profit_margin,
    CASE WHEN s.`Discount` > 0 THEN 'Discounted' ELSE 'Full Price' END AS discount_flag,
    CASE WHEN s.`Profit` < 0 THEN 1 ELSE 0 END                         AS is_loss_making
FROM `saas-sales` s;

-- 7.2 Reusable Customer RFM Tier View
CREATE OR REPLACE VIEW `vw_customer_rfm` AS
WITH customer_dates AS (
    SELECT
        `Customer`, `Sales`, `Order ID`,
        STR_TO_DATE(CAST(`Date Key` AS CHAR), '%Y%m%d') AS parsed_date
    FROM `saas-sales`
),
customer_agg AS (
    SELECT
        `Customer`,
        COUNT(DISTINCT `Order ID`) AS frequency,
        SUM(`Sales`) AS monetary,
        DATEDIFF((SELECT MAX(parsed_date) FROM customer_dates) + INTERVAL 1 DAY, MAX(parsed_date)) AS recency_days
    FROM customer_dates
    GROUP BY `Customer`
),
scored AS (
    SELECT
        `Customer`, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM customer_agg
)
SELECT
    `Customer`, recency_days, frequency, monetary,
    (r_score + f_score + m_score) AS rfm_score,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champion'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal / Growth'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Needs Attention'
        ELSE 'At Risk / Dormant'
    END AS rfm_tier
FROM scored;