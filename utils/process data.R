rm(list = ls())
gc()

library(tidyverse)

# File for processing EDW data to create pivot files
setwd("~/Google Drive File Stream/My Drive/rd file move zone/pivot/winter 2018 update/")
list.files()

# custom function to created quoted character vectors from unquoted text
Cs <- function(...) {as.character(sys.call())[-1]}

# Next time, export headers
gpapre <- read_csv("pre major gpa data_raw.csv",
                   col_names = Cs(sys.key,
                                  maj.first.yr,
                                  major.first.yrq,
                                  major,
                                  pathway,
                                  college,
                                  branch,
                                  cum.gpa),
                   na = c("", "NA", "NULL"))
# don't see any problems with the above. Next:
majors <- read_csv("all active majors-pathways-campus-college_raw.csv",
                   col_names = Cs(major.id,
                                  campus.code,
                                  campus.sname,
                                  major,
                                  pathway,
                                  major.lname,
                                  finorg.perm.id,
                                  finorg.key.id,
                                  finorg.campus.reporting.name,
                                  finorg.college.reporting.name,
                                  fin.sub.college.reporting.name,
                                  fin.dept.reporting.name,
                                  fin.sub.dept.reporting.name),
                   na = c("", "NA", "NULL"))

courses <- read_csv("majors and courses with freq and rank.csv",
                    col_names = Cs(sys.key,
                                   yr,
                                   qtr,
                                   yrq,
                                   dept,
                                   course.num,
                                   course.id,
                                   college,
                                   grade,
                                   grade.deriv,
                                   grade.system,
                                   incomplete,
                                   campus,
                                   major.first.yrq,
                                   major.first.yr,
                                   major,
                                   pathway,
                                   freq,
                                   rank),
                    na = c("", "NA", "NULL"))

urls <- read_csv("major urls.csv",
                 col_names = Cs(campus,
                                major,
                                pathway,
                                major.lname,
                                URL))
urls$Status <- NA     # placeholder

cnames <- read_csv("course long name.csv")

# trim strings
cnames$dept <- str_trim(cnames$dept)
courses$grade.deriv <- as.numeric(courses$grade.deriv)
i <- sapply(gpapre, is.character)
gpapre[i] <- lapply(gpapre[i], str_trim)
i <- sapply(majors, is.character)
majors[i] <- lapply(majors[i], str_trim)
i <- sapply(courses, is.character)
courses[i] <- lapply(courses[i], str_trim)
rm(i)

# re-do course.id in courses in case SQL output had extra spaces
courses$course.id <- paste0(courses$dept, courses$course.num)
# pare down course long names
cnames$course.id <- paste0(cnames$dept, cnames$course_num)
cnames <- cnames[cnames$course.id %in% courses$course.id,]    # only about 5% of courses make the cut

# calc IQRs ---------------------------------------------------------------
# update w/ full college name; tidy up first
cbind(sort(unique(majors$major.lname)))
# I'm not sure I want to try actually standardizing this much text for parens, spaces, etc.
# Just has to be the most egregious/unintuitive ones
# ex:
grep("App & Comp Math Sci", majors$major.lname)
# could fix with base R, stringr slightly easier to code up
# for future ref, a function that takes a whole bunch of patterns and corresponding changes would be swell
# I guess that would more or less be the same as just writing out a file with the correct values for table-joining
# write out two big vectors and loop over? not more efficient than c/p
# also, try to err on the safe side doing it this way, don't replace strings that are going to affect other cases

# Anthropology,Evening Degree Program (not going to fix commas)
# App & Comp Math Sci (-> Applied And Computational Mathematical Sciences)
majors$major.lname <- str_replace(majors$major.lname, "App & Comp Math Sci", "Applied And Computational Mathematical Sciences")
# Bioen: Nanoscience & Molecular Engr
majors$major.lname <- str_replace(majors$major.lname, "Bioen: Nanoscience & Molecular Engr",
            "Bioengineering: Nanoscience and Molecular Engineering")
# Bioresource Science and Engr: Business
majors$major.lname <- str_replace(majors$major.lname, "Bioresource Science and Engr: Business",
                                  "Bioresource Science and Engineering: Business")

# Bus Admin (several)
# check...
majors$major.lname[grep("Bus Admin", majors$major.lname)]
majors$major.lname <- str_replace(majors$major.lname, "Bus Admin", "Business Administration")

