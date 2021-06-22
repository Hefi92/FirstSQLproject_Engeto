/*
 * Prvn� WITH generuje �asov� prom�nn� - prvn� ��st CASE WHEN generuje "0" pro pracovn� dny a "1" pro v�kend.
 * Druh� ��st CASE WHEN na z�klad� definice jednotliv�ch m�s�c� generuje ro�n� obdob� -> 3-5 jaro, 6-8 l�to, 9-11 podzim a zbytek zima.
 */
WITH period_of_year AS(
	SELECT
	date,
	country,
	REPLACE(country,'Czechia','Czech Republic'),
	CASE	WHEN WEEKDAY(date) IN (0, 1, 2, 3, 4) THEN 0
	ELSE 1 END AS weekday_or_weekend,
	CASE	WHEN MONTH(date) BETWEEN 3 AND 5 THEN 0
			WHEN MONTH(date) BETWEEN 6 AND 8 THEN 1
			WHEN MONTH(date) BETWEEN 9 AND 11 THEN 2
	ELSE 3 END time_of_year
	FROM covid19_basic_differences
),
/*
 * Druh� WITH generuje pod�ly jednotliv�ch n�bo�enstv� v konkr�tn�ch zem�ch. Ka�d� ��dek bere v potaz konkr�tn� n�bo�enstv�.
 * Populace pro konkr�tn� n�bo�enstv� se d�l� celkovou populac� zem� z tabulky economies. Tabulky jsou n�sledn� spojen� pomoc� "join".
 */
