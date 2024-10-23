select * from books
select * from branch
select * from employees
select * from issued_status
select * from return_status
select * from members

-- task
--Task 1. Create a New Book Record -- "978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')"
INSERT INTO books(isbn, book_title, category, rental_price, status, author, publisher) 
VALUES
('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')

--2: Update an Existing Member's Address
update members
set member_address = '127 Main St'
where member_id = 'C101';

--3: Delete a Record from the Issued Status Table -- Objective: Delete the record with issued_id = 'IS121' from the issued_status table.
delete from issued_status
where issued_id = 'IS121'

--4: Retrieve All Books Issued by a Specific Employee -- Objective: Select all books issued by the employee with emp_id = 'E101'.
select * 
from issued_status
where issued_emp_id = 'E101'

--Task 5: List Members Who Have Issued More Than One Book -- Objective: Use GROUP BY to find members who have issued more than one book.
select issued_emp_id, 
	count(issued_id) as total_book 
from issued_status
group by issued_emp_id
having count(issued_id) > 1

--6: Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt**
create table book_count as
select 
	b.isbn,
	b.book_title,
	count(iss.issued_id) as num_issued
from books as b
join 
issued_status as iss
on iss.issued_book_isbn = b.isbn
group by 1,2

select * from book_count

-- 7. Retrieve All Books in a Specific Category:
select * 
from books
where category = 'Fiction'

-- 8: Find Total Rental Income by Category:
select category, sum(rental_price) as income, count(*) 
from books
group by 1
order by 2 desc

-- 9.List Members Who Registered in the Last 180 Days:
select * from members
where reg_date >= current_date - interval '180 day'

-- 10. List Employees with Their Branch Manager's Name and their branch details:
select 
	e.*, b.manager_id, e2.emp_name as manager
from employees as e
join 
branch as b
on b.branch_id = e.branch_id
join
employees as e2
on b.manager_id = e2.emp_id

--11. Create a Table of Books with Rental Price Above a Certain Threshold 7USD:
create table booksp7
as
select * from books
where rental_price > 7

select * from booksp7

--12: Retrieve the List of Books Not Yet Returned
select 
	*
from issued_status as iss
LEFT join 
return_status as rs
on iss.issued_id = rs.issued_id
where rs.return_date is NULL

/* 13: Identify Members with Overdue Books Write a query to identify members who have overdue books (assume a 30-day return period). 
Display the member's_id, member's name, book title, issue date, and days overdue.
*/
select 
	m.member_id,
	m.member_name,
	b.book_title,
	iss.issued_date,
	rs.return_date,
	current_date - iss.issued_date as overdue
from issued_status as iss
join members as m
on m.member_id = iss.issued_member_id
join books as b
on b.isbn = iss.issued_book_isbn
LEFT join 
return_status as rs
on iss.issued_id = rs.issued_id
where 
	rs.return_date is null
	and
	(current_date - iss.issued_date) > 30
order by 1

/* 14: Update Book Status on Return
Write a query to update the status of books in the books table to "Yes" 
when they are returned (based on entries in the return_status table).
*/

create or replace procedure add_return_records(p_return_id VARCHAR(10), p_issued_id VARCHAR(10))
language plpgsql
as $$

declare
	v_isbn varchar(50);
	v_book_name varchar(80);
begin
	--inserting into return 
	insert into return_status(return_id, issued_id, return_date)
	values
	(p_return_id,p_issued_id,current_date);

	select 
		issued_book_isbn,
		issued_book_name
		into
		v_isbn,
		v_book_name
	from issued_status
	where issued_id = p_issued_id;
	
	update books
	set status = 'yes'
	where isbn = v_isbn;

	raise notice 'thanks for returning the book %', v_book_name;
end;
$$


call add_return_records('R135','IS135');

/* Task 15: Branch Performance Report
Create a query that generates a performance report for each branch, showing the number of books issued, 
the number of books returned, and the total revenue generated from book rentals.
*/

select 
	b.branch_id,
	count(iss.issued_id) as book_issued,
	count(rs.return_id) as books_return,
	sum(bk.rental_price) as revenue
