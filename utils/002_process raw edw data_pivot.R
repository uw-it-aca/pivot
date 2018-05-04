rm(list = ls())
gc()
# setup -------------------------------------------------------------------

library(tidyverse)

# File for processing EDW data to create pivot files
setwd("~/Google Drive File Stream/My Drive/AXDD/Non-Service Work/Innovation/Peach Cobbler/Student dashboards /Pivot/zk EDW queries/")

# in case there are multiple raw data files, load the most recently created
f <- list.files("sql output/", pattern = "raw", full.names = T)
f <- f[which.max(file.mtime(f))]
load(f); rm(f)

options(tibble.print_max = 800)

# custom function to created quoted character vectors from unquoted text
Cs <- function(...) {as.character(sys.call())[-1]}


# reconcile major codes ---------------------------------------------------

# kuali example:
active.majors$maj.key[1:4]
# major fin org table (SDB) example:
major.college$MajorCode[1:4]

# Issue:
# splitting strings > recombining
# removing (or adding) padded zeroes                --replace 00 with 0 in one instance in kuali, otherwise concat abbv_path
# campus will be lost from code in SDB/AI sources   --ok
# remove trailing spaces in SDB/AI sources

# trailing spaces (would be good to wrap this in a function that takes a data.frame as the argument at some point; although that would introduce a dependency on stringr...*)
# * but who wouldn't have stringr lib installed anyway? inconceivable!
i <- sapply(major.college, is.character)
major.college[i] <- lapply(major.college[i], str_trim)
i <- sapply(pre.maj.gpa, is.character)
pre.maj.gpa[i] <- lapply(pre.maj.gpa[i], str_trim)
i <- sapply(pre.maj.courses, is.character)
pre.maj.courses[i] <- lapply(pre.maj.courses[i], str_trim)
i <- sapply(course.names, is.character)
course.names[i] <- lapply(course.names[i], str_trim)

# splitting up strings to create common major key
# I'll do it for all to err on side of caution
active.majors$mkey <- str_sub(active.majors$maj.key, end = str_locate(active.majors$maj.key, "[\\d]-")[,1])
active.majors$mkey <- str_replace(active.majors$mkey, "-", "_")
# there's one major with 00 instead of 0; fortunately there is not also a CMS-0
active.majors$mkey <- str_replace(active.majors$mkey, "00", "0")

# concat abbv+path, 1 line fewer/cleaner for the rest
major.college$mkey <- paste(major.college$MajorAbbrCode, major.college$MajorPathwayNum, sep = "_")
pre.maj.gpa$mkey <- paste(pre.maj.gpa$maj.abbv, pre.maj.gpa$maj.path, sep = "_")
pre.maj.courses$mkey <- paste(pre.maj.courses$maj.abbv, pre.maj.courses$maj.path, sep = "_")

# for course code (try: split on \\_[\\D])
course.names$ckey <- str_sub(course.names$course.code, start = str_locate(course.names$course.code, "\\_\\D")[,2])
pre.maj.courses$ckey <- paste(pre.maj.courses$course.dept, pre.maj.courses$course.num, sep = "_")


# course names: filter dupes, fix case in course long names -------------------------------------------

# take only most recent year for the name
course.names <- course.names %>% group_by(ckey) %>% filter(yrq == max(yrq))



# re: long names, the base r solution is *extremely* slow(?)
# tools::toTitleCase(tolower(course.names$course.lname))
# also the names are about 35% space-padding by volume :P
# the tools option is supposed to ignore certain words that shouldn't be upper case in
# English titles, e.g. 'and' or 'in', but the runtime is just too slow to be feasible.
# I'd expect 360k cases, vectorized over char+column, to run in a few seconds (trimming spaces occurs in ~.25s)
# stringr has a wrapper for stringi's to_title which is fast. Just check for "i" needing conversion to "I" (1)
# Also: i'm going to leave X-y as-is even though words like X-ray should by X-y.
course.names$course.lname <- tolower(course.names$course.lname)
# now need to fix roman numerals - there is a roman class in base r but it's not a lot of help as-is
# because the numerals are embedded in strings
# grep("ii", course.names$course.lname, value = T)
# chars can occur in the middle of a string, not just the end so I'm going to try to capture most cases
# the one I'm concerned about is:
# grep("vi", course.names$course.lname, value = T)      # civ, environ, survival, violin, &c.
# grep(" vi", course.names$course.lname, value = T)
# so it needs to be something like: space vi space OR space vi colon
# nothing appears to go past VIII
course.names$course.lname <- str_to_title(course.names$course.lname)
course.names$course.lname <- str_replace_all(course.names$course.lname, "I[i]+", toupper)    # appears to work for II and III correctly
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\ Vi[i]+", toupper)  # appears correct for VII+
# lastly, Vi > VI: space Vi followed by either : or eol
# I'm not clever enough at regex to make it anchor/eol OR :, so:
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\sVi\\:", toupper)
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\sVi$", toupper)
# these probably don't even matter for the rankings


