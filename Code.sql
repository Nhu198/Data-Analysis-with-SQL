use dua_data;

# Question 1: Những SP nào chúng ta nên đặt hàng nhiều hơn hoặc ít hơn? 

# DATA EXPLORATION

select count(distinct(productCode))
from products;
# => Có 110 SP mà Cty đang bán

select count(distinct(productCode))
from orderdetails;
# => Có 109 loại SP đã bán được

select *
from products
where 
	productCode not in (select distinct(productCode)
						from orderdetails);
# S18_3233 - 1985 Toyota Supra: SP chưa bán được, tồn kho còn 7733 sp => Không nhập về thêm

select productLine, count(productLine) as sl_sp_perline
from products
group by productLine order by sl_sp_perline desc;
# Có 7 dòng SP Classic Cars (38sp), Vintage Cars (24sp), Motorcycles (13), Planes (12sp), Trucks and Buses (11), Ships (9), Trains (3)
# GIẢ THIẾT
# Những SP có số lượng bán ra < số lượng tồn kho => ko nhập thêm
# Những SP có số lượng bán ra > số lượng tồn kho => nhập thêm lượng chênh lệch giữa số lượng tồn kho và b
with saled_quantity_product as (
	select productCode, sum(quantityOrdered) as quantity_saled
	from orderdetails
	group by productCode order by quantity_saled desc)
select p.productLine, 
		s.productCode, 
        s.quantity_saled, 
        p.quantityInStock,
        (s.quantity_saled - p.quantityInStock) as order_quantity_more
from products p
inner join saled_quantity_product s
	on p.productCode = s.productCode
where s.quantity_saled > p.quantityInStock
order by productLine asc;

with saled_quantity_product as (
	select productCode, sum(quantityOrdered) as quantity_saled
	from orderdetails
	group by productCode order by quantity_saled desc),
CTE2 as (
	select p.productLine, 
			s.productCode, 
			s.quantity_saled, 
			p.quantityInStock,
			(s.quantity_saled - p.quantityInStock) as order_quantity_more
	from products p
	inner join saled_quantity_product s
		on p.productCode = s.productCode
	where s.quantity_saled > p.quantityInStock
	order by productLine asc)
select count(*)
from CTE2;

# Câu 2: chúng ta nên điều chỉnh các chiến lược tiếp thị và truyền thông ntn cho phù hợp với hành vi của KH? 
# Điều này liên quan đến việc phân loại KH, tìm KH VIP (người rất quan trọng) và những người ít tham gia

# GIẢ THIẾT:
# Dựa trên revenue contribution của mỗi KH để xác định đâu là KH lớn (VIP), KH trung (thân thiết), KH nhỏ 
# Phân loại dựa trên các đơn hàng có status là: Shipped

# B1: Xác định sự phân bổ về revenue contribution của mỗi KH => từ đó xác định các mốc đóng góp doanh thu cho từng segment. 
# Dự kiến: tính quantile 1 & 3 => Nếu revenue contribution > Q3 => VIP
#								  Nếu revenue contribution > Q3 & < q1 => Thân thiết
#								  Nếu revenue contribution < Q1 => KH nhỏ

# Tính Q1 & Q3
with CTE1 as (
	select orderNumber, (quantityOrdered*priceEach) as revenue
	from orderdetails),
CTE2 as (
	select orderNumber, sum(revenue) as revenue_per_order
	from CTE1
	group by orderNumber),
CTE3 as (
	select CTE2.orderNumber, orders.customerNumber, CTE2.revenue_per_order, orders.status
	from CTE2 
	inner join orders 
		on CTE2.orderNumber = orders.orderNumber),
CTE4 as (
	select customerNumber, sum(revenue_per_order) as revenue_per_cust
	from CTE3
	where status = "Shipped"
	group by customerNumber
	order by revenue_per_cust desc)