from branch as b
join employees as e
on b.branch_id = e.branch_id
join issued_status as iss
on iss.issued_emp_id = e.emp_id
join books as bk
on bk.isbn = iss.issued_book_isbn
left join return_status as rs
on iss.issued_id = rs.issued_id
group by 1

/* 16: CTAS: Create a Table of Active Members
Use the CREATE TABLE AS (CTAS) statement 
to create a new table active_members containing members who have issued at least one book in the last 8 months.
*/
create table active_members
as
select * from members
where member_id in (
					select 
					distinct issued_member_id
					from issued_status
					where issued_date >= current_date - interval '8 month'
					)

select * from active_members

/*
Task 17: Find Employees with the Most Book Issues Processed
Write a query to find the top 3 employees who have processed the most book issues. 
Display the employee name, number of books processed, and their branch.
*/

select 
	e.emp_name,
	b.*,
	count(iss.issued_id) as book_process
from branch as b
join employees as e
on b.branch_id = e.branch_id
join issued_status as iss
on iss.issued_emp_id = e.emp_id
group by 1,2
order by book_process DESC
Limit 3

/* 18: Identify Members Issuing High-Risk Books
Write a query to identify members who have issued books less than twice with the status "damaged" in the books table. 
Display the member name, book title, and the number of times they've issued damaged books.
*/

select 
	m.member_name,
	iss.issued_book_name as book_title,
	count(iss.issued_id) as issued,
	rs.book_quality
from members as m
join issued_status as iss
on iss.issued_member_id = m.member_id
left join return_status as rs
on iss.issued_id = rs.issued_id
where rs.book_quality = 'Damaged'
group by 1,2,4
having 	count(iss.issued_id) < 2

/* Task 19: Stored Procedure Objective: Create a stored procedure to manage the status of books in a library system. 
Description: Write a stored procedure that updates the status of a book in the library based on its issuance. 

The procedure should function as follows: The stored procedure should take the book_id as an input parameter. 

The procedure should first check if the book is available (status = 'yes'). 

If the book is available, it should be issued, and the status in the books table should be updated to 'no'. 

If the book is not available (status = 'no'), 

the procedure should return an error message indicating that the book is currently not available. */

select * from books
select * from issued_status

create or replace procedure add_books(p_issued_id VARCHAR(10), p_issued_member_id VARCHAR(30), p_issued_book_isbn VARCHAR(30), p_issued_emp_id VARCHAR(10))
language plpgsql
as $$

declare
	v_status VARCHAR(10);

begin
	SELECT 
        status 
        INTO
        v_status
    FROM books
    WHERE isbn = p_issued_book_isbn;

	IF v_status = 'yes' THEN

        INSERT INTO issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
        VALUES
        (p_issued_id, p_issued_member_id, CURRENT_DATE, p_issued_book_isbn, p_issued_emp_id);

        UPDATE books
            SET status = 'no'
        WHERE isbn = p_issued_book_isbn;
		
		Raise notice 'book record success for isbn : %',p_issued_book_isbn;
	else 
		Raise notice 'your request is error for this isbn : %',p_issued_book_isbn;
	end if;
end;
$$


call add_books('IS155','C108','978-0-553-29698-2','E104')
"978-0-14-118776-1" --yes ""IS107"" ""C107"" ""E104""
"978-0-375-41398-8" --no "IS134" "C107" "E106"
select * from books
select * from issued_status
where issued_book_isbn = '978-0-14-118776-1'

/*  Create Table As Select (CTAS) Objective: Create a CTAS (Create Table As Select) query to identify overdue books and calculate fines.
Description: Write a CTAS query to create a new table that lists each member and the books they have issued but 
not returned within 30 days. The table should include: The number of overdue books. 
The total fines, with each day's fine calculated at $0.50. The number of books issued by each member. 
The resulting table should show: Member ID Number of overdue books Total fines
*/

select 
	m.member_id,
	count(iss.issued_id) as overdue_book,
	sum(
		case when current_date - issued_date >= 30
		then (current_date - issued_date - 30) * 0.5
		else 0
	end
	) as fines
from members as m
join issued_status as iss
on iss.issued_member_id = m.member_id
join books as bk
on bk.isbn = iss.issued_book_isbn
left join return_status as rs
on iss.issued_id = rs.issued_id
where rs.return_date is null
group by 1
order by fines desc
