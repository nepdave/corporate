-- +goose Up
-- AddUp is executed when this migration is applied.
CREATE TABLE Departments (
    Department_ID SERIAL PRIMARY KEY,
    Dept_Name VARCHAR(100) NOT NULL UNIQUE,
    Office_Location VARCHAR(100)
);

CREATE TABLE Job_Titles (
    Title_ID SERIAL PRIMARY KEY,
    Title_Name VARCHAR(100) NOT NULL,
    Grade_Level INT,
    Min_Salary DECIMAL(12, 2),
    Max_Salary DECIMAL(12, 2)
);

CREATE TABLE Employees (
    Employee_ID SERIAL PRIMARY KEY,
    First_Name VARCHAR(50) NOT NULL,
    Last_Name VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE,
    Reports_To INT REFERENCES Employees(Employee_ID), -- Self-reference for hierarchy
    Hire_Date DATE NOT NULL,
    Termination_Date DATE, -- NULL means employee is active, otherwise captures the termination/resignation date
    Is_Active BOOLEAN NOT NULL DEFAULT TRUE -- Allows flagging employees as active/inactive for cases such as leave or termination
);

CREATE TABLE Employee_Departments (
    Employee_Department_ID SERIAL PRIMARY KEY,
    Employee_ID INT REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
    Department_ID INT REFERENCES Departments(Department_ID),
    Assigned_From DATE NOT NULL, -- Tracks when the employee was first placed in this department
    Assigned_To DATE -- Null if currently active, otherwise tracks when the assignment to this department ended
);

CREATE TABLE Salary_History (
    Salary_Log_ID SERIAL PRIMARY KEY,
    Employee_ID INT REFERENCES Employees(Employee_ID) ON DELETE CASCADE,
    Salary_Amount DECIMAL(12, 2) NOT NULL CHECK (Salary_Amount > 0),
    Change_Reason VARCHAR(255),
    Effective_Date DATE NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Pre-populate the Departments table
INSERT INTO Departments (Dept_Name, Office_Location) VALUES
('Executive Committee', 'Main Campus - Admin Building'),
('Human Resources', 'Main Campus - South Wing'),
('Software Engineering', 'Tech Campus - Block B'),
('Marketing', 'Main Campus - East Wing'),
('Admissions', 'Main Campus - West Wing');

-- Create or update view for current employee pay and assignment data
CREATE OR REPLACE VIEW Current_Employee_Pay AS
SELECT 
    e.Employee_ID,
    e.First_Name,
    e.Last_Name,
    COALESCE(d.Dept_Name, 'Multiple Departments') AS Dept_Name,
    t.Title_Name,
    s1.Salary_Amount AS Current_Salary,
    s1.Effective_Date AS Last_Raise_Date,
    m.Last_Name AS Manager_Name
FROM Employees e
LEFT JOIN (
    SELECT ed.Employee_ID, d.Dept_Name
    FROM Employee_Departments ed
    JOIN Departments d ON ed.Department_ID = d.Department_ID
    WHERE ed.Assigned_To IS NULL -- Currently active department assignment
) d ON e.Employee_ID = d.Employee_ID
LEFT JOIN Job_Titles t ON e.Title_ID = t.Title_ID
LEFT JOIN Salary_History s1 ON e.Employee_ID = s1.Employee_ID
LEFT JOIN Employees m ON e.Reports_To = m.Employee_ID
WHERE s1.Effective_Date = (
    SELECT MAX(s2.Effective_Date) 
    FROM Salary_History s2 
    WHERE s2.Employee_ID = e.Employee_ID
)
AND e.Is_Active = TRUE; -- Exclude inactive employees (e.g., those on leave)
-- +goose Down
-- AddDown is executed when this migration is rolled back.
DROP VIEW IF EXISTS Current_Employee_Pay;

DROP TABLE IF EXISTS Salary_History;
DROP TABLE IF EXISTS Employee_Departments;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Job_Titles;
DROP TABLE IF EXISTS Departments;
