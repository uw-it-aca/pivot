
# [TODO]
# left off at "add "college" and calc n, iqr for majors"


rm(list = ls())
gc()
# notes
# a CM credential_code is in format of [ABBV]-[pathway]-[level]-[type]
# pathway is not padded to 2 chars in CM, unlike most EDW sources
# level is undergrad/grad/etc.
# type is '...of Arts/Science/etc.'

# setup -------------------------------------------------------------------

library(tidyverse)

# File for processing EDW data to create pivot files
# To access local files/vars that are not part of repo, move up one level from project directory.
# This is included to 'reset' 002 in the event that 001 > 002 aren't being
# run in the same session.
setwd(rstudioapi::getActiveProject())
setwd("..")

# in case there are multiple raw data files, load the most recently created
f <- list.files("raw data/", pattern = "raw", full.names = T)
f <- f[which.max(file.mtime(f))]
load(f); rm(f)

# source("scripts/config.R")

options(tibble.print_max = 800)

# custom function to created quoted character vectors from unquoted text
Cs <- function(...) {as.character(sys.call())[-1]}

# re-written to use base r instead of stringr
df.trimws <- function(df){
  i <- sapply(df, is.character)
  df[i] <- lapply(df[i], trimws)
  return(df)
}

# use max available yrq from transcripts rather than current
max.yrq <- max(pre.maj.courses$tran.yrq)

# make file name prefix from max.yrq
make.prefix <- function(x){
  q <- x %% 10
  y <- (x %/% 10) - 2005  # subtract 5 years
  q <- c("wi", "sp", "su", "au")[q]
  return(paste0(q, y, "_20qtrs"))
}
prefix <- make.prefix(max.yrq)


# CM major codes ---------------------------------------------------
programs <- programs %>%
  filter(program_status == "active",
         str_sub(program_code, 1, 2) == "UG",
         grepl("MAJOR", program_code, ignore.case = F) == T)
programs <- df.trimws(programs)

x <- data.frame(str_split(creds$credential_code, "-", simplify = T))
names(x) <- c("cred_abbv", "cred_pathway", "cred_level_code", "cred_degree_type_code")
creds <- bind_cols(creds, x)
rm(x)

xcreds <- creds %>% filter(credential_status != "active" | grepl("true", DoNotPublish, ignore.case = T) == T)
creds <- creds %>%
  filter(grepl("true", DoNotPublish, ignore.case = T) == F,
         credential_status == "active",
         cred_level_code == 1,
         cred_degree_type_code <= 8)
creds <- df.trimws(creds)

# We're not currently using the Kuali college names b/c they don't have them filled in for Tacoma/Bothell yet
active.majors <- inner_join(creds, programs, by = "program_verind_id") %>%
  distinct(credential_code, .keep_all = T) %>%
  mutate(campus_no = ifelse(campus_name == "Seattle", 0,
                            ifelse(campus_name == "Bothell", 1, 2)))

# remove WS in data warehouse source files
major.college <- df.trimws(major.college)
pre.maj.gpa <- df.trimws(pre.maj.gpa)
pre.maj.courses <- df.trimws(pre.maj.courses)
course.names <- df.trimws(course.names)

# # concat abbv+path, 1 line fewer/cleaner for the rest (why not use major.code...?)
# major.college$mkey <- paste(major.college$MajorAbbrCode, major.college$MajorPathwayNum, sep = "_")
# pre.maj.gpa$mkey <- paste(pre.maj.gpa$maj.abbv, pre.maj.gpa$maj.path, sep = "_")
# pre.maj.courses$mkey <- paste(pre.maj.courses$maj.abbv, pre.maj.courses$maj.path, sep = "_")
#
# # for course code (try: split on \\_[\\D])
# course.names$ckey <- str_sub(course.names$course.code, start = str_locate(course.names$course.code, "\\_\\D")[,2])
# pre.maj.courses$ckey <- paste(pre.maj.courses$course.dept, pre.maj.courses$course.num, sep = "_")
# pre.maj.courses$course.key <- paste(pre.maj.courses$course.campus, pre.maj.courses$course.dept, pre.maj.courses$course.num, sep = "_")

# Course Names: filter dupes, fix case in course long names -------------------------------------------

# take only most recent name
course.names <- course.names %>%
  group_by(CourseCode) %>%
  filter(AcademicQtrKeyId == max(AcademicQtrKeyId)) %>%
  ungroup()

# I'm not finding and fixing all possible typos

