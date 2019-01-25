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
# but - to start (a tiny bit) more safely:
setwd(rstudioapi::getActiveProject())
setwd("..")

source("scripts/config.R")

# create connections to enterprise data server
aicon <- dbConnect(odbc::odbc(), dns, Database = dabs[1], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))
sdbcon <- dbConnect(odbc::odbc(), dns, Database = dabs[2], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))

# get date <-> quarter from SDB ----------------------------------------------------
cal <- tbl(sdbcon, in_schema("sec", "sys_tbl_39_calendar")) %>%
  filter(first_day >= "2018-01-01") %>%
  select(table_key, first_day, grade_submit_ddln) %>%
  collect() %>%
  mutate(fd_next = lead(first_day),
         grade_dl_next = lead(grade_submit_ddln),
         yrq = as.numeric(str_sub(table_key, start = 2)),
         yrq_last = lag(yrq))

max.yrq <- cal$yrq[(Sys.Date() >= cal$grade_submit_ddln) & (Sys.Date() <= cal$grade_dl_next)]
# For 5 years of data:
last.major.yrq5 <- max.yrq - 50
rm(cal)

# [TODO]
# CM in SDB to replace Kuali csv ------------------------------------------------

programs <- tbl(sdbcon, in_schema("sec", "CM_Programs")) %>% collect()
creds <- tbl(sdbcon, in_schema("sec", "CM_Credentials")) %>% collect()


# Major to FinOrg ---------------------------------------------------------

# Made some post-corrections here after checking in 002 script. There is a mis-match between the EDW data and
# the kuali dump, so I got rid of the active filter
# however, there are duplicate id's in the EDW b/c a major can belong to multiple orgs
major.college <- tbl(aicon, in_schema("sec", "IV_MajorFinancialOrganizations")) %>%
  filter(VisitingMajorInd == "N", PrimaryOrgUnitInd == "Y", PreMajorInd == "N") %>%         # ActiveMajorInd == "Y",
  select(MajorCampus, FinCampusReportingName, FinCollegeReportingName, MajorAbbrCode, MajorPathwayNum, MajorCode) %>%
  collect()


# First YRQ of students’ major(s)  and cumulative GPA before declared -----------------------------------------

# AIDB should make first yrq easier b/c it calculates it automatically in ProgramEntryInd
# and resolves pre-majors with another flag

# re: MajorCode: Code that fully identifies the major.
# A concatenation of the MajorCampus, MajorAbbrCode, and MajorPathwayNum (each separated by underscores) e.g. '0_BIOL_10'.
# https://canvas.uw.edu/courses/1061200/pages/studentprogramenrollment


# We need credential code and level in order to match the CM data for credentials and
# to make sure we get all the BA/BS degrees that aren't standard (e.g. they have the same pathway but a different level)
maj.first.yrq <- tbl(aicon, in_schema("sec", "IV_StudentProgramEnrollment")) %>%
  filter(ProgramAcademicCareerLevelCode == "UG",
         ProgramEntryAcademicQtrKeyId >= last.major.yrq5,
         ProgramEntryAcademicQtrKeyId <= max.yrq,
         PreMajorInd == "N",
         VisitingMajorInd == "N",
         Student_ClassCode < 5,
         ProgramEntryInd == "Y",
         DegreeLevelCode == 1)            # degree level code == 1 is Bachelor's

sqo <- tbl(aicon, in_schema("sec", "IV_StudentQuarterlyOutcomes")) %>%
  select(SDBSrcSystemKey, yrq = AcademicQtrKeyId, cgpa = OutcomeCumGPA)

# I noticed in doing integrity check (below) that there isn't outcome data for most recent yrq, re-wrote solution to accomodate that
# join, spreading yrq.decl, group on sys.key+major, keep only rows < yrq.decl, take top row
pre.maj.gpa <- left_join(maj.first.yrq, sqo, by = "SDBSrcSystemKey" ) %>%
  group_by(SDBSrcSystemKey, ProgramCode) %>%
  filter(yrq < ProgramEntryAcademicQtrKeyId) %>%
  top_n(n = 1, wt = yrq) %>%
  collect() %>%
  ungroup()

# how many w/ missing cgpa?
table(is.na(pre.maj.gpa$cgpa))
# remove:
pre.maj.gpa <- filter(pre.maj.gpa, !is.na(cgpa))

table(pre.maj.gpa$yrq >= pre.maj.gpa$AcademicQtrKeyId, useNA = "ifany")      # should be 100% false

# Transcripts from pre-declared-major quarters ----------------------

# use this list of unique system_keys (students) and join
# the SDB uses YYYY and Q separately by default

students <- data.frame(system_key = unique(pre.maj.gpa$SDBSrcSystemKey))

tct <- tbl(sdbcon, in_schema("sec", "transcript_courses_taken")) %>%
  inner_join(students, copy = T) %>%
  filter(deductible == 0,
         !(grade %in% c("S", "NS", "CR", "NC", "W", "HW")),
         grade_system == 0) %>%
  select(system_key,
         tran_yr,
         tran_qtr,
         course_branch,
         dept_abbrev,
         course_number,
         grade,
         grade_system)

# merge with first.yrq and then filter transcripts where yrq > yrq.decl
# this should merge with pre major gpa, not maj.first.yrq b/c maj.first.yrq has students with no prior UW gpa to include
pre.maj.courses <- left_join(pre.maj.gpa, tct, by = c("SDBSrcSystemKey" = "system_key"), copy = T) %>%
  select(-yrq, -cgpa) %>%
  mutate(tran.yrq = tran_yr*10 + tran_qtr) %>%
  filter(tran.yrq < AcademicQtrKeyId) %>%             # removed unecessary group_by()
  arrange(SDBSrcSystemKey, ProgramCode, tran.yrq)


# course names ------------------------------------------------------------

# collect all, process later
course.names <- tbl(sdbcon, in_schema("sec", "sr_course_titles")) %>%
  select(department_abbrev, course_number, last_eff_yr, last_eff_qtr, course_branch, long_course_title) %>%
  collect()

# fetch majors from sdb ---------------------------------------------------

# req'd for checking start date for majors in the event that 2/5 years of data aren't available
maj.age <- tbl(sdbcon, in_schema("sec", "sr_major_code")) %>%
  collect() %>%
  mutate(syrq = major_first_yr*10 + major_first_qtr,
         eyrq = major_last_yr*10 + major_last_qtr)

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
x <- ls(pattern = "con")
for(i in 1:length(x)){
  dbDisconnect(get(x[i]))
}
