
-- 1. Fetch all the paintings which are not displayed on any museums?

select * from public.work where museum_id is null;


--2. Are there museuems without any paintings?

select * from public.museum where not exists (select museum_id from public.work);


-- 3.  How many paintings have an asking price of more than their regular price? 

select count(*) from public.product_size
where sale_price > regular_price;


-- 4.  Identify the paintings whose asking price is less than 50% of its regular price

select * from public.product_size where sale_price < regular_price/2;


-- 5.  Which canva size costs the most?

select cs.label as canva, ps.sale_price
	from  (
		  select *
		  , rank() over(order by sale_price desc) as rnk 
		  from public.product_size
		  ) ps
inner join public.canvas_size cs on cs.size_id::text = ps.size_id
where ps.rnk = 1;



-- 6.  Delete duplicate records from work, product_size, subject and image_link tables
delete from public.work 
where ctid not in (
select min(ctid) from public.work group by work_id );

delete from public.product_size 
where ctid not in (
select min(ctid) from public.product_size group by work_id );

delete from public.subject 
where ctid not in (
select min(ctid) from public.subject group by work_id );

delete from public.image_link 
where ctid not in (
select min(ctid) from public.image_link group by work_id );


-- 7. Identify the museums with invalid city information in the given dataset

select * from public.museum where city  ~ '^[0-9]';


-- 8. Museum_Hours table has 1 invalid entry. Identify it and remove it.

delete from public.museum_hours where ctid not in (
select min(ctid) from public.museum_hours group by museum_id, day);


-- 9. Fetch the top 10 most famous painting subject
with cte as (
	select s.subject, count(1) as no_of_painting,
	rank() over(order by count(1) desc) as rnk
	from public.subject s
	join public.work w on w.work_id = s.work_id
	group by 1
) select * from cte where rnk <= 10;


-- 10.  Identify the museums which are open on both Sunday and Monday. Display museum name, city.

select distinct m.name as museum_name, m.city, m.state,m.country
from public.museum_hours mh 
join public.museum m on m.museum_id=mh.museum_id
where day='Sunday'
and exists (select 1 from public.museum_hours mh2 
		     where mh2.museum_id=mh.museum_id 
			 and mh2.day='Monday');
			 

-- 11. How many museums are open every single day?

with cte as (
select distinct museum_id, count(day) as no_of_days from public.museum_hours group by 1
) select count(*) from cte where no_of_days = 7;



-- 12. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

select distinct w.museum_id, m.name, count(distinct work_id) as no_of_painintgs
from public.work w
inner join public.museum m on w.museum_id = m.museum_id
where w.museum_id is not null
group by 1,2 order by 3 desc limit 5;


-- 13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select distinct w.artist_id, a.full_name,
count(distinct work_id) as work_done 
from public.work w 
inner join public.artist a 
on w.artist_id = a.artist_id
group by w.artist_id, a.full_name 
order by 3 desc 
limit 5;


-- 14. Display the 3 least popular canva sizes;

select label,ranking,no_of_paintings
from (
	select cs.size_id,cs.label,count(1) as no_of_paintings
	, dense_rank() over(order by count(1) ) as ranking
	from public.work w
	join public.product_size ps on ps.work_id=w.work_id
	join public.canvas_size cs on cs.size_id::text = ps.size_id
	group by cs.size_id,cs.label) x
where x.ranking<=3;


-- 15.  Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
with cte as (
select mh.museum_id, m.name, m.city, m.state
,to_timestamp(open, 'HH, MI AM') as open_time
,to_timestamp(close, 'HH, MI PM') as close_time
,to_timestamp(close, 'HH, MI AM') - to_timestamp(open, 'HH, MI PM') as open_duration
,rank() over(order by to_timestamp(close, 'HH, MI AM') - to_timestamp(open, 'HH, MI PM') desc) as rnk
from public.museum_hours mh
inner join public.museum m
on mh.museum_id = m.museum_id
)
select museum_id,name, city, state, open_duration
from cte where rnk=1;


-- 16. Which museum has the most no of most popular painting style?

with 
pop_style as 
	(select style
	,rank() over(order by count(1) desc) as rnk
	from public.work
	group by style),
cte as
	(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
	,rank() over(order by count(1) desc) as rnk
	from public.work w
	join public.museum m on m.museum_id=w.museum_id
	join pop_style ps on ps.style = w.style
	where w.museum_id is not null
	and ps.rnk=1
	group by w.museum_id, m.name,ps.style)
select museum_name,style,no_of_paintings
from cte 
where rnk=1;


-- 17. Identify the artists whose paintings are displayed in multiple countries
with cte as (
select distinct a.full_name as artist
, m.country
from public.work w
join public.artist a on a.artist_id=w.artist_id
join public.museum m on m.museum_id=w.museum_id
)
select artist,count(1) as no_of_countries
from cte
group by artist
having count(1)>1
order by 2 desc;


-- 18. Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. 
-- If there are multiple value, seperate them with comma.

with 
cte_country as (
	select country, count(1)
	,rank() over( order by count(1) desc) as rnk1
	from public.museum
	group by 1
),
cte_city as (
	select city, count(1)
	,rank() over( order by count(1) desc) as rnk2
	from public.museum
	group by 1
) 
select string_agg(distinct country, ', ') as country
, string_agg(city, ', ') as city
from cte_country inner join cte_city
on cte_country.rnk1 = cte_city.rnk2
where rnk1=1 and rnk2=1;


-- 19. Identify the artist and the museum where the most expensive and least expensive painting is placed. 
-- Display the artist name, sale_price, painting name, museum name, museum city and canvas label

with cte as (
select a.artist_id, a.full_name as artist_name, ps.sale_price, w.name as painting_name, 
m.name as museum_name, m.city as museum_city,cs.label as canvas_label,
row_number() over(order by ps.sale_price asc) row_asc,
row_number() over(order by ps.sale_price desc) row_desc
from public.artist a
inner join public.work w
on a.artist_id = w.artist_id
inner join public.museum m
on w.museum_id  = m.museum_id
inner join public.product_size ps
on w.work_id = ps.work_id
inner join public.canvas_size cs
on ps.size_id ::text = cs.size_id ::text
order by 3 desc
)
select * from cte
where row_asc = 1 or row_desc = 1;



-- 20. Which country has the 5th highest no of paintings?

with cte as (
select m.country, count(1) as no_of_Paintings
,rank() over(order by count(1) desc) as rnk
from public.work w
inner join public.museum m
on w.museum_id = m.museum_id
group by m.country
)
select country, no_of_paintings from cte
where rnk <= 5;


-- 21. Which are the 3 most popular and 3 least popular painting styles?

with cte as (
select style, count(1) as cnt
,rank() over(order by count(1) desc) rnk
,count(1) over() as no_of_records
from public.work
where style is not null
group by style
)
select style
,case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks
from cte where rnk <= 3
or rnk > no_of_records - 3;


-- 22. Which artist has the most no of Portraits paintings outside USA?. 
-- Display artist name, no of paintings and the artist nationality.

select full_name as artist_name, nationality, no_of_paintings
from (
	select a.full_name, a.nationality
	,count(1) as no_of_paintings
	,rank() over(order by count(1) desc) as rnk
	from public.work w
	inner join public.artist a on a.artist_id=w.artist_id
	inner join public.subject s on s.work_id=w.work_id
	inner join public.museum m on m.museum_id=w.museum_id
	where s.subject='Portraits'
	and m.country != 'USA'
	group by a.full_name, a.nationality
	) x
where rnk = 1;