# re: long names, the base r solution is *extremely* slow(?)
# tools::toTitleCase(tolower(course.names$course.lname))
# (random note: the names appear to be about 35% space-padding by volume)
# the tools option is supposed to ignore certain words that shouldn't be upper case in
# English titles, e.g. 'and' or 'in', but the runtime is just too slow to be feasible.
# I'd expect 360k cases, vectorized over char+column, to run in a few seconds (trimming spaces occurs in ~.25s)
# stringr has a wrapper for stringi's to_title which is fast. Just check for "i" needing conversion to "I" (1)
# Also: I'm leaving X-y as-is even though words like X-ray should by X-y.
course.names$course.lname <- tolower(course.names$CourseLongName)
# now need to fix roman numerals - there is a roman class in base r but it's not a lot of help as-is
# because the numerals are embedded in strings
# grep("ii", course.names$course.lname, value = T)
# chars can occur in the middle of a string, not just the end so I'm going to try to capture most cases
# the one I'm concerned about is:
# grep("vi", course.names$course.lname, value = T)      # civ, environ, survival, violin, &c.
# grep(" vi", course.names$course.lname, value = T)
# so it needs to be something like: space vi space OR space vi colon
# nothing appears to go past VIII at the moment - a better solution would account for any Roman numerals but
# would require significantly more time and testing (there is a Roman numeral package, it doesn't do what we need).
# Fortunately, the stringr functions are extremely fast
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
# I'm using the tops of the ranges

# wrapping in a function so the recode doesn't live on
grade.recode <- function(g){
  return(recode(g,
                "A"  = "40",
                "A-" = "38",
                "B+" = "34",
                "B"  = "31",
                "B-" = "28",
                "C+" = "24",
                "C"  = "21",
                "C-" = "18",
                "D+" = "14",
                "D"  = "11",
                "D-" = "08",
                "E"  = "00"
                ))
}

pre.maj.courses <- pre.maj.courses %>%
  mutate(grade = grade.recode(grade),
         grade = as.numeric(grade) / 10) %>%            # keeping this a little easier to read than wrapping fun(fun)
  filter(is.na(grade) == F)                             # remove rows with missing values for grade

# rm(grade.recode)

# remove duplicate quarterly-student-program-course enrollments
pre.maj.courses <- pre.maj.courses %>%
  distinct(SDBSrcSystemKey, ProgramCode, course_branch, dept_abbrev, course_number, tran.yrq, .keep_all = T)


# validate active majors and kuali names ------------------------------------

# kuali will be the official source. We don't want to add rows to kuali by duping keys
# nor do we want to drop any active programs or creds. As for not-active-but-future...well...
# Also unsure if it's safe to join only by campus and abbreviation. Probably but I'm not 100%.
# y <- major.college
# x <- active.majors %>%
#   left_join(major.college, by = c("campus_no" = "MajorCampus",
#                                   "cred_abbv" = "MajorAbbrCode",
#                                   "cred_pathway" = "MajorPathwayNum"))
# active.majors <- active.majors[!duplicated(active.majors$credential_verdep_id),]
# # checking this I found that CMS has double zeroes in kuali (nothing else does) so I went back and converted from above

  # # 1/3/19 - here's a new solution that uses some of the Kuali data
  # splitby <- active.majors$campus_no
  # split.majors <- split.data.frame(active.majors, f = splitby)
  #
  # x <- unsplit(split.majors, splitby)
  #
  # # now we have a list of 3 data frames
  # split.majors$Seattle$college <- str_to_title(split.majors$Seattle$college_name)

mj <- major.college %>%
  select(MajorCampus,
         college = FinCollegeReportingName,
         MajorAbbrCode,
         MajorPathwayNum) %>%
  mutate(MajorPathwayNum = as.character(MajorPathwayNum))

amj <- active.majors %>%
  left_join(mj, by = c("campus_no" = "MajorCampus",
                              "cred_abbv" = "MajorAbbrCode",
                              "cred_pathway" = "MajorPathwayNum")) %>%
  # now replace vals for Seattle
  mutate(college = if_else(campus_no == 0,
                           str_to_title(college_name),
                           college))
amj[is.na(amj$college),]
# NA's should only be for future - i.e. active but not yet offered - credentials
active.majors <- amj %>%
  filter(!is.na(college))
rm(mj, amj)

# are the depts+colleges sensible?
table(active.majors$college, active.majors$campus_name, useNA = "ifany")
# yes, even though both bothell and tacoma have Interdisciplinary Arts and Sciences

# CM names for programs need to be split from the credential
# there are a few that are just "Bachelor of XXX" instead of "in XXX"
active.majors$maj.name <- str_sub(active.majors$credential_title, start = str_locate(active.majors$credential_title, "in\\s")[,2]+1)
# using indexing instead of manually changing
i <- is.na(active.majors$maj.name)
active.majors$credential_title[i]
active.majors$maj.name[i] <- str_sub(active.majors$credential_title[i], start = str_locate(active.majors$credential_title[i], "of\\s")[,2]+1)
table(is.na(active.majors$maj.name))

