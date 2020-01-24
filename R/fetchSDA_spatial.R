#' @title Horizon Color Indices
#' @description This is a high-level fetch method that facilitates making spatial queries to Soil Data Access (SDA) based on `mukey` or `nationalmusym`. A typical SDA spatial query is made returning geometry and key identifying information about the mapunit. Additional columns from the mapunit table can be included using `add.fields` argument. 
#' 
#' This function automatically "chunks" the input vector (using `soilDB::makeChunks`) of mapunit identifiers to minimize the likelihood of exceeding the SDA data request size. The number of chunks varies with the `chunk.size` setting and the length of your input vector. If you are working with many mapunits and/or large extents, you may need to decrease this number in order to have more chunks.
#' @param x A vector of MUKEYs or national mapunit symbols.
#' @param by.col Column name containing mapunit identifier ("mukey" or "nmusym"); default: "mukey"
#' @param add.fields Column names from `SDA_Get_MupolygonWktWgs84_from_Mukey(mapunit.mukey)` result `mapunit` table to add to result. Must specify table name prefix as either `G` or `mapunit`.
#' @param chunk.size How many queries should spatial request be divided into? Necessary for large extents. Default: 10
#' @return A SpatialPolygonsDataFrame corresponding to SDA spatial data for all MUKEYs / nmusyms requested. Default result contains MupolygonWktWgs84-derived geometry with attribute table containing `gid`, `mukey` and `nationalmusym`, additional fields in result are specified with `add.fields`.
#' @author Andrew G. Brown.
#' @examples 
#' \donttest{
#' # get spatial data for a single mukey
#' single.mukey <- fetchSDA_spatial(x = "2924882")
#' 
#' # demonstrate fetching full extent (multi-mukey) of national musym
#' full.extent.nmusym <- fetchSDA_spatial(x = "2x8l5", by = "nmusym")
#' 
#' # compare extent of nmusym to single mukey within it
#' if(requireNamespace('sp')) {
#'  sp::plot(full.extent.nmusym, col = "RED",border=0)
#'  sp::plot(single.mukey, add = TRUE, col = "BLUE", border=0)
#' }
#' 
#' # demo adding a field (`muname`) to attribute table of result
#' head(fetchSDA_spatial(x = "2x8l5", by="nmusym", add.fields="muname"))
#' }
#' @rdname fetchSDA_spatial
#' @export fetchSDA_spatial
fetchSDA_spatial <- function(x, by.col = "mukey", 
                             add.fields = NULL, chunk.size = 10) {
  # remove any redundancy in input off the top -- this is important
  # in case x is not ordered and contains duplicates which will possibly
  # be in different chunks
  x <- unique(x)
  
  # default interface is mukey
  if(by.col == "mukey") {
    mukey.list <- x
    
  # a convenience interface is by nmusym -- may have several mukey per nmusym
  } else if(by.col == "nmusym" | by.col == "nationalmusym") {
    # do additional query to determine mapping of nmusym:mukey
    q.mukey <- paste0("SELECT nationalmusym, mukey FROM mapunit WHERE nationalmusym IN ",format_SQL_in_statement(x),";")
    suppressMessages(res <- SDA_query(q.mukey))
    mukey.list <- unique(res$mukey)
    
  # currently only mukey and nmusym are supported
  } else {
    stop(paste0("unknown mapunit identifier (",by.col,")"), call.=FALSE)
  }
  
  mukey.chunk <- soilDB::makeChunks(mukey.list, chunk.size)
  s <- NULL
    
  for(i in 1:length(mukey.chunk)) {
    idx <- which(mukey.chunk == mukey.chunk[i])
      
    q <- paste0("SELECT G.MupolygonWktWgs84 as geom, mapunit.mukey, mapunit.nationalmusym FROM mapunit CROSS APPLY SDA_Get_MupolygonWktWgs84_from_Mukey(mapunit.mukey) as G WHERE mukey IN ", 
                format_SQL_in_statement(mukey.list[idx]))
    
    # add any additional fields from G or mapunit
    if(!is.null(add.fields)) {
      q <- gsub(q, pattern = "FROM mapunit", replacement=paste0(", ", paste0(add.fields, collapse=", "), " FROM mapunit"))
    }
    
    sp.res.sub <- suppressMessages(soilDB::SDA_query(q))
    if(!is.null(sp.res.sub)) {
      s.sub <- soilDB::processSDA_WKT(sp.res.sub)
      if(is.null(s)) {
        s <- s.sub
      } else {
        s <- rbind(s, s.sub)
      }
    } else {
      message("no spatial data found for: ", 
              paste0(mukey.list[idx], collapse=""),  call.=FALSE)
    }
      
  }
  return(s)
}
