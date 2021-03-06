
## tabulte the number of records within each geomorphic table
## there could be some cases where there are no records, resulting in FALSE
# x: object returned by fetchOSD
.tabulateGeomorphRecords <- function(x) {
  
  vars <- c('series', 'n')
  
  ## TODO: [] style indexing will break when a table is empty (FALSE)
  ## temporary short-circuit
  ## consider returning empty tables in fetchOSD()
  if(
    any(
      isFALSE(x$hillpos) | 
      isFALSE(x$geomcomp) | 
      isFALSE(x$terrace) |
      isFALSE(x$flats)
      )
  ) {
    return(NULL)
  }
  
  m1 <- merge(x$hillpos[, vars], x$geomcomp[, vars], by = 'series', all.x = TRUE, all.y = TRUE, sort = FALSE)
  names(m1)[2:3] <- c('hillpos.records', 'geomcomp.records')
  
  m2 <- merge(m1, x$terrace[, vars], by = 'series', all.x = TRUE, all.y = TRUE, sort = FALSE)
  names(m2)[4] <- 'terrace.records'
  
  m3 <- merge(m2, x$flats[, vars], by = 'series', all.x = TRUE, all.y = TRUE, sort = FALSE)
  names(m3)[5] <- 'flats.records'
  
  m4 <- lapply(m3, function(i) {
    ifelse(is.na(i), 0, i)
  })
  
  m5 <- as.data.frame(m4, stringsAsFactors = FALSE)
  
  return(m5)
}



