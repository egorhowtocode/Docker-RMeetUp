# Tadviser

# Первый слой прасинга
library(rvest)
library(DBI)
library(RPostgres)


conn <- dbConnect(Postgres(),
    dbname   = "linktextdb",
    host     = "db", # localhost
    port     = 5432, # 5433
    user     = "user",
    password = "password"
)


url <- "https://www.tadviser.ru/index.php/Карта_информатизации_бизнеса#"

webpage <- read_html(url)

hrefs <- webpage %>%
    html_nodes(".red_bloks") %>%
    html_nodes("a") %>%
    html_attr("href")

techno_titles <- webpage %>%
    html_nodes(".red_bloks") %>%
    html_nodes("a") %>%
    html_text()


technologies <- data.frame(
    name = techno_titles,
    url = hrefs
)


insert_technology <- function(name, url) {
    dbGetQuery(
        conn, "
    INSERT INTO technologies (name, url)
    VALUES ($1, $2);",
        list(name, url)
    )
}

for (i in seq_len(nrow(technologies))) {
    insert_technology(technologies$name[i], technologies$url[i])
}


# Второй слой парсинга

insert_product <- function(conn,
                           technology_id,
                           product_name,
                           vendor_name,
                           contractors_num,
                           projects_num,
                           project_base_num,
                           product_url) {
    sql <- "
  INSERT INTO product_list
         (technology_id,
          product_name,
          vendor_name,
          contractors_num,
          projects_num,
          project_base_num,
          product_url)
  VALUES ($1, $2, $3, $4, $5, $6, $7);
  "

    dbExecute(conn, sql,
        params = list(
            technology_id,
            product_name,
            vendor_name,
            contractors_num,
            projects_num,
            project_base_num,
            product_url
        )
    )
}


add <- "?cache=no&ptype=system#ttop"


for (i in seq_along(hrefs[1:2])) {
    query <- dbGetQuery(
        conn,
        "SELECT id, status FROM technologies WHERE url = $1",
        list(hrefs[i])
    )

    tech_id <- query$id
    status <- query$status

    if (status == "success") {
        next
    }

    tryCatch(
        {
            webpage <- read_html(paste0("https://www.tadviser.ru", hrefs[i], add))

            tbl <- webpage %>%
                html_node(".sortable.cwiki_table") %>%
                html_table()

            tbl$product_url <- webpage %>%
                html_nodes(".sortable.cwiki_table td:first-child") %>%
                html_nodes("a") %>%
                html_attr("href")

            names(tbl)[names(tbl) == "Название продукта"] <- "product_name"
            names(tbl)[names(tbl) == "Вендор"] <- "vendor_name"
            names(tbl)[names(tbl) == "Подрядчиков"] <- "contractors_num"
            names(tbl)[names(tbl) == "Проектов"] <- "projects_num"
            names(tbl)[names(tbl) == "Проектов на базе"] <- "project_base_num"

            for (row in seq_len(nrow(tbl))) {
                insert_product(conn,
                    technology_id = tech_id,
                    product_name = tbl$product_name[row],
                    vendor_name = tbl$vendor_name[row],
                    contractors_num = tbl$contractors_num[row],
                    projects_num = tbl$projects_num[row],
                    project_base_num = tbl$project_base_num[row],
                    product_url = tbl$product_url[row]
                )
            }

            dbExecute(
                conn,
                "UPDATE technologies
          SET status = 'success',
              error_message = NULL
        WHERE id = $1", list(tech_id)
            )
        },
        error = function(e) {
            dbExecute(conn,
                "UPDATE technologies
          SET status = 'error',
              error_message = $2
        WHERE id = $1",
                params = list(tech_id, conditionMessage(e))
            )
        }
    )
}

# Проверяем получившуюся таблицу

product_list_data <- dbGetQuery(conn, "SELECT * FROM product_list")

# Третий слой парсинга


insert_attr <- function(conn, product_id, attr_name, attr_value) {
    dbExecute(conn, "
    INSERT INTO product_attrs (product_id, attr_name, attr_value)
    VALUES ($1, $2, $3)
    ON CONFLICT DO NOTHING;",
        params = list(product_id, attr_name, attr_value)
    )
}

prod_count <- dbGetQuery(conn, "SELECT COUNT(*) FROM product_list")$count


for (i in seq_len(5)) { # Надо использовать seq_len(prod_count), но в целях экономии времени вставим 2

    prod_row <- dbGetQuery(conn, "
      SELECT id, product_url, status
        FROM product_list
       WHERE id = $1", list(i))


    if (nrow(prod_row) == 0) next

    if (prod_row$status == "success") next

    prod_id <- prod_row$id
    link <- prod_row$product_url

    tryCatch(
        {
            page <- read_html(paste0("https://www.tadviser.ru", link))
            table <- html_node(page, "table.atts_table") %>% html_table()


            if (is.null(table) || ncol(table) < 2) {
                stop("No <table class='atts_table'> found")
            }


            attrs <- data.frame(
                attr_name = table[[1]],
                attr_value = table[[2]],
                stringsAsFactors = FALSE
            )

            for (r in seq_len(nrow(attrs))) {
                insert_attr(
                    conn, prod_id,
                    attrs$attr_name[r],
                    attrs$attr_value[r]
                )
            }

            dbExecute(conn, "
      UPDATE product_list
         SET status = 'success',
             error_message = NULL
       WHERE id = $1", list(prod_id))
        },
        error = function(e) {
            dbExecute(conn, "
      UPDATE product_list
         SET status = 'error',
             error_message = $2
       WHERE id = $1",
                params = list(prod_id, conditionMessage(e))
            )
        }
    )
}


product_attrs_data <- dbGetQuery(conn, "SELECT * FROM product_attrs")
