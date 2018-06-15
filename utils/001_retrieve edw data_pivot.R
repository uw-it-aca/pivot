# Fetch EDW data for pivot update

rm(list = ls())
gc()

# setup -------------------------------------------------------------------

library(tidyverse)
library(dbplyr)
library(odbc)

# I'm using tb, x, and y as temporary/intermediate vars which shouldn't scope outside of their sections

# helper function - create quoted vector, i.e. c(), from unquoted text
# not intended to smoothly handle punctuation but can be coerced a little, e.g. Cs(a, b, "?")
Cs <- function(...){as.character(sys.call())[-1]}
options(tibble.print_max = 800)

# To access local files/vars that are not part of repo, move up one level from project directory
# but - to start (a tiny bit) more safely:
setwd(rstudioapi::getActiveProject())
setwd("..")

source("scripts/config.R")

# create connections to enterprise data server
aicon <- dbConnect(odbc::odbc(), dns, Database = dabs[1], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))
sdbcon <- dbConnect(odbc::odbc(), dns, Database = dabs[2], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))

# Active majors >> programs.csv (Kuali dump) -------------------------------------

tb <- read_csv("raw data/programs-kuali.csv")
active.majors <- tb %>%
  filter(program_status == "active",
         grepl("UG-", .$program_code) == T,
         grepl("-MAJOR", .$program_code) == T) %>%
  select(maj.key = code, title, prog.code = program_code, prog.title = program_title, prog.deptcode = program_SDBDeptCode, admission.type = program_admissionType, prog.status = program_status)

# The kuali data doesn't have campus or college fields
# so we also need:

# Major to FinOrg ---------------------------------------------------------
rm(tb)

# Made some post-corrections here after checking in 002 script. There is a mis-match between the EDW data and
# the kuali dump, so I got rid of the active filter
# however, there are duplicate id's in the EDW b/c a major can belong to multiple orgs

tb <- tbl(aicon, in_schema("sec", "IV_MajorFinancialOrganizations"))
major.college <- tb %>%
  filter(VisitingMajorInd == "N", PrimaryOrgUnitInd == "Y", PreMajorInd == "N") %>%         # ActiveMajorInd == "Y",
  select(MajorCampus, FinCampusReportingName, FinCollegeReportingName, MajorAbbrCode, MajorPathwayNum, MajorCode) %>%
  collect()
# fix code mapping from this <-> kuali in script 002
# and - don't filter these, let kuali record be the filter/truth about active/inactive


# First YRQ of students’ major(s) -----------------------------------------
rm(tb)

# dbListTables(aicon)
tb <- tbl(aicon, in_schema("sec", "IV_StudentProgramEnrollment"))
# this new AIDB should make first yrq easier b/c it calculates it automatically in ProgramEntryInd
# and resolves pre-majors with another flag

# re: MajorCode: Code that fully identifies the major.
# A concatenation of the MajorCampus, MajorAbbrCode, and MajorPathwayNum (each separated by underscores) e.g. '0_BIOL_10'.
# https://canvas.uw.edu/courses/1061200/pages/studentprogramenrollment