# Update grades in courses and filter -------------------------------------

# ref: https://www.washington.edu/students/gencat/front/Grading_Sys.html
pre.maj.courses$course.grade <- recode(pre.maj.courses$course.grade,
                                       "A" = "40",
                                       "B" = "31",
                                       "C" = "21",
                                       "D" = "11",
                                       "E" = "00")
pre.maj.courses <- pre.maj.courses %>%
  mutate(grade = as.numeric(course.grade) / 10) %>%
  filter(is.na(grade) == F)

# validate active majors and kuali names ------------------------------------

# kuali will be the official source. We don't want to add rows to kuali by duping keys nor do we want to drop any
major.college[duplicated(major.college$mkey),]
major.college <- major.college[!duplicated(major.college$mkey),]

active.majors <- active.majors %>% left_join(major.college, by = "mkey")
unique(active.majors$mkey[is.na(active.majors$FinCollegeReportingName)])
# checking this I found that CMS has double zeroes in kuali (nothing else does) so I went back and converted from above

# filter kuali by unique mkeys, b/c data is unique by code
active.majors <- active.majors[!duplicated(active.majors$mkey),]

table(is.na(active.majors$FinCollegeReportingName))
# are they sensible?
table(active.majors$FinCollegeReportingName, active.majors$MajorCampus)
# yes, even though both bothell and tacoma have Interdisciplinary Arts and Sciences

# kuali names for programs need to be split from the credential
# unfortunately, there are a few that are just "Bachelor of XXX" instead of "in XXX"
active.majors$maj.name <- str_sub(active.majors$title, start = str_locate(active.majors$title, "in\\s")[,2]+1)
# using indexing instead of manually changing
i <- is.na(active.majors$maj.name)
active.majors$maj.name[i] <- str_sub(active.majors$title[i], start = str_locate(active.majors$title[i], "of\\s")[,2]+1)
table(is.na(active.majors$maj.name))

# Filter other files using active majors ----------------------------------

i <- unique(active.majors$MajorCode)
pre.maj.courses <- pre.maj.courses %>% filter(maj.code %in% i)
pre.maj.gpa <- pre.maj.gpa %>% filter(maj.code %in% i)

# Calc rankings for courses by majors; add additional fields for final file -------------------------------------

course.rank <- pre.maj.courses %>%
  group_by(mkey, ckey) %>%
  summarize(n.course = n(), mgrade = median(grade)) %>%
  arrange(desc(n.course), .by_group = T) %>%
  filter(row_number() <= 10) %>%
  ungroup()

# need: code, course abbv, course#, n_course, n_major,
xtra <-
course.rank <-


# add "college" and calc n, iqr for majors -----------------------------------------------------

