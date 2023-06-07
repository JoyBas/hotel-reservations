CREATE DATABASE hotel;
USE hotel;


-- dimension tables
CREATE TABLE dim_room (
room_id INT NOT NULL PRIMARY KEY,
room_type INT NOT NULL
);


CREATE TABLE dim_guest (
guest_id INT NOT NULL PRIMARY KEY,
num_adult INT NOT NULL, 
num_children INT NULL DEFAULT 0,
repeated_guest INT NULL 
);


CREATE TABLE dim_date (
date_id INT NOT NULL PRIMARY KEY,
arrival_date INT NOT NULL,
arrival_month INT NOT NULL,
arrival_year INT NOT NULL,
lead_time INT NOT NULL
);


CREATE TABLE dim_booking (
booking_id INT NOT NULL PRIMARY KEY,
num_weekend_night INT NOT NULL,
num_weekday_night INT NOT NULL,
booking_status VARCHAR(15) 
);


-- TRIM(booking_status column) in the dim_booking table
UPDATE dim_booking
SET booking_status = TRIM(Replace(Replace(Replace(booking_status,'\t',''),'\n',''),'\r',''));


CREATE TABLE hotel_fact (
hotel_room_id INT,
hotel_guest_id INT,
hotel_date_id INT,
hotel_booking_id INT,
average_price FLOAT(2) NOT NULL
);
	
-- inserting data into tables

-- to load data into dim_room table
LOAD DATA INFILE "C:\\Users\\joyus\\Downloads\\hotel_data\\dim_room.csv"
INTO TABLE dim_room
FIELDS TERMINATED BY ','
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

SELECT * FROM dim_room;

-- to load data into dim_guest table
LOAD DATA INFILE "C:\\Users\\joyus\\Downloads\\hotel_data\\dim_guest.csv"
INTO TABLE dim_guest
FIELDS TERMINATED BY ','
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

SELECT * FROM dim_guest;

-- to load data into dim_date table
LOAD DATA INFILE "C:\\Users\\joyus\\Downloads\\hotel_data\\dim_date.csv"
INTO TABLE dim_date
FIELDS TERMINATED BY ','
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

SELECT * FROM dim_date;

-- to load data into booking table
LOAD DATA INFILE "C:\\Users\\joyus\\Downloads\\hotel_data\\dim_booking.csv"
INTO TABLE dim_booking
FIELDS TERMINATED BY ','
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

SELECT * FROM dim_booking;

-- to load data into hotel_fact table
LOAD DATA INFILE "C:\\Users\\joyus\\Downloads\\hotel_data\\hotel_fact.csv"
INTO TABLE hotel_fact
FIELDS TERMINATED BY ','
ENCLOSED BY '"' 
LINES TERMINATED BY '\n';

SELECT * FROM hotel_fact;

-- add foreign keys to hotel_fact

-- room
ALTER TABLE hotel_fact
ADD CONSTRAINT fk_hotel_room
FOREIGN KEY (hotel_room_id)
REFERENCES dim_room(room_id);

-- guest
ALTER TABLE hotel_fact
ADD CONSTRAINT fk_hotel_guest
FOREIGN KEY (hotel_guest_id)
REFERENCES dim_guest(guest_id);

-- date
ALTER TABLE hotel_fact
ADD CONSTRAINT fk_hotel_date
FOREIGN KEY (hotel_date_id)
REFERENCES dim_date(date_id);

-- booking
ALTER TABLE hotel_fact
ADD CONSTRAINT fk_hotel_booking
FOREIGN KEY (hotel_booking_id)
REFERENCES dim_booking(booking_id);


-- Queries
-- GROUP BY / HAVING
-- calculate the average of the room prices per month > 100
SELECT d.arrival_month, ROUND(AVG(h.average_price), 2) AS monthly_average
FROM dim_date d 
INNER JOIN hotel_fact h
ON d.date_id = h.hotel_date_id
GROUP BY d.arrival_month
HAVING monthly_average > 100
ORDER BY monthly_average;


