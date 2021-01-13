
# utility funs ------------------------------------------------------------

# helper function - create quoted vector, i.e. c(), from unquoted text
# not intended to smoothly handle punctuation but can be coerced a little, e.g. Cs(a, b, "?")
Cs <- function(...){as.character(sys.call())[-1]}

# build an end-label filter for CM tables. I.e. a lookup table to covert text label to numeric
text.qtr.to.numeric <- function(q){
  lookup <- c('Winter', 'Spring', 'Summer', 'Autumn')
  return(match(q, lookup))
}

# Convert a year quarter in text label format to numeric.
# Only meant to handle the format in CM (e.g. `credential_dateEndLabel`) right now.
# "Winter 2020" should return 20201
label.to.yrq <- function(text.yrq){
  y <- str_sub(text.yrq, start = -4)
  q <- str_sub(text.yrq, end = -6)
  q <- text.qtr.to.numeric(q)
  yrq <- paste0(y, q)
  return(as.numeric(yrq))
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

# function to strip whitespace, alternative to `mutate_if(is.character, ...)` that does not depend on dplyr/tidyverse
#
# input: dataframe
# return: dataframe w/o extra whitespace (common to sdb)
df.trimws <- function(df){
  i <- sapply(df, is.character)
  df[i] <- lapply(df[i], trimws)
  return(df)
}
