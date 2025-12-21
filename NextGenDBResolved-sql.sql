-- NextGen Database Restoration & Analysis Queries

create database "NextGen_db" with template = template0 encoding = 'UTF8' locale_provider = libc locale = 'en-US';

-- \c NextGen_db;

create table public.department (
    department_id integer not null,
    department_name character varying(30),
    constraint department_pkey primary key (department_id)
);

create table public.employee (
    employee_id integer not null,
    first_name character varying(30) not null,
    last_name character varying(30) not null,
    job_title character varying(30),
    hire_date date,
    department_id integer,
    hire_year integer,
    hire_month integer,
    constraint employee_pkey primary key (employee_id),
    constraint employee_department_id_fkey foreign key (department_id) 
        references public.department(department_id)
);

create table public.attendance (
    attendance_id integer not null,
    employee_id integer,
    attendance_date date,
    attendance_status character varying(20),
    constraint attendance_pkey primary key (attendance_id),
    constraint attendance_employee_id_fkey foreign key (employee_id) 
        references public.employee(employee_id)
);

create table public.performance (
    performance_id integer not null,
    employee_id integer,
    performance_date date,
    performance_score numeric(2,1),
    department_id integer,
    constraint performance_pkey primary key (performance_id),
    constraint performance_employee_id_fkey foreign key (employee_id) 
        references public.employee(employee_id),
    constraint performance_department_id_fkey foreign key (department_id) 
        references public.department(department_id)
);

create table public.salary (
    salary_id integer not null,
    employee_id integer,
    salary_date date,
    salary_amount integer,
    department_id integer,
    constraint salary_pkey primary key (salary_id),
    constraint salary_employee_id_fkey foreign key (employee_id) 
        references public.employee(employee_id),
    constraint salary_department_id_fkey foreign key (department_id) 
        references public.department(department_id)
);

create table public.turnover (
    turnover_id integer,
    employee_id integer,
    turnover_date date,
    reason_for_leaving text,
    department_id integer,
    constraint turnover_employee_id_fkey foreign key (employee_id) 
        references public.employee(employee_id),
    constraint turnover_department_id_fkey foreign key (department_id) 
        references public.department(department_id)
);

-- employee retention analysis

-- a-1. top 5 longest serving employees
select 
    employee_id, 
    first_name, 
    last_name, 
    hire_date,
    age(current_date, hire_date) as years_of_service
from employee
order by years_of_service desc
limit 5;

-- a-2. turnover rate for each department
select
    d.department_id,
    d.department_name,
    count(e.employee_id) as total_employees,
    count(t.turnover_date) as employees_left,
    case 
        when count(e.employee_id) > 0 then
            round((count(t.turnover_date) * 100.0) / count(e.employee_id), 2)
        else 0 
    end as turnover_rate_percent
from employee e
join department d on e.department_id = d.department_id
left join turnover t on e.employee_id = t.employee_id
group by d.department_id, d.department_name
order by turnover_rate_percent desc;

-- a-3. which employees are at risk of leaving based on their performance
select
    e.employee_id,
    e.first_name,
    e.last_name,
    e.job_title,
    d.department_name,
    round(avg(p.performance_score), 2) as avg_performance
from employee e
join performance p on e.employee_id = p.employee_id
join department d on e.department_id = d.department_id
where p.performance_score <= 3.0
group by e.employee_id, e.first_name, e.last_name, e.job_title, d.department_name
having round(avg(p.performance_score), 2) <= 3.0
order by avg_performance asc;

-- a-4. what are the main reasons employees are leaving the company
select 
    reason_for_leaving,
    count(*) as employees_left,
    round((count(*) * 100.0) / (select count(*) from turnover), 2) as percentage
from turnover
where reason_for_leaving is not null
group by reason_for_leaving
order by employees_left desc;

-- performance analysis

-- b-1. how many employees have left the company
select count(distinct employee_id) as employees_left
from turnover;

-- b-2. how many employees have a performance score of 5.0 / below 3.5
select
    count(distinct case when p.performance_score = 5.0 then p.employee_id end) as count_perfect_score,
    count(distinct case when p.performance_score < 3.5 then p.employee_id end) as count_low_performance