# 2018-10-11: updated to new API, URL subject to change
# fetch basic OSD, SC, and SoilWeb summaries from new API
fetchOSD <- function(soils, colorState='moist', extended=FALSE) {
	
  # sanity check
  if( !requireNamespace('jsonlite', quietly=TRUE))
    stop('please install the `jsonlite` package', call.=FALSE)
  
  
  # compose query
  # note: this is the load-balancer
  if(extended) {
    url <- 'https://casoilresource.lawr.ucdavis.edu/api/soil-series.php?q=all&s='
  } else {
    url <- 'https://casoilresource.lawr.ucdavis.edu/api/soil-series.php?q=site_hz&s='
  }
  
  # format series list and append to url
  final.url <- paste(url, URLencode(paste(soils, collapse=',')), sep='')
  
  ## TODO: implement HTTP POST + JSON for safer encapsulation
  # using HTTP GET is convenient but comes with limits on the number of chars in the URL
  # limiting to 2048 will likely save some trouble
  if(nchar(final.url) > 2048) {
    stop('URL too long, consider splitting input vector of soil series with `makeChunks()` and iterating over chunks', call. = FALSE)
  }
  
  # attempt query to API, result is JSON
  res <- try(jsonlite::fromJSON(final.url))
  
  ## TODO: further testing / message detail required
  # trap errors
  if(class(res) == 'try-error'){
    message('error')
    return(NULL)
  }
  
  # extract site+hz data
  # these will be FALSE if query returns NULL
  s <- res$site
  h <- res$hz
  
	# report missing data
  # no data condition: s == FALSE | h == FALSE
  # otherwise both will be a data.frame
	if( (is.logical(s) & length(s) == 1) | (is.logical(h) & length(h) == 1)) {
		message('query returned no data')
	  return(NULL)
	}
	
	# reformatting and color conversion
	if(colorState == 'moist') {
	  h$soil_color <- with(h, munsell2rgb(matrix_wet_color_hue, matrix_wet_color_value, matrix_wet_color_chroma))
	  h <- with(h, data.frame(id=series, top, bottom, hzname, soil_color, 
	                          hue=matrix_wet_color_hue, value=matrix_wet_color_value, 
	                          chroma=matrix_wet_color_chroma, dry_hue=matrix_dry_color_hue,
	                          dry_value=matrix_dry_color_value, dry_chroma=matrix_dry_color_chroma,
	                          texture_class=texture_class, cf_class=cf_class, pH=ph, pH_class=ph_class,
	                          distinctness=distinctness, topography=topography,
	                          narrative=narrative,
	                          stringsAsFactors=FALSE)) 
	}
	
	if(colorState == 'dry') {
	  h$soil_color <- with(h, munsell2rgb(matrix_dry_color_hue, matrix_dry_color_value, matrix_dry_color_chroma))
	  h <- with(h, data.frame(id=series, top, bottom, hzname, soil_color, 
	                          hue=matrix_dry_color_hue, value=matrix_dry_color_value, 
	                          chroma=matrix_dry_color_chroma, moist_hue=matrix_wet_color_hue,
	                          moist_value=matrix_wet_color_value, moist_chroma=matrix_wet_color_chroma,
	                          texture_class=texture_class, cf_class=cf_class, pH=ph, pH_class=ph_class,
	                          distinctness=distinctness, topography=topography,
	                          narrative=narrative,
	                          stringsAsFactors=FALSE))
	}
	
	
	# upgrade to SoilProfileCollection
	depths(h) <- id ~ top + bottom
	
	# texture clases, in order
	textures <- SoilTextureLevels(which = 'names')
	
	pH_classes <- c('ultra acid', 'extremely acid', 'very strongly acid', 'strongly acid', 'moderately acid', 'slightly acid', 'neutral', 'slightly alkaline', 'mildly alkaline', 'moderately alkaline', 'strongly alkaline', 'very strongly alkaline')
	
	# convert some columns into factors
	h$texture_class <- factor(h$texture_class, levels=textures, ordered = TRUE)
	h$pH_class <- factor(h$pH_class, levels=pH_classes, ordered = TRUE)
	
	# safely LEFT JOIN to @site
	s$id <- s$seriesname
	s$seriesname <- NULL
	site(h) <- s
	
	## safely set metadata
	# TODO: check before clobbering / consider standard var name
	metadata(h)$origin <- 'OSD via Soilweb / fetchOSD'
	
	# set optional hz designation and texture slots
	hzdesgnname(h) <- "hzname"
	hztexclname(h) <- "texture_class"
	
	# mode: standard (SPC returned) or extended (list returned)
	if(extended) {
	  
	  
	  ## TODO: finish this and decide: report or filter
	  # https://github.com/ncss-tech/soilDB/issues/128
	  
	  # profile IDs for reference, done outside of loop for efficiency
	  pIDs <- profile_id(h)
	  # iterate over extended tables
	  # finding all cases where a series is missing from SPC
	  missing.series <- unique(
	    as.vector(
	      unlist(
	        lapply(res, function(i) {
	          if(inherits(i, 'data.frame')) {
	            setdiff(unique(i[['series']]), pIDs)
	          }
	        })
	      )
	    )
	  )
	  
	  
	  # generate a warning if there is a difference between profile IDs in SPC
	  if(length(missing.series) > 0) {
	    msg <- sprintf("%s missing from SPC, see ?fetchOSD for suggestions", paste(missing.series, collapse = ','))
	    warning(msg, call. = FALSE)
	  }
	  
	  
	  # if available, split climate summaries into annual / monthly and add helper columns
	  # FALSE if missing
	  if(inherits(res$climate, 'data.frame')) {
	    # split annual from monthly climate summaries
	    annual.data <- res$climate[grep('ppt|pet', res$climate$climate_var, invert = TRUE), ]
	    monthly.data <- res$climate[grep('ppt|pet', res$climate$climate_var), ]
	    
	    # add helper columns to monthly data
	    monthly.data$month <- factor(as.numeric(gsub('ppt|pet', '', monthly.data$climate_var)))
	    monthly.data$variable <- gsub('[0-9]', '', monthly.data$climate_var)
	    monthly.data$variable <- factor(monthly.data$variable, levels = c('pet', 'ppt'), labels=c('Potential ET (mm)', 'Precipitation (mm)'))
	  } else {
	    # likely outside of CONUS
	    annual.data <- FALSE
	    monthly.data <- FALSE
	  }
	  
	  ## must check for data, no data is returned as FALSE
	  
	  # fix column names in pmkind and pmorigin tables
	  if(inherits(res$pmkind, 'data.frame')) {
	    names(res$pmkind) <- c('series', 'pmkind', 'n', 'total', 'P')
	  }
	    
	  
	  if(inherits(res$pmorigin, 'data.frame')) {
	    names(res$pmorigin) <- c('series', 'pmorigin', 'n', 'total', 'P')
	  }
	    
	  # fix column names in competing series
	  if(inherits(res$competing, 'data.frame')) {
	    names(res$competing) <- c('series', 'competing', 'family')
	  }
	  
	  # compose into a list
	  data.list <- list(
	    SPC=h,
	    competing=res$competing,
	    geomcomp=res$geomcomp,
	    hillpos=res$hillpos,
	    mtnpos=res$mtnpos,
	    terrace=res$terrace,
	    flats=res$flats,
	    pmkind=res$pmkind,
	    pmorigin=res$pmorigin,
	    mlra=res$mlra,
	    climate.annual=annual.data,
	    climate.monthly=monthly.data,
	    soilweb.metadata=res$metadata
	  )
	  
	  return(data.list)
	  
	} else {
	  # extended = FALSE, return SPC
	  return(h) 
	}

	
}