religion AS(
 	SELECT
 	rel.country,
 	MAX(CASE religion WHEN 'Islam' THEN ROUND(rel.population / eco.population * 100,2) END) Islam_rel,
 	MAX(CASE religion WHEN 'Christianity' THEN ROUND(rel.population / eco.population * 100,2) END) Christianity_rel,
 	MAX(CASE religion WHEN 'Unaffiliated Religions' THEN ROUND(rel.population / eco.population * 100,2) END) Unaffiliated_rel,
 	MAX(CASE religion WHEN 'Hinduism' THEN ROUND(rel.population / eco.population * 100,2) END) Hinduism_rel,
 	MAX(CASE religion WHEN 'Buddhism' THEN ROUND(rel.population / eco.population * 100,2) END) Buddhism_rel,
 	MAX(CASE religion WHEN 'Folk Religions' THEN ROUND(rel.population / eco.population * 100,2) END) Folk_rel,
 	MAX(CASE religion WHEN 'Other Religions' THEN ROUND(rel.population / eco.population * 100,2) END) Other_rel,
 	MAX(CASE religion WHEN 'Judaism' THEN ROUND(rel.population / eco.population * 100,2) END) Judaism_rel
 	FROM religions rel
 	JOIN economies eco
 	ON eco.country = rel.country AND CAST(eco.year-1 AS INT) = CAST(rel.year AS INT)
 	GROUP BY rel.country
 ),
 /*
  * Dal�� WITH generuje o�ek�vanou dobu do�it� jedntliv�ch zem� pro rok 2015.
  */
  expectancy_2015 AS (
	SELECT
	country,
	life_expectancy
	FROM life_expectancy
	WHERE `year` = '2015'
),
/*
 * Dal�� WITH generuje o�ek�vanou dobu do�it� jedntliv�ch zem� pro rok 1965.
 */
	expectancy_1965 AS (
	SELECT
	country,
	life_expectancy
	FROM life_expectancy
	WHERE `year` = '1965'
),
/*
 * N�sledn� WITH generuje pr�m�rnou denn� teplotu v jednotliv�ch m�stech. Teplota se generuje od 6:00 do 21?00 hod.
 * Zaokrouhleno na 2 des. m�sta, teplota p�evedena na datov� typ FLOAT. N�sledn� je ve fin�ln� ��sti syntaxe napojeno p�es capital_city s tabulkou countries.
 */
	Daily_temperature AS (
	SELECT
	date,
	city,
	ROUND(CAST(AVG(temp) AS FLOAT), 2) Average_daily_temperature
	FROM weather w
	WHERE `time` BETWEEN '06:00' AND '21:00' AND city IS NOT NULL
	GROUP BY date, city
),
/*
 * Toto WITH generuje po�et hodin v dan�m dni, kdyby byly sr�ky nenulov�.
 * Prvn� je spo��tan� �as pomoc� COUNT a vyn�sobeno t�emi, kv�li t��hodinov�m interval�m v tabulce weather.
 * N�sledn� zaokrouhleno na 2 des. m�ta, �daj "mm" vymaz�n a hodnota p�evedena na FLOAT s podm�nkou v�t�� ne� nula.
 */
	Non_zero_humidity AS(
	SELECT
	date,
	city,
	COUNT(time) * 3 AS Hour_amount_of_humidity_more_than_zero,
	ROUND(CAST((REPLACE(rain,'mm','')) AS FLOAT), 2) AS Humidity_more_than_zero
	FROM weather
	WHERE ROUND(CAST((REPLACE(rain,'mm','')) AS FLOAT), 2) > 0
	GROUP BY date,city
	ORDER BY date DESC
),
/*
 * Posledn� napojen� p�es WITH generuje maxim�ln� s�lu v�tru v n�razech b�hem dne.
 * Vyu�ito funkce MAX, kdy s�la v�tru (gust) p�evedeno na datov� typ FLOAT, zaokrouhleno na 2 des. m�sta.
 * �asov� omezeno op�t mezi 6:00 a 21:00 hod.
 */
	Maximum_gust_per_day AS (
	SELECT
	date,
	city,
	ROUND(CAST(MAX(gust) AS FLOAT), 2) Maximum_gust_during_day
	FROM weather
	WHERE time BETWEEN '06:00' AND '21:00' AND city IS NOT NULL
	GROUP BY date, city
)	
/*
 * N�sleduje vygenerov�n� jednotliv�ch po�adovan�ch sloupc�, kter� jsou sou��st� jedn� tabulky.
 * Panelov� data "date" a "country", po kter�ch n�sleduj� po�adovan� a se�azen� jednotliv� sloupce. 
 * N�kter� z nich(nap�. "gini", "mortality_under5" atd.) br�no ji� z existuj�c�ch tabulek a pouze p�ipojeno - nebylo t�eba po��tat.
 * Jako z�kladn� tabulka br�na "countries", na kter� jsou n�sledn� pomoc� "join" napojeny ostatn� pomocn� tabulky.
 * Omezuj�c� podm�nky WHERE dopln�ny na posledn�m ��dku skriptu.
 */
	SELECT
	poy.date,
	poy.country,
	poy.weekday_or_weekend,
	poy.time_of_year,
	cou.population_density,
	ROUND(eco.GDP/eco.population * 100, 2) GDP_per_citizen,
	eco.gini,
	eco.mortaliy_under5,
	cou.median_age_2018,
	rel.*,
	ROUND(life_exp_2015.life_expectancy - life_exp_1965.life_expectancy, 2) Life_expectancy_diff_2015_1965,
	temp.Average_daily_temperature,
	non.Hour_amount_of_humidity_more_than_zero,
	gust.Maximum_gust_during_day
	FROM countries cou
	LEFT JOIN period_of_year poy
	ON poy.country = cou.country
	LEFT JOIN economies eco
	ON eco.country = cou.country
	LEFT JOIN religion rel
	ON cou.country = rel.country
	JOIN expectancy_2015 life_exp_2015
	ON cou.country = life_exp_2015.country
	JOIN expectancy_1965 life_exp_1965
	ON cou.country = life_exp_1965.country
	JOIN Daily_temperature temp
	ON cou.capital_city = temp.city
	JOIN Non_zero_humidity non
	ON cou.capital_city = non.city
	JOIN Maximum_gust_per_day gust
	ON cou.capital_city = gust.city
	WHERE eco.GDP IS NOT NULL AND eco.gini IS NOT NULL AND eco.population IS NOT NULL;