# C Sci & Softw Eng: Info Assur & Cybersec
majors$major.lname <- str_replace(majors$major.lname, "C Sci & Softw Eng: Info Assur & Cybersec",
                                  "Computer Science and Software Engineering: Information Assurance and Cybersecurity")

# C Sci & Sys (multiple)
majors[grep("C Sci & Sys", majors$major.lname),]
majors$major.lname <- str_replace(majors$major.lname, "C Sci & Sys",
                                  "Computer Science And Systems")

# Chemical Engr: Nanosci & Molecular Engr
majors$major.lname <- str_replace(majors$major.lname, "Chemical Engr: Nanosci & Molecular Engr",
                                  "Chemical Engineering: Nanoscience and Molecular Engineering")

# Computer Sci & Software Engr: (lots)
majors$major.lname <- str_replace(majors$major.lname, "Computer Sci & Software Engr",
                                  "Computer Science And Software Engineering")

# "Easth and Space Sciences: Geology"
majors$major.lname <- str_replace(majors$major.lname, "Easth", "Earth")

# En Sc & Tr Rs Mgt: Landsc Ecol & Consrv"
# "En Sc & Tr Rs Mgt: Nat Res & Env Mgmt"
# "En Sc & Tr Rs Mgt: Restr Ecol & Env Hort"
# "En Sc & Tr Rs Mgt: Sustainable For Mgmt"
# "En Sc & Tr Rs Mgt: Wildlife Conservation"
majors$major.lname <- str_replace(majors$major.lname, "En Sc & Tr Rs Mgt: Landsc Ecol & Consrv",
                                  "Environmental Science and Terrestrial Resource Management: Landscape Ecology and Conservation")
majors$major.lname <- str_replace(majors$major.lname, "En Sc & Tr Rs Mgt: Nat Res & Env Mgmt",
                                  "Environmental Science and Terrestrial Resource Management: Natural Resource and Environmental Management")
majors$major.lname <- str_replace(majors$major.lname, "En Sc & Tr Rs Mgt: Restr Ecol & Env Hort",
                                  "Environmental Science and Terrestrial Resource Management: Restoration Ecology and Environmental Horticulture")
majors$major.lname <- str_replace(majors$major.lname, "En Sc & Tr Rs Mgt: Sustainable For Mgmt",
                                  "Environmental Science and Terrestrial Resource Management: Sustainable Forest Management")
majors$major.lname <- str_replace(majors$major.lname, "En Sc & Tr Rs Mgt: Wildlife Conservation",
                                  "Environmental Science and Terrestrial Resource Management: Wildlife Conservation")

# Envir Sci: Conserv Biol & Ecol (Tacoma)
majors$major.lname <- str_replace(majors$major.lname, "Envir Sci: Conserv Biol & Ecol (Tacoma)",
                                  "Environmental Science: Conservation Biology and Ecology (Tacoma)")

# Envir Science & Terrestrial Resource Mgt"
majors$major.lname <- str_replace(majors$major.lname, "Envir Science & Terrestrial Resource Mgt",
                                  "Environmental Science and Terrestrial Resource Management")
# [264,] "Envir Sustainability: Envir Comm (Tac)"
# [265,] "Envir Sustainability: Envir Educ (Tac)"
# [266,] "Envir Sustainability: Policy & Law (Tac)"
# [267,] "Envir Sustainblty:Bus/Nonpft Env Sus (T)"
majors$major.lname <- str_replace(majors$major.lname, "Envir Sustainability: Envir Comm (Tac)",
                                  "Environmental Sustainability: Environmental Communication (Tacoma)")
majors$major.lname <- str_replace(majors$major.lname, "Envir Sustainability: Envir Educ (Tac)",
                                  "Environmental Sustainability: Environmental Education (Tacoma)")
majors$major.lname <- str_replace(majors$major.lname, "Envir Sustainability: Policy & Law (Tac)",
                                  "Environmental Sustainability: Environmental Policy and Law (Tacoma)")
majors$major.lname <- str_replace(majors$major.lname, "Envir Sustainblty:Bus/Nonpft Env Sus (T)",
                                  "Environmental Sustainability: Business/Nonprofit Environmental Sustainability (Tacoma)")

# Environmental St: Ecology & Conservation"
# [277,] "Environmental St: Internatl Perspectives"
# [278,] "Environmental St: Population and Health"
# [279,] "Environmental St: Resources"
majors[grep("Environmental St:", majors$major.lname),]
majors$major.lname <- str_replace(majors$major.lname, "Environmental St:", "Environmental Studies:")

