create external table if not exists store_sales (
      ss_sold_date_sk int
      , ss_sold_time_sk int
      , ss_item_sk int
      , ss_customer_sk int
      , ss_cdemo_sk int
      , ss_hdemo_sk int
      , ss_addr_sk int
      , ss_store_sk int
      , ss_promo_sk int
      , ss_ticket_number bigint
      , ss_quantity int
      , ss_wholesale_cost double
      , ss_list_price double
      , ss_sales_price double
      , ss_ext_discount_amt double
      , ss_ext_sales_price double
      , ss_ext_wholesale_cost double
      , ss_ext_list_price double
      , ss_ext_tax double
      , ss_coupon_amt double
      , ss_net_paid double
      , ss_net_paid_inc_tax double
      , ss_net_profit double
      )
      stored as parquet location 'hdfs:///data/tpcds/store_sales/'
      tblproperties ('parquet.compression'='SNAPPY');
select * from store_sales limit 10;
create external table if not exists item (
      i_item_sk int
      , i_item_id string
      , i_rec_start_date string
      , i_rec_end_date string
      , i_item_desc string
      , i_current_price double
      , i_wholesale_cost double
      , i_brand_id int
      , i_brand string
      , i_class_id int
      , i_class string
      , i_category_id int
      , i_category string
      , i_manufact_id int
      , i_manufact string
      , i_size string
      , i_formulation string
      , i_color string
      , i_units string
      , i_container string
      , i_manager_id int
      , i_product_name string
      )
      stored as parquet location 'hdfs:///data/tpcds/item'
      tblproperties ('parquet.compression'='SNAPPY');
select * from item limit 10;

create external table students (name VARCHAR(64), age INT) stored as orc location 'hdfs:///data/students';
insert into table students values ('fred flintstone', 32), ('barney rubble', 35);

