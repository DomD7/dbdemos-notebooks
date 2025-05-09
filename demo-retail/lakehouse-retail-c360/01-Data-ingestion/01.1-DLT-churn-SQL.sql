-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC # Data engineering with Databricks - Building our C360 database
-- MAGIC
-- MAGIC Building a C360 database requires ingesting multiple data sources.  
-- MAGIC
-- MAGIC It's a complex process requiring batch loads and streaming ingestion to support real-time insights, used for personalization and marketing targeting among other.
-- MAGIC
-- MAGIC Ingesting, transforming and cleaning data to create clean SQL tables for our downstream user (Data Analysts and Data Scientists) is complex.
-- MAGIC
-- MAGIC <link href="https://fonts.googleapis.com/css?family=DM Sans" rel="stylesheet"/>
-- MAGIC <div style="width: 300px; height: 300px; text-align: center; float: right; margin: 30px 60px 10px 10px; font-family: 'DM Sans'; border-radius: 50%; border: 25px solid #fcba33ff; box-sizing: border-box; overflow: hidden;">
-- MAGIC   <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%; width: 100%;">
-- MAGIC     <div style="font-size: 70px; color: #70c4ab; font-weight: bold;">
-- MAGIC       73%
-- MAGIC     </div>
-- MAGIC     <div style="color: #1b5162; padding: 0 30px; text-align: center;">
-- MAGIC       of enterprise data goes unused for analytics and decision making
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC   <div style="color: #bfbfbf; padding-top: 5px;">
-- MAGIC     Source: Forrester
-- MAGIC   </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <br>
-- MAGIC
-- MAGIC ## <img src="https://raw.githubusercontent.com/databricks-demos/dbdemos-resources/refs/heads/main/images/john.png" style="float:left; margin: -35px 0px 0px 0px" width="80px"> John, as Data engineer, spends immense time….
-- MAGIC
-- MAGIC
-- MAGIC * Hand-coding data ingestion & transformations and dealing with technical challenges:<br>
-- MAGIC   *Supporting streaming and batch, handling concurrent operations, small files issues, GDPR requirements, complex DAG dependencies...*<br><br>
-- MAGIC * Building custom frameworks to enforce quality and tests<br><br>
-- MAGIC * Building and maintaining scalable infrastructure, with observability and monitoring<br><br>
-- MAGIC * Managing incompatible governance models from different systems
-- MAGIC <br style="clear: both">
-- MAGIC
-- MAGIC This results in **operational complexity** and overhead, requiring expert profile and ultimately **putting data projects at risk**.
-- MAGIC
-- MAGIC
-- MAGIC <!-- Collect usage data (view). Remove it to disable collection or disable tracker during installation. View README for more details.  -->
-- MAGIC <img width="1px" src="https://ppxrzfxige.execute-api.us-west-2.amazonaws.com/v1/analytics?category=lakehouse&notebook=01.1-DLT-churn-SQL&demo_name=lakehouse-retail-c360&event=VIEW">

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Simplify Ingestion and Transformation with Lakeflow Connect & DLT
-- MAGIC
-- MAGIC <img src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/cross_demo_assets/Lakehouse_Demo_Team_architecture_1.png?raw=true" style="float: right" width="500px">
-- MAGIC
-- MAGIC In this notebook, we'll work as a Data Engineer to build our c360 database. <br>
-- MAGIC We'll consume and clean our raw data sources to prepare the tables required for our BI & ML workload.
-- MAGIC
-- MAGIC We want to ingest the datasets below from Salesforce Sales Cloud and blob storage (`/demos/retail/churn/`) incrementally into our Data Warehousing tables:
-- MAGIC
-- MAGIC - Customer profile data *(name, age, address etc)*
-- MAGIC - Orders history *(what our customer bought over time)*
-- MAGIC - Streaming Events from our application *(when was the last time customers used the application, typically a stream from a Kafka queue)*
-- MAGIC
-- MAGIC
-- MAGIC <a href="https://www.databricks.com/resources/demos/tours/platform/discover-databricks-lakeflow-connect-demo" target="_blank"><img src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/product/lakeflow-connect-anim.gif?raw=true" style="float: right; margin-right: 20px" width="250px"></a>
-- MAGIC
-- MAGIC ## 1/ Ingest data with Lakeflow Connect
-- MAGIC
-- MAGIC
-- MAGIC Lakeflow Connect offers built-in data ingestion connectors for popular SaaS applications, databases and file sources, such as Salesforce, Workday, and SQL Server to build incremental data pipelines at scale, fully integrated with Databricks. 
-- MAGIC
-- MAGIC
-- MAGIC ## 2/ Prepare and transform your data with DLT
-- MAGIC
-- MAGIC <div>
-- MAGIC   <div style="width: 45%; float: left; margin-bottom: 10px; padding-right: 45px">
-- MAGIC     <p style="min-height: 65px;">
-- MAGIC       <img style="width: 50px; float: left; margin: 0px 5px 30px 0px;" src="https://raw.githubusercontent.com/diganparikh-dp/Images/refs/heads/main/Icons/LakeFlow%20Connect.jpg"/> 
-- MAGIC       <strong>Efficient end-to-end ingestion</strong> <br/>
-- MAGIC       Enable analysts and data engineers to innovate rapidly with simple pipeline development and maintenance 
-- MAGIC     </p>
-- MAGIC     <p>
-- MAGIC       <img style="width: 50px; float: left; margin: 0px 5px 30px 0px;" src="https://raw.githubusercontent.com/diganparikh-dp/Images/refs/heads/main/Icons/LakeFlow%20Pipelines.jpg"/> 
-- MAGIC       <strong>Flexible and easy setup</strong> <br/>
-- MAGIC       By automating complex administrative tasks and gaining broader visibility into pipeline operations
-- MAGIC     </p>
-- MAGIC   </div>
-- MAGIC   <div style="width: 48%; float: left">
-- MAGIC     <p style="min-height: 65px;">
-- MAGIC       <img style="width: 50px; float: left; margin: 0px 5px 30px 0px;" src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/retail/resources/images/lakehouse-retail/logo-trust.png"/> 
-- MAGIC       <strong>Trust your data</strong> <br/>
-- MAGIC       With built-in orchestration, quality controls and quality monitoring to ensure accurate and useful BI, Data Science, and ML 
-- MAGIC     </p>
-- MAGIC     <p>
-- MAGIC       <img style="width: 50px; float: left; margin: 0px 5px 30px 0px;" src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/retail/resources/images/lakehouse-retail/logo-stream.png"/> 
-- MAGIC       <strong>Simplify batch and streaming</strong> <br/>
-- MAGIC       With self-optimization and auto-scaling data pipelines for batch or streaming processing 
-- MAGIC     </p>
-- MAGIC </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <br style="clear:both">

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC ## Building a DLT pipeline to analyze and reduce churn
-- MAGIC
-- MAGIC In this example, we'll implement a end-to-end DLT pipeline consuming our customers information. We'll use the medallion architecture but we could build star schema, data vault or any other modelisation.
-- MAGIC
-- MAGIC We'll incrementally load new data with the autoloader, enrich this information and then load a model from MLFlow to perform our customer churn prediction.
-- MAGIC
-- MAGIC This information will then be used to build our DBSQL dashboard to track customer behavior and churn.
-- MAGIC
-- MAGIC Let's implement the following flow: 
-- MAGIC  
-- MAGIC <div><img width="1100px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-churn-de.png?raw=true"/></div>
-- MAGIC
-- MAGIC *Note that we're including the ML model our [Data Scientist built]($../04-Data-Science-ML/04.1-automl-churn-prediction) using Databricks AutoML to predict the churn. We'll cover that in the next section.*

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Your DLT Pipeline has been installed and started for you! Open the <a dbdemos-pipeline-id="dlt-churn" href="#joblist/pipelines/a6ba1d12-74d7-4e2d-b9b7-ca53b655f39d" target="_blank">Churn DLT pipeline</a> to see it in action.<br/>
-- MAGIC *(Note: The pipeline will automatically start once the initialization job is completed, this might take a few minutes... Check installation logs for more details)*

