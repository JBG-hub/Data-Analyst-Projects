-- import data
-- make a staging table to preserve the original table
Create Table chase_staging
Like chase_branches;

Insert chase_staging
Select *
From chase_branches;

-- Rename columns for ease of use
Alter Table chase_staging 
RENAME Column `Institution Name` To institution,
RENAME Column `Main Office` To main_office,
RENAME Column `Branch Name` To branch_name,
RENAME Column `Branch Number` To branch_number,
RENAME Column `Established Date` To established_date,
RENAME Column `Acquired Date` To acquired_date,
RENAME Column `Street Address` To street_address,
RENAME Column `2010 Deposits` To `2010_deposits`,
RENAME Column `2011 Deposits` To `2011_deposits`,
RENAME Column `2012 Deposits` To `2012_deposits`,
RENAME Column `2013 Deposits` To `2013_deposits`,
RENAME Column `2014 Deposits` To `2014_deposits`,
RENAME Column `2015 Deposits` To `2015_deposits`,
RENAME Column `2016 Deposits` To `2016_deposits`;

-- Optional step, but I created 2nd staging table to add/drop rows and columns. 
-- Here I added row_num column to check for duplicate rows in the data.
CREATE TABLE `chase_staging2` (
  `institution` text,
  `main_office` int DEFAULT NULL,
  `branch_name` text,
  `branch_number` int DEFAULT NULL,
  `established_date` text,
  `acquired_date` text,
  `street_address` text,
  `city` text,
  `county` text,
  `state` text,
  `zipcode` int DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `2010_deposits` int DEFAULT NULL,
  `2011_deposits` int DEFAULT NULL,
  `2012_deposits` int DEFAULT NULL,
  `2013_deposits` int DEFAULT NULL,
  `2014_deposits` int DEFAULT NULL,
  `2015_deposits` int DEFAULT NULL,
  `2016_deposits` int DEFAULT NULL,
  `row_num` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

Insert into chase_staging2
Select *, row_number() over(partition by institution, main_office, branch_name, branch_number, established_date, acquired_date, street_address, city, county, state, zipcode, latitude, longitude, 2010_deposits, 2011_deposits, 2012_deposits, 2013_deposits, 2014_deposits, 2015_deposits, 2016_deposits) as row_num
From chase_staging;
-- 4659 rows

Select *
From chase_staging2
where row_num > 1;
-- no duplicates found
-- -- next we can drop column row_num
Alter Table chase_staging2
DROP COLUMN row_num;

-- Cleaning data
-- -- delete rows where branches had no deposit activity during timeframe (outliers)
Delete 
From chase_staging2
Where 2010_deposits = 0 and 2011_deposits = 0 and 2012_deposits = 0 and 2013_deposits = 0 and 2014_deposits = 0 and 2015_deposits = 0 and 2016_deposits = 0;

-- add column for total_deposits that will be used to explore data further (SQL) and visualize data (Tableau)
Alter Table chase_staging2
Add Column total_deposits bigint;

Update chase_staging2
Set total_deposits = 2010_deposits + 2011_deposits + 2012_deposits + 2013_deposits + 2014_deposits + 2015_deposits + 2016_deposits;

-- Search for more outliers. Dropping two rows with total deposits less than 1k over 7 year span.
Delete 
From chase_staging2
Where total_deposits < 1000;

-- data cleaning. Change established_date & acquired_date from text to date. 
-- -- To do so, change "" rows to null for str_to_date to execute properly.
Update chase_staging2
Set established_date = str_to_date(established_date, '%m/%d/%Y');

Update chase_staging2
Set acquired_date = null
Where acquired_date = "";

Update chase_staging2
Set acquired_date = str_to_date(acquired_date, '%m/%d/%Y');

Alter Table chase_staging2
Modify Column established_date DATE,
Modify Column acquirchase_staging2ed_date DATE;


-- Analysis
-- - top 10 branches by deposits, ranked
With rankings as (Select branch_name, branch_number, city, state, zipcode, total_deposits, 
rank() over(Order by total_deposits desc) as ranking
From chase_staging2
Where main_office = 0)

Select *
From rankings
Where ranking <= 10;

-- - # of branches, total_deposits, & avg by state
Select state, count(branch_number) as branches, sum(total_deposits) as total_$, 
round(avg(total_deposits),0) as avg_by_branch
From chase_staging2
Where main_office = 0
Group by state
Order by total_$ desc;

-- Q: How many branches opened and closed during this time frame? 
-- A: Based on deposit activity, it appears only 1 opened (branch 7078 in NY). Only 1 closed (branch 3152 in IL).
Select *
From chase_staging2
Where 2010_deposits = 0 or 2011_deposits = 0 or 2012_deposits = 0 or 2013_deposits = 0 
or 2014_deposits = 0 or 2015_deposits = 0 or 2016_deposits = 0;


-- which states had the most growth in deposits?  GA, CA, IL, CO, UT, NJ , NV,TX, FL, AZ. The South and the West
With growth as (Select branch_name, branch_number, city, state, 2010_deposits, 2016_deposits, 2016_deposits - 2010_deposits as $_change, 
round((2016_deposits - 2010_deposits)/2010_deposits*100,2) as `%_change`
From chase_staging2
Where main_office = 0
Order by $_change desc, `%_change` desc)

Select state, sum($_change) as $_change, round(avg(`%_change`),2) as `avg_branch_%_change`, count(*) branch_count, 
sum(2010_deposits), sum(2016_deposits)
From growth
Group by state
Order by `avg_branch_%_change` desc;

-- How many branches had a decline in deposits from 2010 to 2016? 109
With decline as (Select branch_name, branch_number, city, state, 2010_deposits, 2016_deposits, 2016_deposits - 2010_deposits as $_change, 
round((2016_deposits - 2010_deposits)/2010_deposits*100,2) as `%_change`
From chase_staging2
Where main_office = 0
Order by $_change asc, `%_change` asc)

Select count(*) as declining_branches
From decline
Where `%_change` < 0;

-- Branches declining by state
With decline as (Select branch_name, branch_number, city, state, 2010_deposits, 2016_deposits, 2016_deposits - 2010_deposits as $_change, 
round((2016_deposits - 2010_deposits)/2010_deposits*100,2) as `%_change`
From chase_staging2
Where main_office = 0
Order by $_change asc, `%_change` asc)

Select state, sum($_change) as $_change, round(avg(`%_change`),2) as `avg_%`, count(*) as branch_count
From decline
Where `%_change` < 0
Group by state
Order by branch_count desc;

-- What city has the most bank branches
Select city, state, count(*) as branch_count, sum(total_deposits) as $_deposits
from chase_staging2
Where main_office = 0
group by city, state
order by branch_count desc, $_deposits;

-- Compare the deposits by year
Select sum(2010_deposits), sum(2011_deposits), sum(2012_deposits), sum(2013_deposits), sum(2014_deposits), sum(2015_deposits), sum(2016_deposits)
From chase_staging2
Where main_office = 0;


-- Average deposits per branch by state
Select state, round(avg(total_deposits),0) as average_deposits, sum(total_deposits), count(total_deposits)
From chase_staging2
Where main_office = 0
Group by state
Order by average_deposits desc;

-- Lastly, export data and visualize with Tableau dashboard
Select *
From chase_staging2
Where main_office = 0
Order by branch_number
Limit 10000;
