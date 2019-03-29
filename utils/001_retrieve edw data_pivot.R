rm(list = ls())
gc()

# setup -------------------------------------------------------------------

library(tidyverse)
library(dbplyr)
library(odbc)

# helper function - create quoted vector, i.e. c(), from unquoted text
# not intended to smoothly handle punctuation but can be coerced a little, e.g. Cs(a, b, "?")
Cs <- function(...){as.character(sys.call())[-1]}
options(tibble.print_max = 800)

# To access local files/vars that are not part of repo, move up one level from project directory
setwd(rstudioapi::getActiveProject())
setwd("..")

source("scripts/config.R")

# create connections to enterprise data server
aicon <- dbConnect(odbc::odbc(), dns, Database = dabs[1], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))
sdbcon <- dbConnect(odbc::odbc(), dns, Database = dabs[2], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))

# get date for year + quarter ----------------------------------------------------
cal <- tbl(sdbcon, in_schema("sec", "sys_tbl_39_calendar")) %>%
  filter(first_day >= "2018-01-01") %>%
  select(table_key, first_day) %>%
  collect() %>%
  mutate(fd_next = lead(first_day),
         yrq = as.numeric(str_sub(table_key, start = 2)),
         yrq_last = lag(yrq))

max.yrq <- cal$yrq_last[(Sys.Date() >= cal$first_day) & (Sys.Date() <= cal$fd_next)]
# For 5 years of data:
last.major.yrq5 <- max.yrq - 50
rm(cal)

# CM in SDB replaces Kuali csv ------------------------------------------------

programs <- tbl(sdbcon, in_schema("sec", "CM_Programs")) %>% collect()
creds <- tbl(sdbcon, in_schema("sec", "CM_Credentials")) %>% collect()

# Major to FinOrg ---------------------------------------------------------

major.college <- tbl(aicon, in_schema("sec", "IV_MajorFinancialOrganizations")) %>%
  filter(VisitingMajorInd == "N", PrimaryOrgUnitInd == "Y", PreMajorInd == "N") %>%         # ActiveMajorInd == "Y",
  select(MajorCampus, FinCampusReportingName, FinCollegeReportingName, MajorAbbrCode, MajorPathwayNum, MajorCode) %>%
  collect()

# re: MajorCode: Code that fully identifies the major.
# A concatenation of the MajorCampus, MajorAbbrCode, and MajorPathwayNum (each separated by underscores) e.g. '0_BIOL_10'.
# https://canvas.uw.edu/courses/1061200/pages/studentprogramenrollment

maj.first.yrq <- tbl(aicon, in_schema("sec", "IV_StudentProgramEnrollment")) %>%
  filter(ProgramAcademicCareerLevelCode == "UG",
         ProgramEntryAcademicQtrKeyId >= last.major.yrq5,
         ProgramEntryAcademicQtrKeyId <= max.yrq,
         PreMajorInd == "N",
         VisitingMajorInd == "N",
         Student_ClassCode < 5,
         ProgramEntryInd == "Y",
         DegreeLevelCode == 1) %>%                # degree level code == 1 is supposed to be Bachelor's
  select(sys.key = SDBSrcSystemKey,
         yrq.decl = ProgramEntryAcademicQtrKeyId,
         campus = MajorCampus,
         maj.abbv = MajorAbbrCode,
         maj.path = MajorPathwayNum,
         maj.code = MajorCode,
         prog.code = ProgramCode) %>%
  collect()

# Cumulative GPA when declared major -----------------------------------

# collect quarterly outcomes temporarily, then merge with first quarter in major
x <- tbl(aicon, in_schema("sec", "IV_StudentQuarterlyOutcomes")) %>%
  select(sys.key = SDBSrcSystemKey, yrq = AcademicQtrKeyId, cgpa = OutcomeCumGPA) %>%
  collect()       # forcing the join in the same query is buggy

# Need to spread declaration quarter
pre.maj.gpa <- left_join(maj.first.yrq, x, by = c("sys.key")) %>%
  group_by(sys.key, maj.code) %>%
  filter(yrq < yrq.decl) %>%
  top_n(n = 1, wt = yrq) %>%
  ungroup()

rm(x)

# remove if missing cgpa
pre.maj.gpa <- filter(pre.maj.gpa, !is.na(cgpa))

# table(pre.maj.gpa$yrq >= pre.maj.gpa$yrq.decl, useNA = "ifany")      # should be 100% false


# Transcripts from pre-declared-major quarters ----------------------

# dplyr syntax doesn't have a good way to filter from w/in the query so use this list of students and join
# and the database uses YYYY and Q separately by default

students <- data.frame(system_key = unique(pre.maj.gpa$sys.key))