# [338,] "Health Informatics&Hlth Information Mgmt"
majors$major.lname <- str_replace(majors$major.lname, "Health Informatics&Hlth Information Mgmt",
                                  "Health Informatics & Health Information Management")
# [348,] "History,Evening Degree Program"
# [357,] "Hlth Inf & Hlth Inf Mgt Certificate Prog"

# "Info Tech: Info Assur & Cybersecurity"
# [367,] "Info Tech: Mobile Digital Forensics"
majors$major.lname <- str_replace(majors$major.lname, "Info Tech: Info Assur & Cybersecurity",
                                  "Information Technology: Information Assurance and Cybersecurity")
majors$major.lname <- str_replace(majors$major.lname, "Info Tech: Mobile Digital Forensics",
                                  "Information Technology: Mobile Digital Forensics")

# "Interdeisciplinary Arts & Sciences (SMG)"
majors$major.lname <- str_replace(majors$major.lname, "Interdeisciplinary", "Interdisciplinary")

# [380,] "Interdisc St: Law, Economics, Public Pol"
majors$major.lname <- str_replace(majors$major.lname, "Interdisc St:", "Interdisciplinary Studies:")
# [438,] "Interdsciplinary Arts & Sciences (ESC)"
majors$major.lname <- str_replace(majors$major.lname, "Interdsciplinary", "Interdisciplinary")
# [456,] "Intl St: Latin America and Caribbean"
majors$major.lname <- str_replace(majors$major.lname, "Intl St:", "International Studies")
# 480,] "Mat Sci & Engr: Nanosci & Moleculr Engr"
majors$major.lname <- str_replace(majors$major.lname, "Mat Sci & Engr: Nanosci & Moleculr Engr",
                                  "Materials Science and Engineering: Nanoscience and Molecular Engineering")

# [481,] "Mat Scie & Engr: Nanosci & Moleculr Engr"
majors$major.lname <- str_replace(majors$major.lname, "Mat Scie & Engr: Nanosci & Moleculr Engr",
                                  "Materials Science and Engineering: Nanoscience and Molecular Engineering")

# [500,] "Mechanical Engr: Nanoscience & Molecular"
majors$major.lname <- str_replace(majors$major.lname, "Mechanical Engr: Nanoscience & Molecular",
                                  "Mechanical Engineering: Nanoscience and Molecular Engineering")

# [639,] "Science, Technology, and Society (Bthll)"
# [646,] "Society, Ethics, & Human Behavior (Bthl)"
majors$major.lname <- str_replace(majors$major.lname, "Bthll", "Bothell")
majors$major.lname <- str_replace(majors$major.lname, "Bthl", "Bothell")

# [657,] "Speech and Hearing Sci (Com Disorders)"
majors$major.lname <- str_replace(majors$major.lname, "Speech and Hearing Sci (Com Disorders)",
                                  "Speech and Hearing Sciences: Communication Disorders")
# [676,] "URBAN STUDIES"
# [133,] "CINEMA AND MEDIA STUDIES"
majors$major.lname <- str_replace(majors$major.lname, "URBAN STUDIES", "Urban Studies")
majors$major.lname <- str_replace(majors$major.lname, "CINEMA AND MEDIA STUDIES", "Cinema and Media Studies")
# Merging files:
x <- majors %>% select(major,
                       pathway,
                       branch = campus.code,
                       college.lname = finorg.college.reporting.name,
                       major.lname) %>% distinct()
gpapre <- inner_join(gpapre, x)
gpapre <- gpapre %>% filter(cum.gpa > 0) %>% distinct()   # feel safe removing these, the reasons are idiosyncratic but many of the transcripts with '0' occur far back in antiquity

mj.annual <- gpapre %>% group_by(major, pathway, college.lname, maj.first.yr) %>%
  summarize(count = n(),
            q1 = quantile(cum.gpa, .25),
            median = median(cum.gpa),
            q3 = quantile(cum.gpa, .75),
            iqr_min = q1 - IQR(cum.gpa),
            iqr_max = if_else(q3 + IQR(cum.gpa) > 4, 4, q3 + IQR(cum.gpa))) %>%
  arrange(maj.first.yr, major, pathway)
