
# Bash Shell Script Database Management System (DBMS)

## Description
This project is a **Command-Line Interface (CLI) DBMS** written entirely in Bash.  
It allows users to create databases, manage tables, and perform basic SQL-like operations without a real database engine.

This Final Project is part of the **ITI Open Source Development 9-month track**, for the course **Red Hat Administration I**.

---

## Features

### Database Operations
- Create Database
- List Databases
- Connect to Database
- Drop Database

### Table Operations
- Create Table (with column names, datatypes, and primary key)
- List Tables
- Drop Table
- Insert Into Table (with datatype and primary key validation)
- Select From Table (pretty printed)
- Delete From Table (by primary key)
- Update Table (by primary key, with type and primary key validation)

---

## Table Storage

- Each database is a folder inside `databases/`.
- Each table is a text file inside its database folder.
- Table file format:
  1. First line: column names (comma-separated)
  2. Second line: datatypes (comma-separated, e.g., int,string)
  3. Third line: primary key column index (0-based)
  4. Following lines: data rows

---

## How to Run

1. Make the script executable:

```bash
chmod +x dbms.sh
```

2. Run the DBMS:

```bash
./dbms.sh
```

3. Use the menu to navigate through databases and tables.

---

## Example Workflow

1. Create a database `school`.  
2. Connect to `school`.  
3. Create a table `students` with columns: `id(int, PK)`, `name(string)`, `age(int)`.  
4. Insert rows into `students`.  
5. Select from `students` to view data.  
6. Update or delete rows as needed.  

---

## Author
**Fares Hazem**