from performance p;

-- b-3. which department has the most employees with a performance of 5.0 / below 3.5
select 
    d.department_id, 
    d.department_name,
    count(distinct case when p.performance_score = 5.0 then e.employee_id end) as perfect_scores,
    count(distinct case when p.performance_score < 3.5 then e.employee_id end) as low_scores,
    count(distinct e.employee_id) as total_employees
from employee e
join performance p on e.employee_id = p.employee_id
join department d on e.department_id = d.department_id
group by d.department_id, d.department_name
order by perfect_scores desc, low_scores asc;

-- b-4. what is the average performance score by department
select 
    d.department_name,
    count(distinct e.employee_id) as employee_count,
    round(avg(p.performance_score), 2) as avg_performance_score
from department d
join employee e on e.department_id = d.department_id
join performance p on e.employee_id = p.employee_id
group by d.department_name
order by avg_performance_score desc;

-- salary analysis

-- c-1. total salary expense
select
    sum(salary_amount) as total_salary_expense,
    count(distinct employee_id) as employees_with_salary_data
from salary;

-- c-2. average salary by job title
select 
    e.job_title,
    count(distinct e.employee_id) as employee_count,
    round(avg(s.salary_amount), 2) as average_salary
from employee e
join salary s on e.employee_id = s.employee_id
group by e.job_title
order by avg(s.salary_amount) desc;

-- c-3. how many employees make > 80k
select
    count(distinct employee_id) as high_earners,
    case 
        when (select count(distinct employee_id) from salary) > 0 then
            round((count(distinct employee_id) * 100.0) / 
                  (select count(distinct employee_id) from salary), 2)
        else 0 
    end as percentage_of_workforce
from salary 
where salary_amount > 80000;

-- c-4. how does performance correlate with salary
select 
    d.department_name,
    count(distinct e.employee_id) as employee_count,
    round(avg(p.performance_score), 2) as avg_performance,
    round(avg(s.salary_amount), 2) as avg_salary,
    round(corr(p.performance_score, s.salary_amount)::numeric, 3) as correlation_coefficient
from employee e
join department d on e.department_id = d.department_id
join performance p on e.employee_id = p.employee_id
join salary s on e.employee_id = s.employee_id
where p.performance_score is not null 
  and s.salary_amount is not null
group by d.department_name
order by avg_performance desc;

-- additional analysis queries

-- overall company performance metrics
select 
    count(distinct e.employee_id) as total_employees,
    count(distinct t.employee_id) as employees_left,
    case 
        when count(distinct e.employee_id) > 0 then
            round((count(distinct t.employee_id) * 100.0) / count(distinct e.employee_id), 2)
        else 0 
    end as overall_turnover_rate,
    round(avg(p.performance_score), 2) as avg_company_performance,
    round(avg(s.salary_amount), 0) as avg_company_salary
from employee e
left join turnover t on e.employee_id = t.employee_id
left join performance p on e.employee_id = p.employee_id
left join salary s on e.employee_id = s.employee_id;

-- department performance dashboard
select 
    d.department_name,
    count(distinct e.employee_id) as total_employees,
    count(distinct t.employee_id) as employees_left,
    round((count(distinct t.employee_id) * 100.0) / 
          nullif(count(distinct e.employee_id), 0), 2) as turnover_rate,
    round(avg(p.performance_score), 2) as avg_performance,
    round(avg(s.salary_amount), 0) as avg_salary
from department d
left join employee e on d.department_id = e.department_id
left join turnover t on e.employee_id = t.employee_id
left join performance p on e.employee_id = p.employee_id
left join salary s on e.employee_id = s.employee_id
group by d.department_name
order by avg_performance desc;

create index idx_employee_department on employee(department_id);
create index idx_employee_hire_date on employee(hire_date);
create index idx_performance_employee on performance(employee_id);
create index idx_performance_score on performance(performance_score);
create index idx_salary_employee on salary(employee_id);
create index idx_salary_amount on salary(salary_amount);
create index idx_turnover_employee on turnover(employee_id);
create index idx_attendance_employee on attendance(employee_id);