select 
	   SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.25 * COUNT(*) + 1)), ',', -1) AS Q1,
       SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.75 * COUNT(*) + 1)), ',', -1) AS Q3
from CTE4;

# Check xem trong bảng CTE2 có bị duplicate cả customerNumber & orderNumber ko?
select customerNumber, orderNumber, count(*)
from orders
group by customerNumber, orderNumber
having count(*) > 1;
# => Không bị duplicate => tiếp tục làm

# Classify customer into segments:
with CTE1 as (
	select orderNumber, (quantityOrdered*priceEach) as revenue
	from orderdetails),
CTE2 as (
	select orderNumber, sum(revenue) as revenue_per_order
	from CTE1
	group by orderNumber),
CTE3 as (
	select CTE2.orderNumber, orders.customerNumber, CTE2.revenue_per_order, orders.status
	from CTE2 
	inner join orders 
		on CTE2.orderNumber = orders.orderNumber),
CTE4 as (
	select customerNumber, sum(revenue_per_order) as revenue_per_cust
	from CTE3
	where status = "Shipped"
	group by customerNumber
	order by revenue_per_cust desc)
select CTE4.*, case
					when revenue_per_cust > (select 
											SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.75 * COUNT(*) + 1)), ',', -1) AS Q3
                                            from CTE4) then "VIP"
					when revenue_per_cust < (select
											SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.25 * COUNT(*) + 1)), ',', -1) AS Q1
                                            from CTE4) then "Nhỏ"
					else "Thân Thiết"
                    end as Cust_Segment
from CTE4;


with CTE1 as (
	select orderNumber, (quantityOrdered*priceEach) as revenue
	from orderdetails),
CTE2 as (
	select orderNumber, sum(revenue) as revenue_per_order
	from CTE1
	group by orderNumber),
CTE3 as (
	select CTE2.orderNumber, orders.customerNumber, CTE2.revenue_per_order, orders.status
	from CTE2 
	inner join orders 
		on CTE2.orderNumber = orders.orderNumber),
CTE4 as (
	select customerNumber, sum(revenue_per_order) as revenue_per_cust
	from CTE3
	where status = "Shipped"
	group by customerNumber
	order by revenue_per_cust desc),
CTE5 as (select CTE4.*, case
					when revenue_per_cust > (select 
											SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.75 * COUNT(*) + 1)), ',', -1) AS Q3
                                            from CTE4) then "VIP"
					when revenue_per_cust < (select
											SUBSTRING_INDEX(SUBSTRING_INDEX(GROUP_CONCAT(CTE4.revenue_per_cust ORDER BY CTE4.revenue_per_cust), ',', FLOOR(0.25 * COUNT(*) + 1)), ',', -1) AS Q1
                                            from CTE4) then "Nhỏ"
					else "Thân Thiết"
                    end as Cust_Segment
from CTE4)
select Cust_Segment, count(Cust_Segment)
from CTE5 
group by Cust_Segment;		

# Insights: 
#	Đối với khách hàng VIP -> tăng chiết khấu khi mua hàng theo doanh thu đóng góp để khuyến khích tiếp tục chi tiêu
#			VD: khách hàng VIP có mức chi tiêu trên 150.000 usd chiết khấu 2%
#				khách hàng VIP có mức chi tiêu trên 200.000 usd chiết khấu 5%
#	            khách hàng VIP có mức chi tiêu trên 250.000 usd chiết khấu 8%
#	Đối với khách hàng thân thiết -> tiếp tục đưa những chính sách khuyến mãi, tặng kèm quà khi mua hàng
#			VD: tặng kèm camera hành trình, nội thất xe, ...
#	Đối với khách hàng nhỏ -> đẩy mạnh truyển thông bằng phương pháp quảng cáo (FB, mai,SMS,...) 
#										   -> đưa ra các ưu đãi theo mùa, chính sách trả góp,...
#										   -> quà tặng voucher
#   Chính sách chung cho tất cả segment: reference programe - giới thiệu khách hàng mới
							