-- COMMAND ----------

-- DBTITLE 1,Let's explore our raw incoming data data: users (json)
--%python
--display(spark.read.json('/Volumes/main__build/dbdemos_retail_c360/c360/users'))

-- COMMAND ----------

-- DBTITLE 1,Raw incoming orders (json)
--%python
--display(spark.read.json('/Volumes/main__build/dbdemos_retail_c360/c360/orders'))

-- COMMAND ----------

-- DBTITLE 1,Raw incoming clickstream (csv)
--%python
--display(spark.read.csv('/Volumes/main__build/dbdemos_retail_c360/c360/events', header=True))

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### 1/ Loading our data using Databricks Autoloader (cloud_files)
-- MAGIC <div style="float:right">
-- MAGIC   <img width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-churn-de-small-1.png?raw=true"/>
-- MAGIC </div>
-- MAGIC   
-- MAGIC Autoloader allow us to efficiently ingest millions of files from a cloud storage, and support efficient schema inference and evolution at scale.
-- MAGIC
-- MAGIC For more details on autoloader, run `dbdemos.install('auto-loader')`
-- MAGIC
-- MAGIC Let's use it to our pipeline and ingest the raw JSON & CSV data being delivered in our blob storage `/demos/retail/churn/...`. 

-- COMMAND ----------

-- MAGIC %md
-- MAGIC

-- COMMAND ----------

