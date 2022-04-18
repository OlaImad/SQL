# FROM THE TV SERIES REVIEWS DATABASE PRACTISE PROBLEMS

select title, rating from series
join reviews
on series.id = reviews.series_id
order by title;

select title, avg(rating) as  avg_rating from series
join reviews 
on series.id = reviews.series_id
GROUP by series.title
order by avg(rating);

select first_name, last_name, rating  from reviewers
join reviews 
on reviewers.id = reviews.reviewer_id;

select title as unreviewed_series from series
left join reviews 
on series.id = reviews.series_id
where rating is null ;

select genre, round(avg(rating),2) as avg_rating from series 
join reviews
on series.id = reviews.series_id
group by series.genre
order by avg_rating desc;

select first_name,last_name, ifnull(count(rating),0) as count,ifnull(max(rating),0) as max_raing,ifnull(min(rating),0) as min_rating,ifnull(round(avg(rating),2),0) as avg_rating, 
# if(count(rating) >=1, 'active','inactive') as status
CASE
when reviews.id is null then 'inactive'
else 'active'
end as 'status'
from reviewers
left join reviews
on reviewers.id = reviews.reviewer_id
group by first_name, last_name
order by avg(rating) desc;

select series.title, reviews.rating, concat(first_name,' ',last_name) as reviewer from
series
join reviews
on series.id = reviews.series_id
join  reviewers
on reviews.reviewer_id = reviewers.id
order by series.title;


# ==================== INSATGRAM CLONE =========================================

--  5 oldest users
select username from users order by created_at limit 5;

-- what days of the week most user subscribed at
select dayname(created_at) as day, count(*) as num_of_users from users 
group by day 
order by num_of_users desc;

-- users who have never posted a photo
select username from users
left join photos
on users.id = photos.user_id
where photos.id is null;

-- who got the most likes on a single photo
select photos.id,photos.image_url,count(*)  as total ,users.username  from photos
join likes 
on photos.id = likes.photo_id
join users 
on photos.user_id = users.id
group by photos.id
order by total desc limit 1 ;

-- How many times does he average user posts
select (select count(*) as total_photos from photos)/
(select count(*) as total_users from users) as avg;

-- what are the top 5 most commonly used hashtags 
select count(*) as total, tag_name from photo_tags
join tags 
on tags.id = photo_tags.tag_id
group by tag_id
order by total desc limit 5;

-- find users who have liked every single photo on the site 
select users.username, likes.user_id, count(*) as total_likes from likes
join users
on users.id = likes.user_id
group by likes.user_id
having total_likes = (select count(*) from photos);

-- Triggers prevent insert if age < 18
delimiter $$
CREATE TRIGGER must_be_adult
before insert on users for each row
BEGIN
if new.age < 18 then
signal sqlstate '45000'
set message_text = 'Must be an adult';
end if;
end;
$$
delimiter ;

-- triggers preventing self-follows
delimiter $$

create trigger prevent_self_follows
before insert on follows for each row
BEGIN
if new.follower_id = new.followee_id
then signal sqlstate '45000'
set message_text = "You can't follow yourself";
end if;
END;
$$ 
Delimiter ;

-- Triggers logging unfollows 
Delimiter $$
CREATE TRIGGER capture_unfollows
after delete on follows for each row
BEGIN
insert into unfollows (follower_id, followee_id) values (old.follower_id, old.followee_id)
END;
$$
Delimiter ;