-- SUBQUERIES
-- 1
-- number of reservations vs cancellation for different years
SELECT * FROM
(SELECT d.arrival_year, COUNT(b.booking_status) AS reserved       -- subquery
FROM dim_booking b
INNER JOIN dim_date d
ON b.booking_id = d.date_id
GROUP BY d.arrival_year) AS A
INNER JOIN
(SELECT d.arrival_year, COUNT(b.booking_status) AS canceled       -- subquery
FROM dim_booking b
INNER JOIN dim_date d
ON b.booking_id = d.date_id
WHERE b.booking_status = 'Canceled'
GROUP BY d.arrival_year) AS B
ON A.arrival_year = B.arrival_year;


-- skip
-- 2
-- number of reservations versus cancellations for different room types

SELECT * FROM
(SELECT r.room_type, COUNT(r.room_id) as reserved             -- subquery
FROM dim_room r
GROUP BY r.room_type) AS A
LEFT JOIN
(SELECT r.room_type, COUNT(r.room_type) as canceled           -- subquery  
FROM dim_room r
INNER JOIN dim_booking b
ON r.room_id = b.booking_id
WHERE booking_status = 'Canceled'
GROUP BY r.room_type) AS B
ON A.room_type = B.room_type
ORDER BY A.reserved DESC;


-- 3
-- looking at the booking status(canceled or not canceled) based on the lead time
-- lead_time: the day the room was reserved prior to check-in

SELECT * FROM

(SELECT d.lead_time, COUNT(d.lead_time) AS lead_count, b.booking_status     -- subquery
FROM dim_date d
INNER JOIN dim_booking b
ON d.date_id = b.booking_id
WHERE b.booking_status = 'Not_Canceled'
GROUP BY d.lead_time
ORDER BY lead_count DESC) AS A

INNER JOIN

(SELECT d.lead_time, COUNT(d.lead_time) AS lead_count, b.booking_status      -- subquery
FROM dim_date d
INNER JOIN dim_booking b
ON d.date_id = b.booking_id
WHERE b.booking_status = 'Canceled'
GROUP BY d.lead_time
ORDER BY lead_count DESC) AS B
ON A.lead_time = B.lead_time;
-- most guests booked on the day they arrived at the hotel


-- VIEWS
-- 1
-- to view room 1 reservations only
CREATE OR REPLACE VIEW room_1_view AS
SELECT * 
FROM dim_room 
WHERE room_type = 1
WITH CHECK OPTION;

-- to test, try inserting any other room type other than 1
INSERT INTO room_1_view
(room_id, room_type)
VALUES
(401, 4);

-- to check
SELECT * FROM dim_room;


-- 2
-- a view that shows the count of different room types, arrival month/year, and their average prices

CREATE OR REPLACE VIEW room_date_average
AS
SELECT 
	r.room_type, d.arrival_month, d.arrival_year,
    COUNT(r.room_type) AS count_room,
    ROUND(AVG(h.average_price), 2) AS average_price
FROM dim_room r, hotel_fact h, dim_date d
WHERE r.room_id = h.hotel_room_id
AND h.hotel_room_id = d.date_id
GROUP BY r.room_type, d.arrival_month, d.arrival_year
ORDER BY count_room DESC, r.room_type;

-- to query the view
-- in which month and year was room type 1 reserved the most
SELECT room_type, arrival_month, arrival_year, count_room
FROM room_date_average
WHERE room_type = 1
ORDER BY count_room DESC
LIMIT 1;


-- FUNCTIONS

-- 1
-- determine the number of reservations the hotel had in different months/seasons
DELIMITER //
CREATE FUNCTION seasons(
    arrival_month INT
) 
RETURNS VARCHAR(10) #should return something /displays output
DETERMINISTIC
BEGIN
    DECLARE season_status VARCHAR(10);
    IF arrival_month IN (1, 2, 3) THEN 
        SET season_status = 'Winter';
    ELSEIF arrival_month IN (4, 5, 6) THEN
        SET season_status = 'Spring';
    ELSEIF arrival_month IN (7, 8, 9) THEN
        SET season_status = 'Summer';
	ELSEIF arrival_month IN (10, 11, 12) THEN
        SET season_status = 'Autumn';
    END IF;
    RETURN (season_status);