-- DBTITLE 1,Ingest raw app events stream in incremental mode 
CREATE STREAMING TABLE churn_app_events (
  CONSTRAINT correct_schema EXPECT (_rescued_data IS NULL)
)
COMMENT "Application events and sessions"
AS SELECT * FROM cloud_files("/Volumes/main__build/dbdemos_retail_c360/c360/events", "csv", map("cloudFiles.inferColumnTypes", "true"))

-- COMMAND ----------

-- DBTITLE 1,Ingest raw orders from ERP
CREATE STREAMING TABLE churn_orders_bronze (
  CONSTRAINT orders_correct_schema EXPECT (_rescued_data IS NULL)
)
COMMENT "Spending score from raw data"
AS SELECT * FROM cloud_files("/Volumes/main__build/dbdemos_retail_c360/c360/orders", "json")

-- COMMAND ----------

-- DBTITLE 1,Ingest raw user data
CREATE STREAMING TABLE churn_users_bronze (
  CONSTRAINT correct_schema EXPECT (_rescued_data IS NULL)
)
COMMENT "raw user data coming from json files ingested in incremental with Auto Loader to support schema inference and evolution"
AS SELECT * FROM cloud_files("/Volumes/main__build/dbdemos_retail_c360/c360/users", "json", map("cloudFiles.inferColumnTypes", "true"))

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### 2/ Enforce quality and materialize our tables for Data Analysts
-- MAGIC <div style="float:right">
-- MAGIC   <img width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-churn-de-small-2.png?raw=true"/>
-- MAGIC </div>
-- MAGIC
-- MAGIC The next layer often call silver is consuming **incremental** data from the bronze one, and cleaning up some information.
-- MAGIC
-- MAGIC We're also adding an [expectation](https://docs.databricks.com/workflows/delta-live-tables/delta-live-tables-expectations.html) on different field to enforce and track our Data Quality. This will ensure that our dashboards are relevant and easily spot potential errors due to data anomaly.
-- MAGIC
-- MAGIC For more advanced DLT capabilities run `dbdemos.install('dlt-loans')` or `dbdemos.install('dlt-cdc')` for CDC/SCDT2 example.
-- MAGIC
-- MAGIC These tables are clean and ready to be used by the BI team!

-- COMMAND ----------

-- DBTITLE 1,Clean and anonymise User data
CREATE STREAMING TABLE churn_users (
  CONSTRAINT user_valid_id EXPECT (user_id IS NOT NULL) ON VIOLATION DROP ROW
)
TBLPROPERTIES (pipelines.autoOptimize.zOrderCols = "id")
COMMENT "User data cleaned and anonymized for analysis."
AS SELECT
  id as user_id,
  sha1(email) as email, 
  to_timestamp(creation_date, "MM-dd-yyyy HH:mm:ss") as creation_date, 
  to_timestamp(last_activity_date, "MM-dd-yyyy HH:mm:ss") as last_activity_date, 
  initcap(firstname) as firstname, 
  initcap(lastname) as lastname, 
  address, 
  canal, 
  country,
  cast(gender as int),
  cast(age_group as int), 
  cast(churn as int) as churn
from STREAM(live.churn_users_bronze)

-- COMMAND ----------

-- DBTITLE 1,Clean orders
CREATE STREAMING LIVE TABLE churn_orders (
  CONSTRAINT order_valid_id EXPECT (order_id IS NOT NULL) ON VIOLATION DROP ROW, 
  CONSTRAINT order_valid_user_id EXPECT (user_id IS NOT NULL) ON VIOLATION DROP ROW
)
COMMENT "Order data cleaned and anonymized for analysis."
AS SELECT
  cast(amount as int),
  id as order_id,
  user_id,
  cast(item_count as int),
  to_timestamp(transaction_date, "MM-dd-yyyy HH:mm:ss") as creation_date

from STREAM(live.churn_orders_bronze)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### 3/ Aggregate and join data to create our ML features
-- MAGIC <div style="float:right">
-- MAGIC   <img width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-churn-de-small-3.png?raw=true"/>
-- MAGIC </div>
-- MAGIC
-- MAGIC We're now ready to create the features required for our Churn prediction.
-- MAGIC
-- MAGIC We need to enrich our user dataset with extra information which our model will use to help predicting churn, such as:
-- MAGIC
-- MAGIC * last command date
-- MAGIC * number of items bought
-- MAGIC * number of actions in our website
-- MAGIC * device used (iOS/iPhone)
-- MAGIC * ...

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW churn_features
COMMENT "Final user table with all information for Analysis / ML"
AS 
  WITH 
    churn_orders_stats AS (SELECT user_id, count(*) as order_count, sum(amount) as total_amount, sum(item_count) as total_item, max(creation_date) as last_transaction
      FROM live.churn_orders GROUP BY user_id),  
    churn_app_events_stats as (
      SELECT first(platform) as platform, user_id, count(*) as event_count, count(distinct session_id) as session_count, max(to_timestamp(date, "MM-dd-yyyy HH:mm:ss")) as last_event
        FROM live.churn_app_events GROUP BY user_id)

  SELECT *, 
         datediff(now(), creation_date) as days_since_creation,
         datediff(now(), last_activity_date) as days_since_last_activity,
         datediff(now(), last_event) as days_last_event
       FROM live.churn_users
         INNER JOIN churn_orders_stats using (user_id)
         INNER JOIN churn_app_events_stats using (user_id)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## 5/ Enriching the gold data with a ML model
