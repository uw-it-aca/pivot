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

# I'm not fixing typos (career palnning sounds fun)

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
course.rank %>% group_by(mkey) %>% filter(max(pop) < 10)  # tacoma individualized study, but it only has 4 transcripts and 1 student anyway

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
###
## need to resolve this
###