x <- tbl(sdbcon, in_schema("sec", "transcript_courses_taken")) %>%
  inner_join(students, copy = T) %>%
  filter(deductible == 0,
         !(grade %in% c("S", "NS", "CR", "NC", "W", "HW")),
         grade_system == 0) %>%
  select(sys.key = system_key,
         tran.yr = tran_yr,
         tran.qtr = tran_qtr,
         course.campus = course_branch,
         course.dept = dept_abbrev,
         course.num = course_number,
         course.grade = grade,                  # needs correction later
         course.grade.sys = grade_system) %>%
  collect()

x$tran.yrq <- (x$tran.yr * 10) + x$tran.qtr

# merge with first.yrq and then filter transcripts where yrq > yrq.decl
# this should merge with pre major gpa, not maj.first.yrq b/c maj.first.yrq has students with no prior UW gpa to include
pre.maj.courses <- left_join(pre.maj.gpa, x, by = "sys.key") %>% select(-yrq, -cgpa) %>% group_by(sys.key, maj.code) %>% arrange(sys.key, maj.code, tran.yrq) %>% filter(tran.yrq < yrq.decl)

rm(x)


# course names ------------------------------------------------------------

# campus in this table is associated with the course, not the degree
# create a matching code in the transcript file when merging with this for the longer version of the names

course.names <- tbl(aicon, in_schema("sec", "IV_CourseSections")) %>%
  select(yrq = AcademicQtrKeyId,
         course.code = CourseCode,
         course.lname = CourseLongName,              # fix case in proc script
         course.sname = CourseShortName) %>%
  distinct() %>%
  collect()


# fetch majors from sdb ---------------------------------------------------

# req'd for checking start date for majors in the event that 2/5 years of data aren't available
tb <- tbl(sdbcon, in_schema("sec", "sr_major_code")) %>% collect()
tb$syrq <- (tb$major_first_yr*10) + tb$major_first_qtr
tb$eyrq <- (tb$major_last_yr*10) + tb$major_last_qtr
maj.age <- tb
rm(tb)


# integrity checks so far (wip) --------------------------------------------
  #
  # # tabulate students per major
  # t <- table(pre.maj.gpa$maj.code)
  # cbind(t[order(t)])
  # table(t >= 5)
  # rm(t)
  # # by campus
  # table(pre.maj.gpa$campus)
  # table(pre.maj.gpa$maj.code, pre.maj.gpa$campus)     # should be no cross-over between elements
  #
  # # check that abbv+path aligns with maj.code
  # pre.maj.courses %>% group_by(maj.abbv, maj.path, maj.code) %>% summarize(n())
  # # this results in 304
  # # this could be a consequence of majors with no students enrolled since 20124?
  # # the other maj.first.yrq w/ 81k obs:
  # maj.first.yrq %>% group_by(maj.abbv, maj.path, maj.code) %>% summarize(n())
  # # has 319
  # # check those codes and the sids
  # (i <- setdiff(maj.first.yrq$maj.code, pre.maj.courses$maj.code))      # 15 major codes in maj.first.yrq but not in pre.maj.courses
  # (check <- maj.first.yrq[maj.first.yrq$maj.code %in% i,])              # 77 records with those codes
  # # do any of those students appear at all in the pre.maj.gpa?
  # (pre.maj.gpa[pre.maj.gpa$sys.key %in% check$sys.key,])                # yes
  #
  #
  # # now we should see which kuali majors are/aren't in the other files
  # # kuali code: "A A-0-1-6"
  # # ai code   : "0_MUSIC_00_1_1"
  # ku <- data.frame(str_split(active.majors$maj.key, "-", simplify = T))   # not going to try to do this in a single swoop w/ matrix today
  # active.majors$maj.path <- paste0(ku$X1, ku$X2)
  # mjfi <- unique(paste0(str_trim(maj.first.yrq$maj.abbv), maj.first.yrq$maj.path))
  # mjpr <- unique(paste0(str_trim(pre.maj.gpa$maj.abbv), pre.maj.gpa$maj.path))
  #
  # (i <- setdiff(active.majors$maj.path, mjfi))
  # active.majors[active.majors$maj.path %in% i,]
  #
  # # we will keep all active majors so they will show up in pivot even if no students
  #
  # # check that same num/set of student ids are in both gpa and courses
  # length(unique(pre.maj.gpa$sys.key))
  # length(unique(pre.maj.courses$sys.key))





# Write data ---------------------------------------------------------------

save(programs, creds, major.college, pre.maj.courses, pre.maj.gpa, course.names, maj.age, file = paste0("raw data/raw data_", Sys.Date()))


# Disconnect/close --------------------------------------------------------
# DBI::dbListConnections() doesn't appear to work with odbc()
# I don't trust s/vapply to correctly close each connection in x...
x <- ls(pattern = "con")
for(i in 1:length(x)){
  dbDisconnect(get(x[i]))
}