# Filter pre-major courses and gpa using active majors ----------------------------------

# i <- unique(paste(active.majors$cred_abbv, active.majors$cred_pathway, sep = "_"))

table(pre.maj.courses$ProgramCode %in% active.majors$credential_code) # program code and credential code don't match by default b/c program code includes campus number
# but also b/c program code pathways are padded but active majors in CM are not
# and, of course, one uses '-' and one uses '_'
# ANTH-0-1-1 v. 0_ANTH_00_1_1
pre.maj.courses$credential_code <- paste(pre.maj.courses$MajorAbbrCode,
                                         pre.maj.courses$MajorPathwayNum,
                                         pre.maj.courses$DegreeLevelCode,
                                         pre.maj.courses$DegreeTypeCode,
                                         sep = "-")
pre.maj.gpa$credential_code <- paste(pre.maj.gpa$MajorAbbrCode,
                                     pre.maj.gpa$MajorPathwayNum,
                                     pre.maj.gpa$DegreeLevelCode,
                                     pre.maj.gpa$DegreeTypeCode,
                                     sep = "-")

  # table(pre.maj.courses$credential_code %in% active.majors$credential_code)
  # i <- sort(setdiff(pre.maj.courses$credential_code, active.majors$credential_code)); cbind(i)
  # # need the xcreds to at least try to validate these
  # table(xcreds$credential_code %in% i)      # some, not all, are indeed 'active' but not published

pre.maj.courses <- pre.maj.courses %>% filter(credential_code %in% unique(active.majors$credential_code))
pre.maj.gpa <- pre.maj.gpa %>% filter(credential_code %in% unique(active.majors$credential_code))

# add "college" and calc n, iqr for majors -----------------------------------------------------

