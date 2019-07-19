
## Update on re-factoring with CM data - the holdup now is that Bothell/Tacoma 'college' is not up to date
## in the CM SDB tables

rm(list = ls())
gc()

# setup -------------------------------------------------------------------

library(tidyverse)

# File for processing EDW data to create pivot files
# To access local files/vars that are not part of repo, move up one level from project directory.
# This is included to 'reset' 002 in the event that 001 > 002 aren't being
# run in the same session.
setwd(paste0(rstudioapi::getActiveProject(), "/.."))

# in case there are multiple raw data files, load the most recently created
f <- list.files("raw data/", pattern = "raw", full.names = T)
f <- f[which.max(file.mtime(f))]
load(f); rm(f)

# function to created quoted character vectors from unquoted text
#
# input: unquoted text as in Cs(x, y, z)
Cs <- function(...) {as.character(sys.call())[-1]}


# [NICETOHAVE] a not-in function around [!(x %in% y)]

# function to strip whitespace, alternative to `mutate_if(is.character, ...)` that does not depend on dplyr/tidyverse
#
# input: a dataframe
# return: dataframe
df.trimws <- function(df){
  i <- sapply(df, is.character)
  df[i] <- lapply(df[i], trimws)
  return(df)
}

# make file name prefix from max.yrq
mk.prefix <- function(x){
  q <- x %% 10
  y <- (x %/% 10) - 2000  # diff from yr 2000; [TODO] make this an argument
  q <- c("wi", "sp", "su", "au")[q]
  return(paste0(q, y, "_20qtrs"))
}

# calculate the difference between two quarters
qtr.diff <- function(x, y){
  (((x %/% 10) - (y %/% 10)) * 4) + ((x %% 10) - (y %% 10))
}

# Trim WS from everything
l <- ls()
# apply(l, function(x) {
#   cur <- get(x)
#   if(is.data.frame(cur)){
#
#   }
# })
for(i in 1:length(l)){
  cur.df <- get(l[i])
  if(is.data.frame(cur.df)){
    cur.df <- df.trimws(cur.df)
    assign(l[i], cur.df)
  }
}
rm(l, cur.df, i)

# setup maximum data year-quarter and file prefix
# using max available yrq from transcripts to set upper boundary
max.yrq <- max(pre.maj.courses$tran.yrq)
prefix <- mk.prefix(max.yrq)

# CM major codes ---------------------------------------------------

active.majors$campus_num <- case_when(active.majors$campus_name == "Seattle"~ 0,
                                      active.majors$campus_name == "Bothell" ~ 1,
                                      active.majors$campus_name == "Tacoma" ~ 2)

# programs <- programs %>%
#   filter(program_status == "active",
#          str_sub(program_code, 1, 2) == "UG",
#          grepl("MAJOR", program_code, ignore.case = F) == T)
# programs <- df.trimws(programs)
#
# x <- data.frame(str_split(creds$credential_code, "-", simplify = T))
# names(x) <- c("cred_abbv", "cred_pathway", "cred_level_code", "cred_degree_type_code")
# creds <- bind_cols(creds, x)
# rm(x)
#
# creds <- creds %>%
#   filter(grepl("true", DoNotPublish, ignore.case = T) == F,
#          credential_status == "active",
#          cred_level_code == 1,
#          cred_degree_type_code <= 8)
# creds <- df.trimws(creds)
#
# active.majors <- inner_join(creds, programs, by = "program_verind_id") %>%
#   distinct(credential_code, .keep_all = T) %>%
#   mutate(mkey = paste(cred_abbv, cred_pathway, sep = "_"))

# add compatible key to active majors
# the transcript files use _left_ padding on the pathway for the string codes when
# the path column is converted to a program code
# So either the active.majors + maj.age need to be modified or the transcript-based files need
# to be changed. Technically they both need some modifications. I'm now wondering if it
# wouldn't be better to merge on multiple fields and create the key later (maybe, maybe not).
# My guess is that this is some function of the SDB penchant for storing things as strings