END//
DELIMITER ;


-- using the seasons function
-- find the number of reservations made by guests in different months/seasons
SELECT 
	d.arrival_month AS Month, 
    COUNT(d.arrival_month) AS Number_Of_Guests, 
    seasons(d.arrival_month) AS Seasons
FROM dim_date d
GROUP BY Month
ORDER BY Number_Of_Guests DESC;


-- 2
-- which group of people happen to cancel their reservations the most(those with or without children)?

DELIMITER //
CREATE FUNCTION with_without_kids(
    num_children INT
) 
RETURNS VARCHAR(15) #should return something /displays output
DETERMINISTIC
BEGIN
DECLARE with_kids VARCHAR(15);
	IF num_children = 0 THEN 
        SET with_kids = 'No';
    ELSEIF num_children > 0 THEN
        SET with_kids = 'Yes';
    END IF;
    RETURN (with_kids);
END//
DELIMITER ;

-- using the function
SELECT 
	b.booking_status,
	with_without_kids(num_children) AS kid_status, 
    COUNT(with_without_kids(num_children)) AS 'Number of Children'
FROM dim_booking b
INNER JOIN dim_guest g
ON b.booking_id = g.guest_id
WHERE b.booking_status = 'Canceled'
GROUP BY kid_status;
-- most people who canceled their reservations were with no kids


-- STORED PROCEDURES
-- 1
-- calculate the total average_price per year (no parameters)
DELIMITER //
CREATE PROCEDURE total_price_per_year()
BEGIN
	SELECT d.arrival_year, ROUND(SUM(average_price),2) AS total_average_price
	FROM dim_date d
	INNER JOIN hotel_fact h
	ON d.date_id = h.hotel_date_id
	GROUP BY d.arrival_year
;
END //
DELIMITER ;
 
CALL total_price_per_year();


-- 2
-- stored procedure with a year as the parameter, it calculates the percentage of cancellation for that year
DELIMITER //
CREATE PROCEDURE yearly_percentage_canceled(
IN year INT
)
BEGIN
	SELECT
		COUNT(*) * 100.0 / 
		(SELECT count(*) 
        FROM dim_booking b
		INNER JOIN dim_date d
		ON b.booking_id = d.date_id
		GROUP BY d.arrival_year
		HAVING d.arrival_year = year) as 'Percentage canceled'
	FROM dim_booking b
	INNER JOIN dim_date d
	ON b.booking_id = d.date_id
	WHERE b.booking_status = 'Canceled'
	AND d.arrival_year = year;
END //
DELIMITER ;

CALL yearly_percentage_canceled(2017); -- results in percentage


-- TRIGGERS
-- to ensure only the available room_types are entered in the dim_room table, set to zero if not in the list
DELIMITER //  
CREATE TRIGGER before_insert_room_type 
BEFORE INSERT ON dim_room FOR EACH ROW  
BEGIN  
IF NEW.room_type NOT IN (1, 2, 4, 5, 6, 7) THEN SET NEW.room_type = 0;  
END IF;  
END // 
 
-- to demonstrate
INSERT INTO dim_room
(room_id, room_type) 
VALUES    
(401, 23); 

-- to delete the new row that was added
DELETE FROM dim_room 
WHERE room_id = 401;


-- Other Example Queries

-- which year had the most reservations?
SELECT COUNT(date.arrival_year), date.arrival_year
FROM dim_date date
GROUP BY arrival_year
ORDER BY arrival_year DESC
LIMIT 1;


-- how many children(guests) checked in without adults?
SELECT COUNT(*)
FROM dim_guest g, dim_room r
WHERE g.guest_id = r.room_id
AND g.num_children > 0
AND g.num_adult = 0;


-- were most guests repeat guests? -- 0:no, 1:yes
SELECT g.repeated_guest, COUNT(g.guest_id)
FROM dim_guest g
GROUP BY g.repeated_guest;
-- most guests were one-time guests

-- Further questions to explore
-- calculate the total of each room side by side with the total of the hotel


















