# Import Data
# Add columns. We are going to split up storage and display into multiple fields. 
# We will rename price to price_rupee and add a column for price_usd. Add columns for brand/processor brand.
Alter Table laptops
Add Column ram text,
Add Column storage_only text,
Add Column display_size text,
Add Column display_pixels text,
Add Column display_type text,
Rename Column price to price_rupee,
Add Column price_usd int after price_rupee,
Add Column brand text After name,
Add Column processor_brand text After processor;

#Set the values for each column created.
Update laptops
Set ram = Case When display like '%,%' Then substring(storage, 1, locate('RAM',storage)+2) End,
storage_only = Case When storage like '%RAM%' Then substring(storage, locate('RAM',storage)+5) End,
display_size = Case When display like '%,%' Then substring(display, 1, locate(',',display)-1) End,
display_pixels = Case When display like '%,%' Then substring(display, locate(',',display)+2, (locate('px',display)+1) - (locate(',',display)+1)) End,
display_type = Case When display like '%,%' Then trim(substring(display, locate('px',display)+3)) End,
price_usd = price_rupee * 0.012,
brand = substring(name, 1, locate(' ', name)),
processor_brand = substring(processor, 1, locate(' ', processor));
# Conversion rate of Rupee to USD is 0.012 as of the date of this project.

#Check for duplicates
select name, name_c, storage, display, count(*)
From laptops
group by name, name_c, storage, display
Having count(*) > 1;
#No duplicates found

#Set blank prices to average price of spec_score pool. Using a CTE allows the use of a subquery within the Update statement.
With cte as (Select spec_score, avg(price_rupee) as average_rupee, avg(price_usd) as average_usd
From laptops
Group by spec_score
Order by spec_score desc)

Update laptops
Set price_rupee = Case When price_rupee = 0 Then (select average_rupee from cte where laptops.spec_score = cte.spec_score) End,
price_usd = Case When price_usd = 0 Then (select average_usd from cte where laptops.spec_score = cte.spec_score) End
Where price_rupee = 0;

# For unspecified values, replace with 'Unknown'
Update laptops
Set display_type = Case When display_type = 'Display' Then 'Unknown' Else display_type End,
display_pixels = case when display_pixels = 'x px' Then 'Unknown' Else display_pixels End;

# Blank values in storage_only represent eMMC storage. Extract these values from the name_c column.
Update laptops
Set storage_only = replace(substring(name_c,locate('eMMc', name_c)-7,11),'/','') where name_c like "%eMMC%";

# Drop unnecessary columns
Alter table laptops
Drop Column img;

# Now let's do some quick EDA
# # BASIC BRAND METRICS
Select brand, count(*) total_products, round(avg(price_usd),0) avg_price_usd, round(avg(spec_score),0) avg_spec_score, sum(no_rates) total_ratings, 
round(avg(rating_100),1) avg_rating_score
From laptops
Group by brand
Order by brand;

# RANKING 10 MOST EXPENSIVE BRANDS.
With price_table as (Select brand, round(avg(price_usd),0) average_usd
From laptops
Group by brand),
ranking_price as (Select *, rank() over(order by average_usd desc) ranking
From price_table)

Select *
From ranking_price
Where ranking <=10;

# MOST USED RAM SIZES
Select *, rank() over (order by count desc) ranking
From (Select substring(ram,1,locate('GB',ram)+1) as memory, count(*) count
From laptops
Group by memory) memory_table;

# MOST USED SYSTEMS
Select *, rank() over (order by count desc) ranking
From (Select system_name, count(*) count
From laptops
Group by system_name) system_table;

# MOST USED DISPLAY SIZES
With displays as (select display_size, count(*) count
From laptops
Group by display_size)

Select *, rank() over(order by count desc) ranking
From displays;

# MOST USED DISPLAY PIXELS
With displays as (select display_pixels, count(*) count
From laptops
Group by display_pixels)

Select *, rank() over(order by count desc) ranking
From displays;

# MOST USED STORAGE
With storage_size as (select storage_only, count(*) count
From laptops
Group by storage_only)

Select *, rank() over(order by count desc) ranking
From storage_size;

# MOST USED PROCESSOR BRANDS
With p_brands as (select processor_brand, count(*) count
From laptops
Group by processor_brand)

Select *, rank() over(order by count desc) ranking
From p_brands;

# Export file as csv. When you export, save the file as CSV with semi-colon as the delimiter.
Select *
From laptops
Limit 10000;