# Also worth noting is that program code means something different in the new CM tables where
# it indicates "level-dept abbv-major/minor"

(x <- str_split(active.majors$credential_code, "_", simplify = T))

active.majors$credential_code <- str_replace_all(active.majors$credential_code, "-", "_")

# for course code (try: split on \\_[\\D])
# course.names$ckey <- str_sub(course.names$course.code, start = str_locate(course.names$course.code, "\\_\\D")[,2])
course.names$ckey <- paste(course.names$department_abbrev, course.names$course_number, sep = "_")
pre.maj.courses$ckey <- paste(pre.maj.courses$course.dept, pre.maj.courses$course.num, sep = "_")

# course names cleanup -------------------------------------------

course.names$yrq <- course.names$last_eff_yr*10 + course.names$last_eff_qtr

# take most recent, fix case(s) if necessary

# take only most recent year for the name
course.names <- course.names %>% group_by(course_branch, ckey) %>% filter(yrq == max(yrq))

# first - check if string is all uppercase; x == toupper(x)
  # i <- course.names$long_course_title == toupper(course.names$long_course_title)
  # table(i)
  # course.names$long_course_title[i]
  # course.names$long_course_title[i] <- str_to_title(course.names$long_course_title[i])
course.names$course.lname <- course.names$long_course_title

# re: long names, the base r solution is *extremely* slow(?)
# tools::toTitleCase(tolower(course.names$course.lname))
# also the names are about 35% space-padding by volume :P
# the tools option is supposed to ignore certain words that shouldn't be upper case in
# English titles, e.g. 'and' or 'in', but the runtime is just too slow to be feasible.
# I'd expect 360k cases, vectorized over char+column, to run in a few seconds (trimming spaces occurs in ~.25s)
# stringr has a wrapper for stringi's to_title which is fast. Just check for "i" needing conversion to "I" (1)
# Also: i'm going to leave X-y as-is even though words like X-ray should by X-y.

# Then need to fix roman numerals - there is a roman class in base r but it's not a lot of help as-is
# because the numerals are embedded in strings
# grep("ii", course.names$course.lname, value = T)
# chars can occur in the middle of a string, not just the end so I'm going to try to capture most cases
# the one I'm concerned about is:
# grep("vi", course.names$course.lname, value = T)      # civ, environ, survival, violin, &c.
# grep(" vi", course.names$course.lname, value = T)
# so it needs to be something like: space vi space OR space vi colon
# nothing appears to go past VIII

# Steps:
# lowercase conversion
# fix roman numerals
# not analyzing or fixing actual typos

course.names$course.lname <- tolower(course.names$course.lname)
course.names$course.lname <- str_to_title(course.names$course.lname)

course.names$course.lname <- str_replace_all(course.names$course.lname, "I[i]+", toupper)    # appears to work for II and III correctly
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\ Vi[i]+", toupper)  # appears correct for VII+
# lastly, Vi > VI: space Vi followed by either : or eol
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\sVi\\:", toupper)
course.names$course.lname <- str_replace_all(course.names$course.lname, "\\sVi$", toupper)

course.names <- course.names %>%
  select(campus = course_branch, ckey, course.lname)

# Update grades in courses -------------------------------------

# ref: https://www.washington.edu/students/gencat/front/Grading_Sys.html
# I'm using the tops of the ranges
pre.maj.courses$course.grade <- recode(pre.maj.courses$course.grade,
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
                                       "E"  = "00")
pre.maj.courses <- pre.maj.courses %>%
  mutate(grade = as.numeric(course.grade) / 10) %>%
  filter(is.na(grade) == F)

# remove duplicate quarterly enrollments
i <- pre.maj.courses %>% ungroup() %>% select(sys.key, prog.code, ckey, tran.yrq) %>% duplicated(); table(i)
pre.maj.courses <- pre.maj.courses[i == F,]
rm(i)

# verify everything in active majors is active:
unique(active.majors$program_status)

# and the program school/college
unique(active.majors$program_school_or_college)

