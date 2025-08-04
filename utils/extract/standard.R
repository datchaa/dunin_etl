show_tables <- function(conn){
  DBI::dbListTables(conn,schema="dbo")
}

get_table_in_lazy_method <- function(conn,table_name){
  dplyr::tbl(conn,table_name)
}

get_all  <- function(table_name,attribute){
  table_name |> dplyr::pull(attribute)

}