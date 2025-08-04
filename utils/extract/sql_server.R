get_sqlServerCon_by_server_auth <- function(server_name,db_name,user_name,passwrd) {
  
conn <- DBI::dbConnect(
    odbc::odbc(),
    .connection_string = "Driver={ODBC Driver 17 for SQL Server};",
     Server = server_name,
     Database = db_name, 
     UID = user_name,
     PWD = passwrd   
  )
 
  return(conn)
}


get_sqlServerCon_by_windows_auth <-  function(server_name,db_name) {
  con <- DBI::dbConnect(odbc::odbc(),
                 Driver   = "SQL Server",
                 Server   = server_name,
                 Database = db_name,
                 Trusted_Connection = "Yes")
  return(con)
}