med.tot <- pre.maj.gpa %>%
  group_by(mkey, FinCollegeReportingName) %>%
  summarize(count = n(),
            campus = max(campus),
            q1 = quantile(cgpa, .25),
            median = median(cgpa),
            q3 = quantile(cgpa, .75),
            iqr_min = q1 - IQR(cgpa),
            iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
  ungroup()


med.ann <- pre.maj.gpa %>%
  group_by(mkey, yrq.decl) %>%
  summarize(count = n(),
            campus = max(campus),
            q1 = quantile(cgpa, .25),
            median = median(cgpa),
            q3 = quantile(cgpa, .75),
            iqr_min = q1 - IQR(cgpa),
            iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
  ungroup()




# merge files -------------------------------------------------------------

majors <- majors %>%
  select(major,
         pathway,
         branch = campus.code,
         college.lname = finorg.college.reporting.name,
         major.lname,
         major.id)

# verify (against old pivot) that majors + branches are correct:
table(majors$college.lname, majors$branch)

gpapre <- inner_join(gpapre, majors, by = c("major", "pathway", "branch"))
gpapre <- gpapre %>% filter(cum.gpa > 0) %>% distinct()   # safe removing these, the reasons are idiosyncratic but many of the transcripts with '0' occur far back in antiquity

# remove majors that slipped through filters
# later iterations should remove these ahead of time
nix <- c("Tacoma Dual Enrollment",
         "Tacoma Dual Enrollment - TCC",
         "Dual Enrollment Comput & Sftwr Sys (Tac)",
         "Education Certificate Tacoma",
         "Academy for Young Scholars",
         "General Studies",
         "Certificate in International Business",
         "Computer Science & Systems (Proj/Thesis)",
         "Center for Study of Capable Youth",
         "Tacoma General Studies",
         "Postbaccalaureate Study",
         "Medex (Medex Certificate Program)",
         "Exchange - Engineering",
         "Exchange - Arts and Sciences",
         "Dual Enrollment Comput & Sftwr Sys (Tac)",
         "Post Bac Studies (Tacoma Campus)",
         "Law Special",
         "Law Visiting",
         "Pharmacy",
         "General Studies - Distance Learning",
         "Hlth Inf & Hlth Inf Mgt Certificate Prog",
         "Pre Major Sustainable Urb Dev (Tacoma)",
         "Dual Enrollment Comput Engr & Sys (Tac)")
gpapre <- gpapre %>% filter(!(major.lname %in% nix))

# check that college names need cleanup here:
table(gpapre$college.lname)
gpapre <- gpapre %>% filter(college.lname != "Graduate School")

# summarize:
mj.annual <- gpapre %>% group_by(major, pathway, college.lname, maj.first.yr, major.lname, branch) %>%
  summarize(major.id = max(major.id),
            count = n(),
            q1 = quantile(cum.gpa, .25),
            median = median(cum.gpa),
            q3 = quantile(cum.gpa, .75),
            iqr_min = q1 - IQR(cum.gpa),
            iqr_max = if_else(q3 + IQR(cum.gpa) > 4, 4, q3 + IQR(cum.gpa))) %>%
  arrange(maj.first.yr, major, pathway) %>%
  ungroup()
# this if_else might actually be slower than just passing through the summarized data but for 140k data points it doesn't matter
mj.all <- gpapre %>% group_by(major, pathway, college.lname, major.lname, branch) %>%
  summarize(major.id = max(major.id),
            count = n(),
            median = median(cum.gpa),
            q1 = quantile(cum.gpa, .25),
            q3 = quantile(cum.gpa, .75),
            iqr_min = q1 - IQR(cum.gpa),
            iqr_max = if_else(q3 + IQR(cum.gpa) > 4, 4, q3 + IQR(cum.gpa))) %>%
  arrange(major, pathway) %>%
  ungroup()

# how many per year?
cbind(table(mj.annual$maj.first.yr))
# run script to boxplot all the majors+pathways?
# source("one script to print them all.R")


# create majors and courses file ------------------------------------------

# with major, pathway, dept_abbv, course_number, student count, students in major, course median gpa, course long name (as code for lookup), major full name (as code for lookup),
# major id (code), rank, campus (code)
# Note: I kept the years in here in case this data might be wanted later


# n.maj will serve for the key lookup later but I don't like this joining, script is getting klunky
n.maj <- mj.all %>% select(major, pathway, count, major.id, major.lname, branch) %>% distinct()

courses <- courses %>% filter(incomplete == 0)   # H is honors, HP-high pass

# with popularity, we don't care about the class branch, branch/campus number should be for the MAJOR
pop <- courses %>% group_by(major, pathway, dept, course.num, rank) %>%
  summarize(student_count = n(), course_gpa_50pct = median(grade.deriv, na.rm = T) / 10) %>%
  arrange(major, pathway, rank) %>%
  ungroup()
pop <- inner_join(pop, n.maj, by = c("major", "pathway")) %>% mutate(check.p = student_count / count)

## popularity needs the courselongname numeric lookup added to it from cnames
x <- cnames %>% select(name.lookup = id, dept, course.num = course_num)
pop <- inner_join(pop, x) %>% distinct()
# Ok - course long name (in pop) will map back to 'id' in the course long name file, which is used for the Data Map
# It *should* be ok if there are duplicate names between courses and majors b/c they also have a binary 'what is this' lookup field. I think.

rm(a, d, x, nix)


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

# intelligently bind rows

a <- cnames %>% select(is_course, is_major, is_campus, name = CourseLongName, id)
b <- n.maj %>% ungroup() %>% select(is_course, is_major, is_campus, name = major.lname, id = major.id)

data.map <- bind_rows(a, b, campus)


# write files -------------------------------------------------------------
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

# replace n <5 w/ -1
mj.annual$count[mj.annual$count < 5] <- -1
mj.all$count[mj.all$count < 5] <- -1
# apply(mj.all[,Cs(iqr_min, q1, median, q3, iqr_max)], 2, function(x) ifelse(mj.all$count == -1, -1, x))
cols <- Cs(iqr_min, q1, median, q3, iqr_max)
mj.all[,cols] <- lapply(mj.all[,cols], function(x) ifelse(mj.all$count == -1, -1, x))


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
                      Campus = branch)

urls <- urls %>% select(Code = major, Name = major.lname, URL, Status) %>% distinct()



## FUTURE: name files accordingly and output with single lapply; parallel lists of files + desired names would work fine too in a for loop
# paste0(outdir, "Status_Lookup.csv")
outdir <- "/Volumes/GoogleDrive/My Drive/AXDD/Non-Service Work/Innovation/Peach Cobbler/Student dashboards /Pivot/zk EDW queries/"
write.csv(urls, paste0(outdir, "Status_Lookups.csv"), row.names = F)
write.csv(mj.annual, paste0(outdir, "Student Data - All Majors by Year.csv"), row.names = F)
write.csv(mj.all, paste0(outdir, "Student Data - All Majors.csv"), row.names = F)
write.csv(data.map, paste0(outdir, "Data Map.csv"), row.names = F)
write.csv(pop, paste0(outdir, "course-major rankings.csv"), row.names = F)