-- MAGIC <div style="float:right">
-- MAGIC   <img width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-churn-de-small-4.png?raw=true"/>
-- MAGIC </div>
-- MAGIC
-- MAGIC Our Data scientist team has build a churn prediction model using Auto ML and saved it into Databricks Model registry. 
-- MAGIC
-- MAGIC One of the key value of the Lakehouse is that we can easily load this model and predict our churn right into our pipeline. 
-- MAGIC
-- MAGIC Note that we don't have to worry about the model framework (sklearn or other), MLFlow abstracts that for us.
-- MAGIC
-- MAGIC This model was trained as part of the demo! Open [$./04-Data-Science-ML/04.1-automl-churn-prediction](./04-Data-Science-ML/04.1-automl-churn-prediction) to see how it's done.

-- COMMAND ----------

-- DBTITLE 1,Load the model as SQL function
--Loaded in 01.2-DLT-churn-Python-UDF
--
--%python
--import mlflow
--mlflow.set_registry_uri('databricks-uc')
--#                                                                              Stage/version  
--#                                                                 Model name         |        
--#                                                                     |              |        
--predict_churn_udf = mlflow.pyfunc.spark_udf(spark, "models:/main__build.dbdemos_retail_c360.dbdemos_customer_churn@prod", "int")
--spark.udf.register("predict_churn", predict_churn_udf)

-- COMMAND ----------

-- DBTITLE 1,Call our model and predict churn in our pipeline
CREATE OR REFRESH MATERIALIZED VIEW churn_prediction 
COMMENT "Customer at risk of churn"
  AS SELECT predict_churn(struct(user_id, 1 as age_group, canal, country, gender, order_count, total_amount, total_item, last_transaction, platform, event_count, session_count, days_since_creation, days_since_last_activity, days_last_event)) as churn_prediction, * FROM live.churn_features

-- COMMAND ----------

-- MAGIC %md ## Our pipeline is now ready!
-- MAGIC
-- MAGIC As you can see, building Data Pipelines with Databricks lets you focus on your business implementation while the engine solves all of the hard data engineering work for you.
-- MAGIC
-- MAGIC Open the <a dbdemos-pipeline-id="dlt-churn" href="#joblist/pipelines/a6ba1d12-74d7-4e2d-b9b7-ca53b655f39d" target="_blank">Churn DLT pipeline</a> and click on start to visualize your lineage and consume the new data incrementally!

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # Next: secure and share data with Unity Catalog
-- MAGIC
-- MAGIC Now that these tables are available in our Lakehouse, let's review how we can share them with the Data Scientists and Data Analysts teams.
-- MAGIC
-- MAGIC Jump to the [Governance with Unity Catalog notebook]($../00-churn-introduction-lakehouse) or [Go back to the introduction]($../00-churn-introduction-lakehouse)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Optional: Checking your data quality metrics with DLT
-- MAGIC DLT tracks all of your data quality metrics. You can leverage the expectations directly as SQL tables with Databricks SQL to track your expectation metrics and send alerts as required. This lets you build the following dashboards:
-- MAGIC
-- MAGIC <img width="1000" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-c360-dashboard-dlt-stat.png?raw=true">
-- MAGIC
-- MAGIC <a dbdemos-dashboard-id="dlt-quality-stat" href='/sql/dashboardsv3/01ef00cc36721f9e9f2028ee75723cc1' target="_blank">Data Quality Dashboard</a>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Building our first business dashboard with Databricks SQL
-- MAGIC
-- MAGIC Our data is now available! We can start building dashboards to get insights from our past and current business.
-- MAGIC
-- MAGIC <img style="float: left; margin-right: 50px;" width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-c360-dashboard-churn-prediction.png?raw=true" />
-- MAGIC
-- MAGIC <img width="500px" src="https://github.com/databricks-demos/dbdemos-resources/blob/main/images/retail/lakehouse-churn/lakehouse-retail-c360-dashboard-churn.png?raw=true"/>
-- MAGIC
-- MAGIC <a dbdemos-dashboard-id="churn-universal" href='/sql/dashboardsv3/01ef00cc36721f9e9f2028ee75723cc1'  target="_blank">Open the DBSQL Dashboard</a>