pre.maj.gpa <- pre.maj.gpa %>% inner_join(active.majors, by = "mkey")

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
  mutate(yr.decl = yrq.decl %/% 10) %>%
  group_by(mkey, FinCollegeReportingName, yr.decl) %>%
  summarize(count = n(),
            campus = max(campus),
            q1 = quantile(cgpa, .25),
            median = median(cgpa),
            q3 = quantile(cgpa, .75),
            iqr_min = q1 - IQR(cgpa),
            iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
  ungroup()

# Calc rankings for courses by majors; add additional fields for final file -------------------------------------

# first check for courses without names:
i <- !(pre.maj.courses$ckey %in% course.names$ckey)
table(i)
pre.maj.courses$ckey[i]
# I've checked through many of these in the full course names file, which has no filters applied
# Not much to do to reconcile them right now (check with team)

course.rank <- pre.maj.courses %>%
  filter(ckey %in% course.names$ckey) %>%               # filter slows the whole query down significantly
  group_by(mkey, ckey) %>%
  summarize(n.course = n(), mgrade = median(grade)) %>%
  arrange(desc(n.course), .by_group = T) %>%
  filter(row_number() <= 10) %>%
  mutate(pop = seq_along(n.course)) %>%
  ungroup()

nrow(course.rank) / length(unique(course.rank$mkey))      # hmm, something doesn't have 10 majors
course.rank %>% group_by(mkey) %>% filter(max(pop) < 10)  # TINDIV, but it only has 4 transcripts and 1 student

# need: long name, major name, and campus (for MAJOR) are supposed to be numeric codes
course.names$ckey.num <- seq_along(course.names$ckey)
active.majors$mkey.num <- seq_along(active.majors$mkey)

c <- course.names %>% select(ckey, ckey.num)
course.rank <- course.rank %>% left_join(c, by = "ckey")
m <- active.majors %>% select(mkey, mkey.num, MajorCampus)
course.rank <- course.rank %>% left_join(m, by = "mkey")
m <- med.tot %>% select(mkey, count)
course.rank <- course.rank %>% left_join(m, by = "mkey")

# check: number in course should never exceed total in major:
table(course.rank$n.course > course.rank$count)
i <- course.rank$n.course > course.rank$count
course.rank[i,]

# check the duplicate entries (with duplicated quarters already having been removed above)
(huh <- course.rank[i,1:2])
check <- huh %>% inner_join(pre.maj.courses) %>% group_by(sys.key) %>% filter(n() > 1) %>% ungroup()
# if student took same course more than once for credit, in different quarters - that seems acceptable
# set n.course equal to n.major
length(unique(check$sys.key))
rm(huh, check)

course.rank$n.course <- ifelse(course.rank$n.course > course.rank$count, course.rank$count, course.rank$n.course)
table(course.rank$n.course > course.rank$count)
course.rank[course.rank$mkey == "MUSIC_0",]


# # run script to boxplot all the majors+pathways?
# # source("one script to print them all.R")


# Create data map -------------------------------------

course.map <- course.names[course.names$ckey %in% course.rank$ckey,]
course.map <- course.map %>%
  ungroup() %>%
  mutate(is_course = 1,
         is_major = 0,
         is_campus = 0) %>%
  select(is_course,
         is_major,
         is_campus,
         name = course.lname,
         # id = ckey.num,
         id = ckey.num,
         key = ckey)
major.map <- active.majors %>%
  ungroup() %>%
  mutate(is_course = 0,
         is_major = 1,
         is_campus = 0) %>%
  select(is_course,
         is_major,
         is_campus,
         name = maj.name,
         # id = mkey.num,
         id = mkey.num,
         key = mkey)
campus.map <- data.frame(is_course = 0,
                         is_major = 0,
                         is_campus = 1,
                         name = c("Seattle",
                                  "Bothell",
                                  "Tacoma"),
                         # id = c(0,1,2),
                         id = c(0,1,2),
                         key = c('0','1','2'),
                         stringsAsFactors = F)

data.map <- bind_rows(course.map, major.map, campus.map)
rm(campus.map, course.map, major.map)


# create student.data.all.majors (med.tot) ------------------------------------------

student.data.all.majors <- med.tot %>% select(major_path = mkey, college = FinCollegeReportingName, count, iqr_min, q1, median, q3, iqr_max)
# edit rows with count < 5
cols <- Cs(count, iqr_min, q1, median, q3, iqr_max)
student.data.all.majors[,cols] <- lapply(student.data.all.majors[,cols], function(x) ifelse(student.data.all.majors$count < 5, -1, x))

# add majors that are active but have no students
active.no.stu <- active.majors %>%
  filter(!(mkey %in% med.tot$mkey)) %>%
           select(major_path = mkey, college = FinCollegeReportingName) %>%
  mutate(count = -1, iqr_min = -1, q1 = -1, median = -1, q3 = -1, iqr_max = -1)

student.data.all.majors <- bind_rows(student.data.all.majors, active.no.stu)


# status lookup + age -----------------------------------------------------------

# status lookup does not need to replicate names from data.map (but it's useful for error checking)
status.lookup <- active.majors %>% select(code = mkey, name = maj.name, status = admission.type)

# Add age to status lookup
maj.age$mkey <- paste(trimws(maj.age$major_abbr), maj.age$major_pathway, sep = "_")
maj.age <- maj.age %>% group_by(mkey) %>% add_tally() %>% filter(any(eyrq == 99994)) %>% ungroup()
maj.age <- maj.age %>% group_by(mkey) %>% transmute(st = min(syrq), end = max(eyrq)) %>% ungroup()

qtr.diff <- function(x, y){
  (((x %/% 10) - (y %/% 10)) * 4) + ((x %% 10) - (y %% 10))
}

maj.age$quarters_of_data <- qtr.diff(max.yrq, maj.age$st)
maj.age <- maj.age %>% select(mkey, quarters_of_data) %>% mutate(quarters_of_data = if_else(quarters_of_data > 20, 20, quarters_of_data))

# check:
status.lookup[!(status.lookup$code %in% maj.age$mkey),]
# These may have been updated since the last time, e.g. ECFS O is no longer accepting students
status.lookup <- status.lookup %>% left_join(maj.age, by = c("code" = "mkey")) %>% distinct() %>% select(-name)

# Course.major.rankings ---------------------------------------------------

# no long using "Major full name" or "course long name" columns in the majors_and_course.csv
course.rank <- course.rank %>% select(major_path = mkey, course_num = ckey, student_count = n.course,
                                      students_in_major = count, course_gpa_50pct = mgrade,
                                      course_popularity_rank = pop, campus = MajorCampus)
i <- course.rank$students_in_major < 5
cols <- Cs(student_count, students_in_major, course_gpa_50pct)
course.rank[,cols] <- lapply(course.rank[,cols], function(x) ifelse(course.rank$students_in_major < 5, -1, x))
head(course.rank[i,], 30)


# double check names ---------------------------------------------
names(status.lookup)
names(student.data.all.majors)
names(data.map)
names(course.rank)

# write files -------------------------------------------------------------

outdir <- paste0(getwd(), "/transformed data/")
write.csv(status.lookup, paste0(outdir, "status_lookup.csv"), row.names = F)
write.csv(data.map, paste0(outdir, "data_map.csv"), row.names = F)

# these need prefixes
write.csv(student.data.all.majors, paste0(outdir, prefix, "_student_data_all_majors.csv"), row.names = F)
write.csv(course.rank, paste0(outdir, prefix, "_majors_and_courses.csv"), row.names = F)

save(list = Cs(active.majors, pre.maj.courses, med.ann, pre.maj.gpa, course.names, major.college), file = "intermediate data/intermediate cleaned files.RData")
