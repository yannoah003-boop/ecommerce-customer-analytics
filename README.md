# E-commerce Customer Analytics Project

This project analyzes an e-commerce transaction dataset to understand **sales performance, product trends, and customer behavior**.  
The analysis combines **Python for data cleaning, SQL for analytical queries, and Power BI for interactive dashboards**.

---


1. Project Overview
This project focuses on analyzing an e-commerce transaction dataset to uncover insights into sales performance, product trends, and customer behavior.
The dataset is sourced from Kaggle (Online Retail Dataset) and contains over 540,000 transaction records, including detailed information such as invoice data, product descriptions, quantities, prices, and customer IDs.
The objective of this project is to build an end-to-end data analytics pipeline using Python, SQL, and Power BI, transforming raw transactional data into actionable business insights.
The analysis covers three main areas:
•	Sales Performance Analysis: evaluating total revenue, order volume, and monthly growth trends 
•	Product Performance Analysis: identifying top-selling and high-revenue products, as well as revenue concentration patterns 
•	Customer Behavior Analysis: understanding customer spending patterns, segmentation (RFM), and retention behavior (cohort analysis) 
The project follows a structured workflow:
•	Data cleaning and preprocessing using Python (Pandas) 
•	Data analysis using SQL (MySQL) with advanced techniques such as window functions and cohort logic 
•	Data visualization through an interactive Power BI dashboard 
This project demonstrates the ability to perform end-to-end data analysis, from raw data preparation to business-focused insights and dashboard reporting.


---

# Dataset

The dataset used in this project is the **Online Retail Dataset** available on Kaggle.

Dataset link:  
https://www.kaggle.com/datasets/ulrikthygepedersen/online-retail-dataset/data

The dataset contains transactional data from a UK-based online retail store between **2010 and 2011**.

Main fields include:

- InvoiceNo – transaction identifier  
- StockCode – product identifier  
- Description – product name  
- Quantity – number of items purchased  
- InvoiceDate – transaction date  
- UnitPrice – price per item  
- CustomerID – customer identifier  
- Country – customer country  

Due to file size limitations, the dataset is **not included in this repository**.

---

# Data Cleaning

Data preprocessing was performed using **Python (Pandas)**.

Main steps include:

- Removing missing `CustomerID`
- Removing negative quantities (product returns)
- Removing invalid prices
- Creating cleaned dataset for analysis

The data cleaning workflow is available in the notebook:
notebooks/data_cleaning.ipynb

---

# SQL Analysis

SQL was used to perform business analysis on the cleaned dataset.

Key analyses include:

### Sales Performance
- Total revenue
- Total orders
- Average order value
- Monthly revenue trend
- Month-over-month growth

### Product Performance
- Top selling products
- Top revenue products
- Product revenue concentration (Pareto analysis)

### Customer Analysis
- Customer spending distribution
- Top customers
- Customer lifetime value indicators

### Customer Segmentation
- RFM (Recency, Frequency, Monetary) analysis
- Customer segmentation

### Retention Analysis
- Repeat purchase behavior
- Purchase interval analysis
- Cohort retention analysis

SQL queries can be found in:
sql/ecommerce_analysis.sql

---

# Dashboard

An interactive **Power BI dashboard** was created to visualize key insights from the analysis.

The dashboard includes:

- Revenue and order KPIs
- Monthly sales trends
- Top-performing products
- Customer segmentation
- Retention metrics

Power BI file:
dashboard/ecommerce_dashboard.pbix

Dashboard screenshots are available in the `images` folder.

---

# Tools Used

- **Python** (Pandas)
- **SQL (MySQL)**
- **Power BI**
- **Jupyter Notebook**

---

# Future Improvements

This project will be expanded with:

- More detailed business insights
- Additional customer behavior analysis
- Enhanced dashboard visualizations
