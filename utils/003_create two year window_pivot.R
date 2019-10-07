rm(list = ls())
gc()
# setup -------------------------------------------------------------------

library(tidyverse)

setwd(paste0(rstudioapi::getActiveProject(), "/.."))

# custom function to created quoted character vectors from unquoted text
Cs <- function(...) {as.character(sys.call())[-1]}

load("intermediate data/intermediate cleaned files.RData")
data.map <- read_csv("transformed data/data_map.csv")
# Gen most recent two years of data for switch ----------------------------

# use max available yrq from transcripts rather than current
(yrq.cut <- max(pre.maj.courses$tran.yrq) - 20)

# create prefix for 2 year window
max.yrq <- max(pre.maj.courses$tran.yrq)
# make file name prefix from max.yrq
(q <- max.yrq %% 10)
(y <- (max.yrq %/% 10) - 2000)
(q <- c("wi", "sp", "su", "au")[q])
(prefix <- paste0(q, y, "_8qtrs"))
rm(q, y)

pre.gpa2 <- pre.maj.gpa %>% ungroup() %>% filter(yrq.decl >= yrq.cut)

med.tot <- pre.gpa2 %>% group_by(credential_code, program_school_or_college) %>%
  summarize(count = n(),
            campus = max(campus),
            q1 = quantile(cgpa, .25),
            median = median(cgpa),
            q3 = quantile(cgpa, .75),
            iqr_min = q1 - IQR(cgpa),
            iqr_max = if_else(q3 + IQR(cgpa) > 4, 4, q3 + IQR(cgpa))) %>%
  ungroup()

# diagnostics
nrow(active.majors) - nrow(med.tot)
table(med.tot$count < 5)
(majors.wo.2yrs <- active.majors$credential_code[!(active.majors$credential_code %in% med.tot$credential_code)])


# transcripts for those declarations --------------------------------------
i <- pre.gpa2 %>% select(sys.key, yrq, credential_code)
course.rank <- inner_join(pre.maj.courses, i) %>%
  filter(ckey %in% course.names$ckey) %>%
  mutate(campus = as.numeric(campus)) %>%
  group_by(sys.key, credential_code, ckey, campus) %>%
  summarize(grade = max(grade)) %>%                     # limit to highest grade in major+course per student
  ungroup() %>%
  group_by(campus, credential_code, ckey) %>%
  summarize(n.course = n(), mgrade = median(grade)) %>%
  arrange(desc(n.course), .by_group = T) %>%
  mutate(pop = row_number()) %>%
  filter(pop <= 10) %>%
  ungroup()

nrow(course.rank) / length(unique(course.rank$credential_code))
course.rank %>% group_by(credential_code) %>% filter(max(pop) < 10)

# add numeric keys
c <- course.names %>% ungroup() %>% select(ckey, ckey.num)
course.rank <- course.rank %>% left_join(c, by = "ckey")
m <- active.majors %>% select(credential_code, mkey.num)
course.rank <- course.rank %>% left_join(m, by = "credential_code")
m <- med.tot %>% select(credential_code, count)
course.rank <- course.rank %>% left_join(m, by = "credential_code")
rm(c, m)

table(course.rank$n.course > course.rank$count)
course.rank %>% filter(n.course > count)
course.rank$n.course <- ifelse(course.rank$n.course > course.rank$count, course.rank$count, course.rank$n.course)
table(course.rank$n.course > course.rank$count)
table(course.rank$n.course == course.rank$count)


# fix names, write files --------------------------------------------------

student.data.all.majors <- med.tot %>% select(major_path = credential_code, college = program_school_or_college, count, iqr_min, q1, median, q3, iqr_max)
# edit rows with count < 5
cols <- Cs(count, iqr_min, q1, median, q3, iqr_max)
student.data.all.majors[,cols] <- lapply(student.data.all.majors[,cols], function(x) ifelse(med.tot$count < 5, -1, x))

# add majors that are active but have no students
active.no.stu <- active.majors %>%
  filter(!(credential_code %in% med.tot$credential_code)) %>%
  select(major_path = credential_code, college = program_school_or_college) %>%
  mutate(count = -1, iqr_min = -1, q1 = -1, median = -1, q3 = -1, iqr_max = -1)
student.data.all.majors <- bind_rows(student.data.all.majors, active.no.stu)

course.rank <- course.rank %>% select(major_path = credential_code, course_num = ckey, student_count = n.course,
                                      students_in_major = count, course_gpa_50pct = mgrade,
                                      course_popularity_rank = pop, campus)
i <- course.rank$students_in_major < 5
cols <- Cs(student_count, students_in_major, course_gpa_50pct)
course.rank[,cols] <- lapply(course.rank[,cols], function(x) ifelse(course.rank$students_in_major < 5, -1, x))
head(course.rank[i,], 30)
sum(i == T)


# verify names ------------------------------------------------------------
names(student.data.all.majors)
names(course.rank)


# append any additional courses to the data map ---------------------------

i <- setdiff(course.rank$course_num, data.map$key[data.map$is_course == 1])
# to.add <- course.names[course.names$ckey %in% i,]
to.add <- course.names %>%
  ungroup() %>%
  filter(ckey %in% i) %>%
  transmute(is_course = 1,
         is_major = 0,
         is_campus = 0,
         name = course.lname,
         id = ckey.num,
         key = ckey)

data.map <- bind_rows(data.map, to.add)

table(duplicated(data.map$key))
table(duplicated(data.map$id))
i <- data.map[data.map$id %in% data.map$id[duplicated(data.map$id)],]
i[order(i$id),]


# add any missing majors from data map to majors+courses ------------------
# majors_courses <=> course.rank
#' Compare two text lists and return a data.frame padded with n -1's
fill.missing.majors <- function(complete.list = data.map$key[data.map$is_major == 1],
                                inc.list = course.rank$major_path,
                                df.names = names(course.rank)){
  diff <- complete.list[!complete.list %in% inc.list]
  negmat <- matrix(-1, nrow = length(diff), ncol = length(df.names)-1)
  res <- data.frame(cbind(diff, negmat))
  names(res) <- df.names
  return(res)
}
# [TODO] fix this type conversion problem
x <- fill.missing.majors()
str(x)
x[,3:ncol(x)] <- lapply(x[,3:ncol(x)], as.numeric)

# get the correct campus for missing majors

x$campus <- active.majors$campus_num[active.majors$credential_code %in% x$major_path]

course.rank <- bind_rows(course.rank, x)
rm(x)

# output ------------------------------------------------------------------
# write.csv(student.data.all.majors, file = "transformed data/two year window/wi16_8qtrs_student_data_all_majors.csv", row.names = F)
# write.csv(course.rank, file = "transformed data/two year window/wi16_8qtrs_majors_and_courses.csv", row.names = F)
outdir <- paste0(getwd(), "/transformed data/")
write.csv(data.map, paste0(outdir, "data_map.csv"), row.names = F)
write.csv(student.data.all.majors, paste0(outdir, prefix, "_student_data_all_majors.csv"), row.names = F)
write.csv(course.rank, paste0(outdir, prefix, "_majors_and_courses.csv"), row.names = F)