# kuali names for programs need to be split from the credential
# unfortunately, there are a few that are just "Bachelor of XXX" instead of "in XXX"
active.majors$maj.name <- str_sub(active.majors$credential_title, start = str_locate(active.majors$credential_title, "in\\s")[,2]+1)
# using indexing instead of manually changing
i <- is.na(active.majors$maj.name)
active.majors$maj.name[i] <- str_sub(active.majors$credential_title[i], start = str_locate(active.majors$credential_title[i], "of\\s")[,2]+1)
table(is.na(active.majors$maj.name))


# fix the list of titles that have XXX_0_1_1/5 but title is the same, e.g. Chemistry/Chemistry ----------------------------------

# another nice to have: this should be a function

# ANTH has several more that aren't 0_1_1/5
abbvs <- c("B CHEM", "B PHYS", "CHEM", "ECON", "INDIV", "MATH", "OCEAN", "PH", "PSYCH", "TCSCI")
anth <- c("ANTH_0_1_1", "ANTH_10_1_1", "ANTH_30_1_1", "ANTH_40_1_1")
anthbs <- c("ANTH_0_1_5", "ANTH_10_1_5", "ANTH_30_1_5", "ANTH_40_1_5")
(ba <- c(anth, sapply(abbvs, function(x) paste0(x, "_0_1_1"), simplify = T, USE.NAMES = F)))
(bs <- c(anthbs, sapply(abbvs, function(x) paste0(x, "_0_1_5"), simplify = T, USE.NAMES = F)))

i <- active.majors$credential_code %in% ba
active.majors$maj.name[i] <- paste(active.majors$maj.name[i], "(BA)",  sep = " ")

i <- active.majors$credential_code %in% bs
active.majors$maj.name[i] <- paste(active.majors$maj.name[i], "(BS)",  sep = " ")

rm(abbvs, anth, anthbs, i, ba, bs)

# Create the common credential code for pre major courses and pre major gpa ----------------------------------

x <- str_split(pre.maj.courses$prog.code, "_", simplify = T)
x[,3] <- as.numeric(x[,3])
pre.maj.courses$credential_code <- paste(x[,2], x[,3], x[,4], x[,5], sep = "_")

x <- str_split(pre.maj.gpa$prog.code, "_", simplify = T)                          # this file has path as a numeric var but still need the other two elements
x[,3] <- as.numeric(x[,3])
pre.maj.gpa$credential_code <- paste(x[,2], x[,3], x[,4], x[,5], sep = "_")

rm(x)


###
#  ! At this point it's a good idea to do some validation of the !(%in%) between active.majors and pre.maj.courses
# IE:
pmc.not.active <- pre.maj.courses[!(pre.maj.courses$credential_code %in% active.majors$credential_code),]
active.no.students <- active.majors[!(active.majors$credential_code %in% pre.maj.courses$credential_code),]
# It's helpful to know that it's not user-error in the code that creates the non-overlap (since there are irregularities in the numeric conventions)
###

pre.maj.courses <- pre.maj.courses[pre.maj.courses$credential_code %in% active.majors$credential_code,]
pre.maj.gpa <- pre.maj.gpa[pre.maj.gpa$credential_code %in% active.majors$credential_code,]


# add "college" and calc n, iqr for majors -----------------------------------------------------
pre.maj.gpa$campus <- as.numeric(pre.maj.gpa$campus)
pre.maj.gpa <- pre.maj.gpa %>% inner_join(active.majors, by = c("credential_code" = "credential_code", "campus" = "campus_num"))