maj.first.yrq <- tb %>%
  filter(ProgramAcademicCareerLevelCode == "UG",
         ProgramEntryAcademicQtrKeyId >= 20124,
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
rm(tb)

# Future: if tables are too large for collect() to be efficient then try creating temp tables, i.e. compute(name = 'something useful')
tb <- tbl(aicon, in_schema("sec", "IV_StudentQuarterlyOutcomes"))
x <- tb %>% select(sys.key = SDBSrcSystemKey, yrq = AcademicQtrKeyId, cgpa = OutcomeCumGPA) %>% collect()       # forcing the join in the same query is buggy


# I noticed in doing integrity check (below) that there isn't outcome data for most recent yrq, re-wrote solution to accomodate that
# join, spreading yrq.decl, group on sys.key+major, keep only rows < yrq.decl, take top row
pre.maj.gpa <- left_join(maj.first.yrq, x, by = c("sys.key")) %>% group_by(sys.key, maj.code) %>% filter(yrq < yrq.decl) %>% top_n(n = 1, wt = yrq) # %>% filter(!is.na(cgpa))

# how many w/ missing cgpa?
table(is.na(pre.maj.gpa$cgpa))
# remove:
pre.maj.gpa <- filter(pre.maj.gpa, !is.na(cgpa))

table(pre.maj.gpa$yrq >= pre.maj.gpa$yrq.decl)      # should be 100% false

# for curiousity's sake:
d <- pre.maj.gpa %>%
  ungroup() %>%
  select(yrq.decl, yrq) %>%
  mutate(yra = yrq.decl %/% 10,
         qa = yrq.decl %% 10,
         yrb = yrq %/% 10,
         qb = yrq %% 10,
         yd = (yra - yrb) * 4,
         qd = qa - qb,
         tot = yd + qd)
cbind(table(d$tot))
table(cut(d$tot, 5))


# Transcripts from pre-declared-major quarters ----------------------
rm(x, y, tb)

# dplyr syntax doesn't have a good way to filter from w/in the query so use this list of students and join
# and the database uses YYYY and Q separately by default

tb <- tbl(sdbcon, in_schema("sec", "transcript_courses_taken"))

students <- data.frame(system_key = unique(pre.maj.gpa$sys.key))

x <- tb %>%
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


# course names ------------------------------------------------------------
rm(x, y, tb)

tb <- tbl(aicon, in_schema("sec", "IV_CourseSections"))
# nb: campus in this table is associated with the course, not the degree - the transcript file
# 'branch' as the corresponding field; so create a matching code in the transcript file when merging
# with this for the long names
course.names <- tb %>%
  select(yrq = AcademicQtrKeyId,
         course.code = CourseCode,
         course.lname = CourseLongName,              # fix case in proc script
         course.sname = CourseShortName) %>%
  distinct() %>%
  collect()


# integrity checks so far (wip) --------------------------------------------

rm(x, y, tb)

# tabulate students per major
t <- table(pre.maj.gpa$maj.code)
cbind(t[order(t)])
table(t >= 5)
rm(t)
# by campus
table(pre.maj.gpa$campus)
table(pre.maj.gpa$maj.code, pre.maj.gpa$campus)     # ok, no x-over, that's a good sign

# check that abbv+path aligns with maj.code
# there are 361 active majors in kuali
pre.maj.courses %>% group_by(maj.abbv, maj.path, maj.code) %>% summarize(n())
# this results in 304
# this could be a consequence of majors with no students enrolled since 20124?
# the other maj.first.yrq w/ 81k obs:
maj.first.yrq %>% group_by(maj.abbv, maj.path, maj.code) %>% summarize(n())
# has 319
# check those codes and the sids
(i <- setdiff(maj.first.yrq$maj.code, pre.maj.courses$maj.code))      # 15 major codes in maj.first.yrq but not in pre.maj.courses
(check <- maj.first.yrq[maj.first.yrq$maj.code %in% i,])              # 77 records with those codes
# do any of those students appear at all in the pre.maj.gpa?
(pre.maj.gpa[pre.maj.gpa$sys.key %in% check$sys.key,])                # yes


# now we should see which kuali majors are/aren't in the other files
# kuali code: "A A-0-1-6"
# ai code   : "0_MUSIC_00_1_1"
ku <- data.frame(str_split(active.majors$maj.key, "-", simplify = T))   # not going to try to do this in a single swoop w/ matrix today
active.majors$maj.path <- paste0(ku$X1, ku$X2)
mjfi <- unique(paste0(str_trim(maj.first.yrq$maj.abbv), maj.first.yrq$maj.path))
mjpr <- unique(paste0(str_trim(pre.maj.gpa$maj.abbv), pre.maj.gpa$maj.path))

(i <- setdiff(active.majors$maj.path, mjfi))
active.majors[active.majors$maj.path %in% i,]

# we will keep all active majors so they will show up in pivot even if no students

# check that same num/set of student ids are in both gpa and courses
length(unique(pre.maj.gpa$sys.key))
length(unique(pre.maj.courses$sys.key))


# Write data ---------------------------------------------------------------

save(active.majors, major.college, pre.maj.courses, pre.maj.gpa, course.names, file = paste0("raw data/raw data_", Sys.Date()))


# Disconnect/close --------------------------------------------------------
# DBI::dbListConnections() doesn't appear to work with odbc()
# I don't trust s/vapply to correctly close each connection in x...
x <- ls(pattern = "con")
for(i in 1:length(x)){
  dbDisconnect(get(x[i]))
}
