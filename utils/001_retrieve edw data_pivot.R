# Fetch EDW data for pivot update

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

# @max.yrq is defined in the config.R file
# define 5yr (20 quarter) upper boundary via config file, then calc 5 or 2 year cutoffs
last.major.yrq5 <- max.yrq - 50

# create connections to enterprise data server
aicon <- dbConnect(odbc::odbc(), dns, Database = dabs[1], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))
sdbcon <- dbConnect(odbc::odbc(), dns, Database = dabs[2], UID = uid, PWD = rstudioapi::askForPassword("pwd-"))

# Active majors >> programs.csv (Kuali dump) -------------------------------------

# FUTURE: this information will come from CM_*
active.majors <- read_csv("raw data/programs-kuali.csv")
active.majors <- active.majors %>%
  filter(program_status == "active",
         grepl("UG-", .$program_code) == T,
         grepl("-MAJOR", .$program_code) == T) %>%
  select(maj.key = code, title, prog.title = program_title, prog.deptcode = program_SDBDeptCode, admission.type = program_admissionType, prog.status = program_status)


# Connect major to FinOrg ---------------------------------------------------------
# Made some post-corrections here after checking in 002 script. There is a mis-match between the SDB data and
# the kuali dump, so I got rid of the active filter
# however, there are duplicate id's in the SDB b/c a major can belong to multiple orgs

# fix code mapping from this <-> kuali in script 002; don't filter these, let kuali record be the filter/truth about active/inactive

major.college <- tbl(aicon, in_schema("sec", "IV_MajorFinancialOrganizations")) %>%
  filter(VisitingMajorInd == "N", PrimaryOrgUnitInd == "Y", PreMajorInd == "N") %>%         # ActiveMajorInd == "Y",
  select(MajorCode, MajorCampus, MajorAbbrCode, MajorPathwayNum, FinCampusReportingName, FinCollegeReportingName, FinDepartmentReportingName) %>%
  collect()


# First YRQ of students’ major(s) -----------------------------------------

# AIDB should make first yrq easier b/c it calculates it automatically in ProgramEntryInd and resolves pre-majors with another flag

# Contrary to some documentation, MajorCode does not fully identify a major b/c it lacks the credential, e.g. BIOL_0 is 1 pathway but 2 degree tracks
# therefore ProgramCode is what we need for building the correct names for the app
# !BUT! this is not the same as program_code in the CM_* tables

maj.first.yrq <- tbl(aicon, in_schema("sec", "IV_StudentProgramEnrollment")) %>%
  filter(ProgramAcademicCareerLevelCode == "UG",
         ProgramEntryAcademicQtrKeyId >= last.major.yrq5,
         ProgramEntryAcademicQtrKeyId <= max.yrq,
         PreMajorInd == "N",
         VisitingMajorInd == "N",
         Student_ClassCode < 5,
         ProgramEntryInd == "Y",
         DegreeLevelCode == 1) %>%                # degree level code == 1 is Bachelor's
  select(system_key = SDBSrcSystemKey,
         yrq.decl = ProgramEntryAcademicQtrKeyId,
         MajorCampus,
         MajorAbbrCode,
         MajorPathwayNum,
         MajorCode,
         ProgramCode,
         DegreeLevelCode,
         DegreeTypeCode) %>%
  collect()


# Cumulative GPA when declared major -----------------------------------
# aicon is not an optimal source for this b/c the data is snapshotted early-ish. However, changing to SWS should fix the lag so there is no need to re-write code to
# use EDW instead of AI


# create a temporary table to hold these cumulative GPAs b/c running the join in the same query seems to be buggy here
temp <- tbl(aicon, in_schema("sec", "IV_StudentQuarterlyOutcomes")) %>%
  select(system_key = SDBSrcSystemKey, yrq = AcademicQtrKeyId, cgpa = OutcomeCumGPA) %>%
  collect()

# I noticed that there isn't outcome data for the most recent yrq, re-wrote solution to accomodate that.
# Join with temporary table -> spreading yrq.decl to students -> group on system_key+major and keep only rows < yrq.decl -> take top row
pre.maj.gpa <- left_join(maj.first.yrq, temp, by = c("system_key")) %>%
  group_by(system_key, ProgramCode) %>%
  filter(yrq < yrq.decl) %>%
  top_n(n = 1, wt = yrq) %>% # %>% filter(!is.na(cgpa))
  distinct() %>%
  ungroup()