med.tot <- pre.maj.gpa %>%
  group_by(campus, credential_code, program_school_or_college) %>%
  summarize(count = n(),
            # campus = max(campus),
            q1 = quantile(cgpa, .25),
            median = median(cgpa),
            q3 = quantile(cgpa, .75),
            iqr_min = q1 - IQR(cgpa),
            iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
  ungroup()

# med.ann <- pre.maj.gpa %>%
#   mutate(yr.decl = yrq.decl %/% 10) %>%
#   group_by(campus, credential_code, program_school_or_college, yr.decl) %>%
#   summarize(count = n(),
#             # campus = max(campus),
#             q1 = quantile(cgpa, .25),
#             median = median(cgpa),
#             q3 = quantile(cgpa, .75),
#             iqr_min = q1 - IQR(cgpa),
#             iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
#   ungroup()

# Calc rankings for courses by majors; add additional fields for final file -------------------------------------

# check for courses without names: (SHOULD BE FIXED USING SDB INSTEAD OF AI)
i <- !(pre.maj.courses$ckey %in% course.names$ckey)
table(i)
cbind(sort(unique(pre.maj.courses$ckey[i])))
any(course.names == "")

course.rank <- pre.maj.courses %>%
  filter(ckey %in% course.names$ckey) %>%
  group_by(credential_code, ckey) %>%
  summarize(n.course = n(), mgrade = median(grade)) %>%
  arrange(desc(n.course), .by_group = T) %>%
  filter(row_number() <= 10) %>%
  mutate(pop = seq_along(n.course)) %>%
  ungroup()

nrow(course.rank) / length(unique(course.rank$credential_code))      # some may not have 10
course.rank %>% group_by(credential_code) %>% filter(max(pop) < 10)  # examine

# need: long name, major name, and campus (for MAJOR) are supposed to be numeric codes
course.names$ckey.num <- seq_along(course.names$ckey)
active.majors$mkey.num <- seq_along(active.majors$credential_code)

c <- course.names %>% ungroup() %>% select(ckey, ckey.num)
course.rank <- course.rank %>% left_join(c, by = "ckey")
m <- active.majors %>% select(credential_code, mkey.num, campus_name)
course.rank <- course.rank %>% left_join(m, by = "credential_code")
m <- med.tot %>% select(credential_code, count)
course.rank <- course.rank %>% left_join(m, by = "credential_code")

# check: number in course should (usually) not exceed total in major:
any(course.rank$n.course > course.rank$count)
course.rank[course.rank$n.course > course.rank$count,]

course.rank$n.course <- ifelse(course.rank$n.course > course.rank$count, course.rank$count, course.rank$n.course)
table(course.rank$n.course > course.rank$count)

# # run script to boxplot all the majors+pathways?
# # source("one script to print them all.R")


# Create data map -------------------------------------

# course.map <- course.names[course.names$ckey %in% course.rank$ckey,]    # only using the course names we need to display, not the complete list
course.map <- course.names %>%
  ungroup() %>%
  filter(ckey %in% course.rank$ckey) %>%
  mutate(is_course = 1,
         is_major = 0,
         is_campus = 0) %>%
  select(is_course,
         is_major,
         is_campus,
         name = course.lname,
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
         id = mkey.num,
         key = credential_code)

campus.map <- data.frame(is_course = 0,
                         is_major = 0,
                         is_campus = 1,
                         name = c("Seattle",
                                  "Bothell",
                                  "Tacoma"),
                         id = c(0,1,2),
                         key = c('0','1','2'),
                         stringsAsFactors = F)

data.map <- bind_rows(course.map, major.map, campus.map)
rm(campus.map, course.map, major.map)


# create student.data.all.majors (med.tot) ------------------------------------------

student.data.all.majors <- med.tot %>%
  select(major_path = credential_code, college = program_school_or_college, count, iqr_min, q1, median, q3, iqr_max)
# edit rows with count < 5
cols <- Cs(count, iqr_min, q1, median, q3, iqr_max)
student.data.all.majors[,cols] <- lapply(student.data.all.majors[,cols], function(x) ifelse(student.data.all.majors$count < 5, -1, x))

# add majors that are active but have no students
active.no.stu <- active.majors %>%
  filter(!(credential_code %in% med.tot$credential_code)) %>%
           select(major_path = credential_code, college = program_school_or_college) %>%
  mutate(count = -1, iqr_min = -1, q1 = -1, median = -1, q3 = -1, iqr_max = -1)

student.data.all.majors <- bind_rows(student.data.all.majors, active.no.stu)


# status lookup + age -----------------------------------------------------------

# status lookup does not need to replicate names from data.map (but it's useful for error checking)
status.lookup <- active.majors %>% select(code = credential_code, name = maj.name, status = program_admissionType)

maj.age$credential_code <- paste(maj.age$major_abbr, maj.age$major_pathway, maj.age$major_default_lvl, maj.age$major_default_typ, sep = "_")


# a <- maj.age
#
# (x <- str_split(status.lookup$code, "_", simplify = T))
# x <- sort(paste(x[,1], x[,2], sep = "_"))
# y <- sort(unique(paste(a$major_abbr, a$major_pathway, sep = "_")))
# all(x %in% y)
# y <- y[y %in% x]
# # ok...
#
# # try: lvl, w/o type
# x <- sort(str_sub(status.lookup$code, end = -3))
# y <- sort(unique(paste(a$major_abbr, a$major_pathway, a$major_default_lvl, sep = "_")))  # , a$major_default_typ, sep = "_")))
# all(x %in% y)
# sum(x %in% y)         # missing 4 is an improvement over ^^^
# (z <- x[!(x %in% y)])
# zz <- c()
# for(i in 1:length(z)){
#   zz <- c(zz, (grep(z[i], active.majors$credential_code, value = T)))
# }
# View(active.majors[active.majors$credential_code %in% zz,])
# View(pre.maj.courses[pre.maj.courses$credential_code %in% zz,])

# AGE
# step 1: use maj.age for as many as possible
# step 2: use pre.maj.courses data for the remaining credentials

ma <- maj.age %>%
  mutate(len = qtr.diff(eyrq, syrq),
         len = if_else(len < 0, 0, len)) %>%
  group_by(credential_code) %>%
  summarize(quarters_of_data = sum(len)) %>%
  ungroup() %>%
  mutate(quarters_of_data = if_else(quarters_of_data > 20, 20, quarters_of_data))

(i <- status.lookup$code[!(status.lookup$code %in% ma$credential_code)])
any(i %in% active.no.students$credential_code)
i <- i[!(i %in% active.no.students$credential_code)]
all(i %in% pre.maj.courses$credential_code)
i <- i[!(i %in% pre.maj.courses$credential_code)]
ma2 <- pre.maj.courses %>%
  filter(credential_code %in% i) %>%
  group_by(credential_code) %>%
  summarize(quarters_of_data = qtr.diff(max(tran.yrq), min(tran.yrq))) %>%
  ungroup() %>%
  mutate(quarters_of_data = if_else(quarters_of_data > 20, 20, quarters_of_data))

ages <- rbind(ma, ma2)

status.lookup <- status.lookup %>%
  left_join(ages, by = c("code" = "credential_code")) # %>% distinct() %>% select(-name)
x <- status.lookup$code[is.na(status.lookup$quarters_of_data)]
all(x %in% active.no.students$credential_code)
status.lookup$quarters_of_data[is.na(status.lookup$quarters_of_data)] <- 0
rm(ma, ma2, x, y, z, zz, i, ages)


# Course.major.rankings ---------------------------------------------------

course.rank <- course.rank %>% select(major_path = credential_code, course_num = ckey, student_count = n.course,
                                      students_in_major = count, course_gpa_50pct = mgrade,
                                      course_popularity_rank = pop, campus = campus_name)
i <- course.rank$students_in_major < 5
cols <- Cs(student_count, students_in_major, course_gpa_50pct)
course.rank[,cols] <- lapply(course.rank[,cols], function(x) ifelse(course.rank$students_in_major < 5, -1, x))
head(course.rank[i,], 30)


# Need a check on status lookup for majors with same name but diff --------
### [HERE] checking with the service team on how to handle these duplicate names - either complete string or add (BS)/(BA) to some

# i <- status.lookup[duplicated(status.lookup$name),]


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

save(list = Cs(active.majors, pre.maj.courses, pre.maj.gpa, course.names), file = "intermediate data/intermediate cleaned files.RData")
