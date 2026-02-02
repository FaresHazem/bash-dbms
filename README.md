# Bash DBMS: Hybrid CLI & GUI Database System

[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)](https://www.linux.org/)

A lightweight, robust Database Management System written entirely in Bash. This project implements a relational-like structure using the flat-file system, featuring a **Hybrid Interface** that automatically switches between a terminal-based menu and a Graphical User Interface (GUI) via Zenity.

This project was developed as part of the **ITI Open Source Development 9-month track** for the **Red Hat Administration I** course.

---

## 🚀 Features

### 🖥️ Dual-Mode Interface
- **Graphical Mode:** Uses `zenity` for dialogs, lists, and input forms.
- **Terminal Mode:** Fallback to a clean, menu-driven CLI if Zenity is unavailable or preferred.
- **UI Abstraction:** A single core logic engine powers both interfaces.

### 📊 Database Operations
- **Management:** Create, List, and Drop databases (directories).
- **Security:** Basic checks to prevent overwriting or deleting non-existent data.

### 📋 Table Operations
- **Schema Definition:** Create tables with custom column names and data types (`int` vs `str`).
- **Primary Key Integrity:** Supports Primary Key definition with mandatory uniqueness checks during insertion.
- **Data Validation:** Ensures data entered matches the defined column type (e.g., preventing strings in integer columns).
- **CRUD Operations:**
    - **Insert:** Add rows with real-time validation.
    - **Select:** View data in a formatted, pretty-printed table.
    - **Update/Delete:** Modify or remove records based on the Primary Key.

---

## 🛠️ Technical Architecture

### Project Structure
```text
.
├── dbms.sh                 # Main executable script
├── README.md               # Documentation
└── databases               # Root directory for all data
    └── open_source_courses # Example Database
        └── courses.txt     # Example Table (Flat file)
```

### Storage Engine (Flat-File Format)
Each table is stored as a `.txt` file with a 3-line metadata header:
1.  **Line 1:** Column Names (comma-separated).
2.  **Line 2:** Data Types (comma-separated: `int` or `str`).
3.  **Line 3:** Primary Key Index (0-based index of the PK column).
4.  **Line 4+:** Actual Data Records.

**Example `courses.txt` snippet:**
```csv
Ser,Course_Code,Course_Name,Lec,Lab
int,string,string,int,int
0
1,ESS/AGL/200,Agile Software Development Methodologies,12,12
2,ESS/SWE/100,Introduction to Software Engineering & UML,24,0
```

---

## 🚥 Getting Started

### Prerequisites
- **Bash Shell** (v4.0 or higher recommended).
- **Zenity** (Required for GUI mode):
  ```bash
  sudo apt install zenity  # Debian/Ubuntu
  sudo dnf install zenity  # RHEL/Fedora
  ```
- **util-linux** (provides the `column` command for pretty-printing).

### Installation & Execution
1.  **Clone or download** the script.
2.  **Give execution permissions:**
    ```bash
    chmod +x dbms.sh
    ```
3.  **Run the application:**
    ```bash
    ./dbms.sh
    ```

---

## 📖 Usage Example
1.  **Launch:** Choose "Graphical (GUI)" at the startup prompt.
2.  **Create DB:** Select "Create Database" and enter `University`.
3.  **Connect:** Select "Connect" and enter `University`.
4.  **Create Table:** Create `students` with 3 columns:
    - Name: `ID`, Type: `int`
    - Name: `Name`, Type: `str`
    - Name: `GPA`, Type: `int`
    - Set `PK` to `1` (The ID column).
5.  **Insert:** Add a record (e.g., `1, Fares, 4`).
6.  **Query:** Use "Select All" to see the formatted output.

---

## 👥 Authors
- **Fares Hazem**
- **Ahmed Ashraf**

*Open Source Development Track | ITI*