# remove missing CGPA's
pre.maj.gpa <- filter(pre.maj.gpa, !is.na(cgpa))

# only keep first major+pathway+degree type
# Is it possible to switch pathways or have two pathways in same quarter? Should that be omitted? Keeping for now, but see also: >> pre.maj.gpa %>% group_by(system_key, MajorAbbrCode) %>% filter(n() > 1)
# There are still some programs that may not require separate applications to the BS v. BA, namely PSYCH
pre.maj.gpa <- pre.maj.gpa %>%
  group_by(system_key, MajorAbbrCode, DegreeTypeCode) %>%
  filter(yrq.decl == min(yrq.decl)) %>%
  ungroup()

rm(temp)

# Transcripts from pre-declared-major quarters ----------------------

# dplyr syntax doesn't have a good way to filter from w/in the query so use this list of students and join
# and the database uses YYYY and Q separately by default
temp <- data.frame(system_key = unique(pre.maj.gpa$system_key))

students <- tbl(sdbcon, in_schema("sec", "transcript_courses_taken")) %>%
  inner_join(temp, copy = T) %>%
  filter(deductible == 0,
         !(grade %in% c("S", "NS", "CR", "NC", "W", "HW")),
         grade_system == 0) %>%
  select(system_key = system_key,
         tran.yr = tran_yr,
         tran.qtr = tran_qtr,
         course.campus = course_branch,
         course.dept = dept_abbrev,
         course.num = course_number,
         course.grade = grade,                  # needs correction later
         course.grade.sys = grade_system) %>%
  collect()

students$tran.yrq <- (students$tran.yr * 10) + students$tran.qtr

# merge with first.yrq and then filter transcripts where yrq > yrq.decl
# this should merge with pre major gpa, not maj.first.yrq b/c maj.first.yrq has students with no prior UW gpa to include
pre.maj.courses <- left_join(pre.maj.gpa, students, by = "system_key") %>%
  select(-yrq, -cgpa) %>%
  group_by(system_key, ProgramCode) %>%
  arrange(system_key, ProgramCode, tran.yrq) %>%
  filter(tran.yrq < yrq.decl) %>%
  distinct() %>%
  ungroup()

rm(temp)

# course names ------------------------------------------------------------

# nb: campus in this table is associated with the course, not the degree - the transcript file
# 'branch' as the corresponding field; so create a matching code in the transcript file when merging
# with this for the long names
course.names <- tbl(aicon, in_schema("sec", "IV_CourseSections")) %>%
  select(yrq = AcademicQtrKeyId,
         CourseCode,
         CourseLongName,              # fix case in proc script
         CourseShortName) %>%
  collect() %>%
  distinct()


# fetch majors from sdb ---------------------------------------------------

# req'd for checking start date for majors in the event that 2/5 years of data aren't available
maj.age <- tbl(sdbcon, in_schema("sec", "sr_major_code")) %>% collect()

maj.age$syrq <- (maj.age$major_first_yr*10) + maj.age$major_first_qtr
maj.age$eyrq <- (maj.age$major_last_yr*10) + maj.age$major_last_qtr


# # integrity checks so far (wip) --------------------------------------------
#
# rm(x, tb)
#
# # tabulate students per major
# t <- table(pre.maj.gpa$maj.code)
# cbind(t[order(t)])
# table(t >= 5)
# rm(t)
# # by campus
# table(pre.maj.gpa$campus)
# table(pre.maj.gpa$maj.code, pre.maj.gpa$campus)     # ok, no x-over, that's a good sign
#
# # check that abbv+path aligns with maj.code
# # there are 361 active majors in kuali
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
# (pre.maj.gpa[pre.maj.gpa$system_key %in% check$system_key,])                # yes
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
# length(unique(pre.maj.gpa$system_key))
# length(unique(pre.maj.courses$system_key))





# Write data ---------------------------------------------------------------

save(active.majors, major.college, pre.maj.courses, pre.maj.gpa, course.names, maj.age, file = paste0("raw data/raw data_", Sys.Date()))


# Disconnect/close --------------------------------------------------------
# DBI::dbListConnections() doesn't appear to work with odbc()
# I don't trust s/vapply to correctly close each connection in x...
x <- ls(pattern = "con")
for(i in 1:length(x)){
  dbDisconnect(get(x[i]))
}
