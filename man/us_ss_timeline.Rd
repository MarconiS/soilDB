\name{us_ss_timeline}
\alias{us_ss_timeline}
\docType{data}

\title{
Timeline of US Published Soil Surveys
}

\description{
This dataset contains the years of each US Soil Survey was published.
}

\usage{data("us_ss_timeline")}

\format{
  A data frame with 5209 observations on the following 5 variables.
  \describe{
    \item{\code{ssa}}{Soil Survey name, a character vector}
    \item{\code{year}}{year of publication, a numeric vector}
    \item{\code{pdf}}{does a pdf exists, a logical vector}
    \item{\code{state}}{State abbrevation, a character vector}
  }
}

\details{
This data was web scraped from the NRCS Soils Website. The scraping procedure and a example plot are included in the examples section below.
}

\source{
https://www.nrcs.usda.gov/wps/portal/nrcs/soilsurvey/soils/survey/state/
}

\examples{
\donttest{
if (requireNamespace("curl") &
    curl::has_internet() &
    require("XML") & 
    require("RCurl") &
    require("ggplot2") & 
    require("gridExtra")
) {
  
data(state)
st <- paste0(c(state.abb, "PR", "DC", "VI", "PB"))
us_ss_timeline <- {
  lapply(st, function(x) {
    cat("getting", x, "\n")
    url <- getURL(paste0(
      "https://www.nrcs.usda.gov/wps/portal/nrcs/surveylist/soils/survey/state/?stateId=", x)
    )
    df  <- readHTMLTable(url, which = 22, stringsAsFactors = FALSE)
    df$state <- x
    return(df)
  }) ->.;
  do.call("rbind", .) ->.;
  names(.) <- c("ssa", "year", "pdf", "wss", "state")
  .[!grepl(.$year, pattern="current"), ] ->.;
}
us_ss_timeline <- within(us_ss_timeline, {
  ssa  = sapply(ssa, function(x) strsplit(x, "\r")[[1]][1])
  year = as.numeric(substr(year, 3,6))
  pdf  = ifelse(pdf == "Yes", TRUE, FALSE)
  wss  = NULL
})

test <- as.data.frame(table(us_ss_timeline$year), stringsAsFactors = FALSE)

g1 <- ggplot(data = test, aes(x = Var1, y = Freq)) +
  geom_histogram(stat = "identity") + 
  xlab("Year") + 
  ylab("Count") +
  theme(aspect.ratio = 1) + 
  ggtitle("Number of Published \n US Soil Surveys by Year")
g2 <- ggplot(test, aes(x = Var1, y = cumsum(Freq))) +
  geom_histogram(stat = "identity") + 
  xlab("Year") + 
  ylab("Count") +
  theme(aspect.ratio = 1) +
  ggtitle("Cumulative Number of Published \n US Soil Surveys by Year")

grid.arrange(g1, g2, ncol = 2)

}}}
\keyword{datasets}
