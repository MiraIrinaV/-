--1) В каких городах больше одного аэропорта? Ответ: Ульяновск и Москва

select --вывожу инф.о наз.города и кол-ве аэропортов
	a.city,
	count(a.airport_code) "count_airports"
from --вся нужная инф.находится в таб.airports
	airports a 
group by --группирую по наз.городу
	a.city
having count(a.airport_code)>1 --вывожу только те города, в кот.кол-во аэропортов больше 1


--2) В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select --вывожу инф.о наз.аэропорта, модели самолёта и дальности полёта
	a.airport_name,
	a2.model,
	a2."range"  
from --не вся инф.находится в таб.airports, поэтому дополняю инф.из таб.flights и aircrafts
	airports a 
full outer join flights f on f.departure_airport = a.airport_code 
full outer join aircrafts a2 on a2.aircraft_code = f.aircraft_code
where a2."range" in ( --уточняю подзапросом, в кот.упорядочиваю все модели самолёта по дальности полёта по убыванию и ограничиваю список первым значенем, тем самым нахожу модель самолёта, с мах дальностью полёта
		select a3."range" 
		from aircrafts a3 
		order by a3."range" desc 
		limit 1
		)
group by a.airport_code, a2.aircraft_code --группирую по аэропорту и модели самолёта  


--3) Вывести 10 рейсов с максимальным временем задержки вылета

select --вывожу рейсы, время вылета по расписанию, факт.время вылета и вычисляемое значение задержки вылета
	f.flight_no,
	f.scheduled_departure,
	f.actual_departure,
	f.actual_departure - f.scheduled_departure departure_delay
from flights f -- вся нужная инф.находится в таб.flights
where f.actual_departure is not null --т к факт.время вылета может принимать null значения, оставляю not null значения факт.времени вылета
order by departure_delay desc --упорядочиваю задержку вылета по убыванию 
limit 10 --ограничиваю выводимый список 10 значениями, тем самым вывожу 10 рейсов с max временем задержки рейса


--4) Были ли брони, по которым не были получены посадочные талоны?

select --вывожу уник.значения брони, номер места из таб.boarding_passes (при этом предполагаю, что брони, по кот.не были получены посадочные будут иметь null значения номера места из таб.boarding_passes)
	distinct t.book_ref,
	bp.seat_no 
from tickets t --инф.о брони беру из таб.tickets и присоединяю к ней инф.о номере места из таб.boarding_passes
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.seat_no is null --вывожу значения, в кот.номер места принимает null значения 


--5) Найдите количество свободных мест для каждого рейса, 
--их % отношение к общему количеству мест в самолете. 
--Добавьте столбец с накопительным итогом - 
--суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
--Т.е. в этом столбце должна отражаться накопительная сумма - 
--сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня

with cte1 as ( --нахожу кол-во мест в самолёте для каждого рейса
	select 
		f.flight_id,
		count(s.seat_no) 
	from flights f 
	join aircrafts a on a.aircraft_code = f.aircraft_code  
	join seats s on s.aircraft_code = a.aircraft_code 
	group by f.flight_id
),
cte2 as ( --нахожу кол-во посадочных мест для каждого рейса
	select 
		f.flight_id,
		count (bp.seat_no)
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	group by f.flight_id 
)
select 
	f2.flight_id, --вывожу каждый рейс
	(case --вывожу кол-во свободных мест для каждого рейса, для этого отнимаю от кол-ва мест из первого подзапроса кол-во мест из второго подзапроса (учитываю, что в рейсе могли быть null значения кол-ва посадочных мест, например - рейс отменили)
		when (cte1.count - cte2.count) is null then cte1.count
		else (cte1.count - cte2.count)
	end) "Кол-во свободных мест",
	(case --вывожу % свободных мест в самолёте для каждого рейса (по аналогии с кол-ом свободных мест)
		when cte2.count is null then 100
		else round ((cte1.count - cte2.count) / cte1.count :: numeric * 100, 2) 
	end) "% свободных мест в самолёте",
	(case --вывожу кол-во вывезенных пассажиров для каждого рейса
		when cte2.count is null then 0
		else cte2.count
	end) count_passengers,
	f2.departure_airport, --вывожу аэропорт отправления
	date_trunc('day', f2.scheduled_departure) "День вылета",
	sum (cte2.count) over (partition by f2.departure_airport order by f2.scheduled_departure :: date) --нахожу накопительную сумму вывезенных пассажиров по каждому дню для каждого аэропорта
from flights f2 
join cte1 on f2.flight_id = cte1.flight_id
full outer join cte2 on f2.flight_id = cte2.flight_id
group by f2.flight_id, cte1.count, cte2.count


--6) Найдите процентное соотношение перелетов по типам самолетов от общего количества
	
select --вывожу модели самолётов и расчётное значение отношения кол-ва перелётов по каждой модели самолёта к общему кол-ву перелётов (для этого использ.подзапрос), далее умножаю на 100, округляю до 2 знаков после запятой
	a.model,
	round (count (f.flight_id) / (select count(f.flight_id) from flights f) :: numeric * 100, 2) "% соотн.перелётов"
from aircrafts a --инф.беру из табл.aircrafts и flights
join flights f on f.aircraft_code = a.aircraft_code
group by a.model --группирую по модели самолёта


--7) Были ли города, в которые можно добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with cte1 as ( --нахожу min стоимость билета в Эконом классе для каждого перелёта
	select 
		f.flight_id,
		f.arrival_airport,
		min(tf.amount) 
	from ticket_flights tf
	join flights f on f.flight_id = tf.flight_id
	where tf.fare_conditions = 'Economy'
	group by f.flight_id, f.arrival_airport  
),
cte2 as ( --нахожу min стоимость билета в Бизнесс классе для каждого перелёта
	select 
		f.flight_id,
		f.arrival_airport,
		min(tf.amount) 
	from ticket_flights tf
	join flights f on f.flight_id = tf.flight_id
	where tf.fare_conditions = 'Business'
	group by f.flight_id, f.arrival_airport 
)
select --вывожу список городов прибытия, в которые можно было попасть дешевле бизнесс классом, чем эконом, для этого сравниваю минимальные значения стоимости билетов из подзапросов
	a.city
from airports a 
join cte1 on cte1.arrival_airport = a.airport_code 
join cte2 on cte2.arrival_airport = a.airport_code 
where cte1.min > cte2.min
group by a.city


--8) Между какими городами нет прямых рейсов?

select --в первом запросе нахожу всевозможные пары городов, используя для этого декартово произведение
	a.city,
	a2.city 
from airports a, airports a2 
where a.city != a2.city 
except --вычитаю из первого запроса второй и нахожу пары городов без прямых рейсов
select --во втором запросе вывожу список городов вылета и прибытия
	a.city, --город вылета
	a2.city --город прибытия
from flights f 
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport







