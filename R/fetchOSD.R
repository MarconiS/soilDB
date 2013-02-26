## TODO: update SoilWeb's snapshot of the SC database and check on subgroup_mod column

# fetch basic OSD data from the SoilWeb snapshot of the SC database
fetchOSD <- function(soils) {
	
	# base URLs
	u.osd_site <- 'http://casoilresource.lawr.ucdavis.edu/soil_web/reflector_api/soils.php?what=osd_site_query&q_string='
	u.osd_hz <- 'http://casoilresource.lawr.ucdavis.edu/soil_web/reflector_api/soils.php?what=osd_query&q_string='
	
	# compile URL + requested soil series
	u.site <- paste(u.osd_site, paste(soils, collapse=','), sep='')
	u.hz <- paste(u.osd_hz, paste(soils, collapse=','), sep='')
	
	# encode special characters into URLS
	u.site <- URLencode(u.site)
	u.hz <- URLencode(u.hz)
	
	# request data
	s <- read.csv(url(u.site), stringsAsFactors=FALSE)
	h <- read.csv(url(u.hz), stringsAsFactors=FALSE)
	
	# reformatting and color conversion
	h$soil_color <- with(h, munsell2rgb(matrix_wet_color_hue, matrix_wet_color_value, matrix_wet_color_chroma))
	h <- with(h, data.frame(id=series, top, bottom, hzname, soil_color, 
													hue=matrix_wet_color_hue, value=matrix_wet_color_value, 
													chroma=matrix_wet_color_chroma, stringsAsFactors=FALSE))
	
	# upgrade to SoilProfileCollection
	depths(h) <- id ~ top + bottom
	
	# merge-in site data
	s$id <- s$seriesname
	s$seriesname <- NULL
	site(h) <- s
	
	# done
	return(h)
}