# this if_else might actually be slower than just passing through the summarized data but for 140k data points it doesn't matter
mj.all <- gpapre %>% group_by(major, pathway, college.lname) %>%
  summarize(count = n(),
            median = median(cum.gpa),
            q1 = quantile(cum.gpa, .25),
            q3 = quantile(cum.gpa, .75),
            iqr_min = q1 - IQR(cum.gpa),
            iqr_max = if_else(q3 + IQR(cum.gpa) > 4, 4, q3 + IQR(cum.gpa))) %>%
  arrange(major, pathway)

# how many per year?
# cbind(table(mj.annual$maj.first.yr))
# run script to boxplot all the majors+pathways?
# source("one script to print them all.R")



# create majors and courses file ------------------------------------------

# with major, pathway, dept_abbv, course_number, student count, students in major, course median gpa, course long name (as code for lookup), major full name (as code for lookup),
# major id (code), rank, campus (code)
# Note: I kept the years in here in case this data might be desirable on an annual basis another time

# n.maj will serve for the key lookup later but I don't like this joining, script is getting klunky
n.maj <- mj.all %>% select(major, pathway, count)
n.maj <- inner_join(n.maj, majors) %>% select(major, pathway, count, major.id, major.lname) %>%
  group_by(major, pathway, major.lname, count) %>% summarize(major.id = min(major.id))
courses <- courses %>% filter(incomplete == 0)   # H is honors, HP-high pass

pop <- courses %>% group_by(major, pathway, dept, course.num, campus, rank) %>%
  summarize(student_count = n(), course_gpa_50pct = median(grade.deriv, na.rm = T) / 10) %>%
  arrange(major, pathway, rank)
# a <- pop
pop <- inner_join(pop, n.maj) %>% mutate(check.p = student_count / count)

## TO DO - pop file needs the courselongname numeric lookup added to it from cnames
x <- cnames %>% select(name.lookup = id, dept, course.num = course_num)
pop <- inner_join(pop, x) %>% distinct()

# check dropped codes
# d <- setdiff(a[,1:4], pop[,1:4])
# gpapre[gpapre$major %in% d$major,]
# d[!(d$major %in% gpapre$major),]

# Ok - course long name (in pop) will map back to 'id' in the course long name file, which is only used for the Data Map

rm(a, d, x)

# create “data map" and 'status lookup' -------------------------------------------------------
cnames$is_course <- 1
cnames$is_major <- 0
cnames$is_campus <- 0
n.maj$is_course <- 0     # because it aligns with pop
n.maj$is_major <- 1
n.maj$is_campus <- 0
campus <- data.frame(is_course = 0,
                     is_major = 0,
                     is_campus = 1,
                     name = c("Seattle",
                              "Bothell",
                              "Tacoma"),
                     id = c(0,1,2))

## NEXT -- BIND ROWS

a <- cnames %>% select(is_course, is_major, is_campus, name = CourseLongName, id)
b <- n.maj %>% ungroup() %>% select(is_course, is_major, is_campus, name = major.lname, id = major.id)

data.map <- bind_rows(a, b, campus)

# write files -------------------------------------------------------------
dir.create("output")
mj.annual <- mj.annual %>% select(year = maj.first.yr,
                                  major_abbr = major,
                                  pathway,
                                  College = college.lname,
                                  count,
                                  iqr_min,
                                  q1,
                                  median,
                                  q3,
                                  iqr_max)
mj.all <- mj.all %>% select(major_abbr = major,
                            pathway,
                            College = college.lname,
                            count,
                            iqr_min,
                            q1,
                            median,
                            q3,
                            iqr_max)

pop <- pop %>% select(major_abbr = major,
                      pathway,
                      dept_abbrev = dept,
                      course_number = course.num,
                      student_count,
                      students_in_major = count,
                      course_gpa_50pct,
                      CourseLongName = name.lookup,  # = name.lookup
                      major_full_nm = major.id,   # = major.id
                      # MajorID = NA,         # omit this
                      CoursePopularityRank = rank,
                      Campus = campus)

urls <- urls %>% select(Code = major, Name = major.lname, URL, Status) %>% distinct()

write.csv(urls, "output/Status_Lookup.csv")
write.csv(mj.annual, "output/Student Data - All Majors by Year.csv")
write.csv(mj.all, "output/Student Data - All Majors.csv")
write.csv(data.map, "output/Data Map.csv")
write.csv(pop, "output/course-major rankings.csv")
