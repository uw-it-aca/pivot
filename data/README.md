## Description of Data Files
-----------------------------
`Data_Map.csv` - Connecting id's to course, major, and campus names
```
"is_course","is_major","is_campus","name","id"
1, 0, 0, "Intro to Computer Science", 34
0, 1, 0, "Computer Science", 99
0, 0, 1, "Seattle", 0
```
`Majors_and_Courses.csv` - Most popular courses by students who declare each major (along with the course-gpa)
```
"major_path","course_num","student_count","students_in_major","course_gpa_50pct","course_long_name","major_full_nm","course_popularity_rank","campus"
"CSE_0", "CSE_101", 200, 100, 3.70, 34, 99, 1, 0
```
`Student_Data_All_Majors.csv` - Boxplot data surrounding the GPA's of students who declare each major
```
"major_path","college","count","iqr_min","q1","median","q3","iqr_max"
"CSE_0", "College of Engineering", 100, 3.60, 3.70, 3.80, 3.90, 4
```
`Status_Lookup.csv` - Status (Capacity-Constrained, Open, Minimum Requirements) for each major
```
"code","name","status"
"CSE_0", "Computer Science", "capacity-constrained"
```
