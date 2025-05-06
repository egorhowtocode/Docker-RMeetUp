CREATE TABLE IF NOT EXISTS technologies (
  id   SERIAL PRIMARY KEY,
  name TEXT  UNIQUE NOT NULL,
  url  TEXT  NOT NULL,
  status TEXT DEFAULT 'pending',
  error_message TEXT DEFAULT NULL

);

CREATE TABLE IF NOT EXISTS product_list (
  id            SERIAL PRIMARY KEY,
  technology_id INTEGER NOT NULL REFERENCES technologies(id) ON DELETE CASCADE,
  product_name  TEXT    NOT NULL,
  vendor_name   TEXT    NOT NULL,
  contractors_num INTEGER NOT NULL,
  projects_num   INTEGER NOT NULL,
  project_base_num INTEGER NOT NULL,
  product_url   TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  error_message TEXT DEFAULT NULL

);

CREATE TABLE IF NOT EXISTS product_attrs ( 
  id         SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES product_list(id) ON DELETE CASCADE,
  attr_name  TEXT    NOT NULL,
  attr_value TEXT    NOT NULL

);