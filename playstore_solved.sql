SELECT COUNT(*) FROM projects.playstore;
truncate playstore;
select * from playstore;

load data  infile "C:/playstore.csv"
into table playstore
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;

-- solving the case study --
-- 1. You're working as a market analyst for a mobile app development company. 
-- Your task is to identify the most promising categories (TOP 5) for launching new free apps based on their average ratings. 
select 
	Category,round(AVG(Rating),2) as "avg_rating" 
from playstore
where Type="Free"
group by 1
order by 2 desc
limit 5;

-- 2. As a business strategist for a mobile app company, your objective is to pinpoint the three categories that generate the most revenue from paid apps. 
-- This calculation is based on the product of the app price and its number of installations
select Category, round(sum(Price*Installs),2) as "revenue" from playstore
where Type="Paid"
group by 1
order by 2 desc
limit 3;

-- 3. As a data analyst for a gaming company, you're tasked with calculating the percentage of games within each category. 
-- This information will help the company understand the distribution of gaming apps across different categories 
select 
	Category, Count(*) as "cnt",round(COUNT(*)*100/(select count(*) from playstore),2) as "%" 
from playstore
group by 1
order by 2 desc;

-- 4. As a data analyst at a mobile app-focused market research firm you’ll recommend whether the company should develop paid or free apps for each category based on the ratings of that category.
with t1 as (select Category, round(avg(rating),2) as "Paid" from playstore where type="Paid" group by 1),
t2 as (select Category, round(avg(rating),2) as "Free" from playstore where type="Free" group by 1)

select *, case when k.Paid>k.Free then "develop Paid apps" else "develop Free apps" end as "decision" from
(select a.Category, Paid, Free from t1 a 
inner join t2 b
on a.Category=b.Category) k;

-- 5. Suppose you're a database administrator your databases have been hacked and hackers are changing price of certain apps on the database, 
-- it is taking long for IT team to neutralize the hack, however you as a responsible manager don’t want your data to be changed, 
-- do some measure where the changes in price can be recorded as you can’t stop hackers from making changes

create table play as select * from playstore;   -- making duplicate table to perform updates
create table price_changelog (					-- where the updates will be recorded
    app VARCHAR(255),
    old_price decimal(10,2),
    new_price decimal(10,2),
    operation_type varchar(25),
    operation_date timestamp
);

-- cretaing the TRIGGER --
DELIMITER //
CREATE TRIGGER price_change_hack
AFTER UPDATE
ON play
FOR EACH ROW
BEGIN
    INSERT INTO price_changelog(app, old_price, new_price, operation_type, operation_date) 
    VALUES (NEW.app, OLD.price, NEW.price, 'update', CURRENT_TIMESTAMP);
END //
DELIMITER ;



update play
set price=0
where Type="Paid";
select * from price_changelog;

SHOW TRIGGERS;

-- 6. Your IT team have neutralized the threat; however, hackers have made some changes in the prices, 
-- but because of your measure you have noted the changes, now you want correct data to be inserted into the database again.
select * from play;

drop trigger price_change_hack;
update play as a
join price_changelog b
on a.App=b.App
set a.price=b.old_price;

select * from play		-- checking
where Type="Paid";

-- 7. As a data person you are assigned the task of investigating the correlation between two numeric factors: app ratings and the quantity of reviews.
-- corr = sum((x-x')(y-y'))/sqrt(sum((x-x')^2)*sum((y-y')^2))
set @x=(select avg(Rating) from playstore)
set @y=(select avg(Reviews) from playstore);
with cte as 
	(select *, (rat*rat) as "sqr_x", (rev*rev) as "sqr_y" from 
	(select Rating, round((Rating-@x),2) as 'rat', Reviews, round((Reviews-@y),2) as "rev" from playstore) k
)
select @numerator:=sum(rat*rev), @deno_1:=sum(sqr_x), @deno_2:=sum(sqr_y) from cte;
select round(@numerator/sqrt(@deno_1*@deno_2),2) as "corr_coefficient";

-- 8. Your boss noticed  that some rows in genres columns have multiple genres in them, which was creating issue when developing the 
-- recommender system from the data he/she assigned you the task to clean the genres column and make two genres out of it, rows that have only one genre will have other column as blank. 
select  Genres, 
	case when Genres =substring_index(Genres,";",-1) then NULL else substring_index(Genres,";",-1) end as "Genre_2"  from playstore;
    -- Add the new column
ALTER TABLE playstore
ADD COLUMN Genre_2 VARCHAR(255) AFTER Genres;

-- Update the new column with the desired values
UPDATE playstore
SET Genre_2 = CASE WHEN Genres = SUBSTRING_INDEX(Genres, ";", -1) THEN NULL ELSE SUBSTRING_INDEX(Genres, ";", -1) END;
select * from playstore;

-- 9.Your senior manager wants to know which apps are not performing as par in their particular category, however he is not interested in 
-- handling too many files or list for every  category and he/she assigned  you with a task of creating a dynamic tool 
-- where he/she  can input a category of apps he/she  interested in  and your tool then provides real-time feedback 
-- by displaying apps within that category that have ratings lower than the average rating for that specific category.

call check_app_performance('business');


-- 10. Calculate the average rating of apps in each category, where the rating is adjusted based on the number of installations. 
-- The adjustment factor is defined as the square root of the number of installations. 
-- Write a user-defined function to calculate the adjusted rating, and then use it to find the average adjusted rating for each category.
--		query to find adjusted_rating withon each category --
select Category,
	ROUND(AVG(adjusted_rating(Rating, Installs)),2) from playstore
  GROUP BY 1  