rm(list = ls())
gc()
# setup -------------------------------------------------------------------

library(tidyverse)

setwd(rstudioapi::getActiveProject())
setwd("..")

# custom function to created quoted character vectors from unquoted text
Cs <- function(...) {as.character(sys.call())[-1]}

load("intermediate data/intermediate cleaned files.RData")
data.map <- read_csv("transformed data/Data_Map.csv")
# Gen most recent two years of data for switch ----------------------------

# use max available yrq from transcripts rather than current
(yrq.cut <- max(pre.maj.courses$tran.yrq) - 20)

pre.gpa2 <- pre.maj.gpa %>% ungroup() %>% filter(yrq.decl >= yrq.cut)

med.tot <- pre.gpa2 %>% group_by(mkey, FinCollegeReportingName) %>%
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


# transcripts for those declarations --------------------------------------
i <- pre.gpa2 %>% select(sys.key, yrq, mkey)
course.rank <- inner_join(pre.maj.courses, i)
course.rank <- course.rank %>%
  filter(ckey %in% course.names$ckey) %>%
  group_by(mkey, ckey) %>%
  summarize(n.course = n(), mgrade = median(grade)) %>%
  arrange(desc(n.course), .by_group = T) %>%
  filter(row_number() <= 10) %>%
  mutate(pop = seq_along(n.course)) %>%
  ungroup()

nrow(course.rank) / length(unique(course.rank$mkey))
course.rank %>% group_by(mkey) %>% filter(max(pop) < 10)

# add numeric keys
c <- course.names %>% select(ckey, ckey.num)
course.rank <- course.rank %>% left_join(c, by = "ckey")
m <- active.majors %>% select(mkey, mkey.num, MajorCampus)
course.rank <- course.rank %>% left_join(m, by = "mkey")
m <- med.tot %>% select(mkey, count)
course.rank <- course.rank %>% left_join(m, by = "mkey")
rm(c, m)

table(course.rank$n.course > course.rank$count)
course.rank %>% filter(n.course > count)
course.rank$n.course <- ifelse(course.rank$n.course > course.rank$count, course.rank$count, course.rank$n.course)
table(course.rank$n.course > course.rank$count)
table(course.rank$n.course == course.rank$count)


# fix names, write files --------------------------------------------------

student.data.all.majors <- med.tot %>% select(major_path = mkey, college = FinCollegeReportingName, count, iqr_min, q1, median, q3, iqr_max)
# edit rows with count < 5
cols <- Cs(count, iqr_min, q1, median, q3, iqr_max)
student.data.all.majors[,cols] <- lapply(student.data.all.majors[,cols], function(x) ifelse(med.tot$count < 5, -1, x))

# add majors that are active but have no students
active.no.stu <- active.majors %>%
  filter(!(mkey %in% med.tot$mkey)) %>%
  select(major_path = mkey, college = FinCollegeReportingName) %>%
  mutate(count = -1, iqr_min = -1, q1 = -1, median = -1, q3 = -1, iqr_max = -1)
student.data.all.majors <- bind_rows(student.data.all.majors, active.no.stu)

course.rank <- course.rank %>% select(major_path = mkey, course_num = ckey, student_count = n.course,
                                      students_in_major = count, course_gpa_50pct = mgrade,
                                      course_popularity_rank = pop, campus = MajorCampus)
i <- course.rank$students_in_major < 5
cols <- Cs(student_count, students_in_major, course_gpa_50pct)
course.rank[,cols] <- lapply(course.rank[,cols], function(x) ifelse(course.rank$students_in_major < 5, -1, x))
head(course.rank[i,], 30)
sum(i == T)


# verify names ------------------------------------------------------------
names(student.data.all.majors)
names(course.rank)


# output ------------------------------------------------------------------
write.csv(student.data.all.majors, file = "transformed data/two year window/wi16_8qtrs_student_data_all_majors.csv", row.names = F)
write.csv(course.rank, file = "transformed data/two year window/wi16_8qtrs_majors_and_courses.csv", row.names = F)
