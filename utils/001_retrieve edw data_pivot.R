rm(list = ls())
gc()

# setup -------------------------------------------------------------------

library(tidyverse)
library(dbplyr)
library(odbc)
library(keyring)

options(tibble.print_max = 800)

# To access local files/vars that are not part of repo, move up one level from project directory
setwd(rstudioapi::getActiveProject())
setwd("..")
source('pivot_rproj/utils/r_utility_funs.R')

# create connections to enterprise data server
con <- dbConnect(odbc(), 'sqlserver01', PWD = keyring::key_get("sdb"))
aicon <- dbConnect(odbc::odbc(), 'sqlserver01', Database = "AnalyticInteg",
                   PWD = keyring::key_get("sdb"))

# get date for year + quarter ----------------------------------------------------
cal <- tbl(con, in_schema("sec", "sys_tbl_39_calendar")) %>%
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

## get.active.majors

programs <- tbl(con, in_schema('sec', 'CM_Programs')) %>%
  filter(program_type == 'Major',
         program_level == 'Undergraduate') %>%
  collect() %>%
  mutate(program_end = label.to.yrq(program_dateEndLabel)) %>%
  filter(program_end >= max.yrq | is.na(program_end)) %>%
  select(-program_end)

creds <- tbl(con, in_schema('sec', 'CM_Credentials')) %>%
  filter(DoNotPublish %in% c('', 'False', 'false')) %>%
  collect() %>%
  mutate(credential_end = label.to.yrq(credential_dateEndLabel)) %>%
  filter(credential_end >= max.yrq | is.na(credential_end)) %>%
  select(-credential_end)

active.majors <- inner_join(creds, programs, by = c('program_verind_id')) %>%
  distinct(credential_code, .keep_all = T)

rm(programs, creds)


# Student 1st yrq in major ------------------------------------------------

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

get.premajor.gpa <- function(){
  # Collect quarterly outcomes temporarily, then merge with first quarter in major
  x <- tbl(aicon, in_schema("sec", "IV_StudentQuarterlyOutcomes")) %>%
    select(sys.key = SDBSrcSystemKey, yrq = AcademicQtrKeyId, cgpa = OutcomeCumGPA) %>%
    collect()       # this is slower but performing join in the same query is buggy

  # Spread declaration quarter
  pre.maj.gpa <- left_join(maj.first.yrq, x, by = c("sys.key")) %>%
    group_by(sys.key, maj.code) %>%
    filter(yrq < yrq.decl) %>%
    top_n(n = 1, wt = yrq) %>%
    ungroup()

  rm(x)

  # remove if missing cgpa
  pre.maj.gpa <- filter(pre.maj.gpa, !is.na(cgpa))

  return(pre.maj.gpa)
}

pre.maj.gpa <- get.premajor.gpa()

# table(pre.maj.gpa$yrq >= pre.maj.gpa$yrq.decl, useNA = "ifany")      # should be 100% false


# Transcripts from pre-declared-major quarters ----------------------

# dplyr syntax doesn't have a good way to filter from w/in the query so use this list of students and join
# and the database uses YYYY and Q separately by default

get.premaj.courses<- function(){
  students <- data.frame(system_key = unique(pre.maj.gpa$sys.key))

  x <- tbl(con, in_schema("sec", "transcript_courses_taken")) %>%
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
  pre.maj.courses <- left_join(pre.maj.gpa, x, by = "sys.key") %>%
    select(-yrq, -cgpa) %>%
    group_by(sys.key, maj.code) %>%
    arrange(sys.key, maj.code, tran.yrq) %>%
    filter(tran.yrq < yrq.decl)

  return(pre.maj.courses)

}

pre.maj.courses <- get.premaj.courses()

# course names ------------------------------------------------------------

# nb: campus in this table is associated with the _course_, not the degree - the transcript file
# 'branch' as the corresponding field; so create a matching code in the transcript file when merging
# with this for the long names
course.names <- tbl(con, in_schema("sec", "sr_course_titles")) %>%
  collect()

# fetch majors from sdb ---------------------------------------------------

# req'd for checking start date for majors in the event that 2/5 years of data aren't available
maj.age <- tbl(con, in_schema("sec", "sr_major_code")) %>%
  collect() %>%
  mutate(syrq = major_first_yr*10 + major_first_qtr,
         eyrq = major_last_yr*10 + major_last_qtr)

# Write data ---------------------------------------------------------------

save(active.majors, pre.maj.courses, pre.maj.gpa, course.names, maj.age, file = paste0("raw data/raw data_", Sys.Date()))
dbDisconnect(con); rm(con)
dbDisconnect(aicon); rm(aicon)
