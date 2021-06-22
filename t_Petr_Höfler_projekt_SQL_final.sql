/*
 * První WITH generuje casovì promenné - první èást CASE WHEN generuje "0" pro pracovní dny a "1" pro víkend.
 * Druhá cást CASE WHEN na základe definice jednotlivých mesícu generuje rocní období -> 3-5 jaro, 6-8 léto, 9-11 podzim a zbytek zima.
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
 * Druhé WITH generuje podíly jednotlivých náboženství v konkrétních zemích. Každý rádek bere v potaz konkrétní náboženství.
 * Populace pro konkrétní náboženství se delí celkovou populací zeme z tabulky economies. Tabulky jsou následne spojené pomocí "join".
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
  * Další WITH generuje ocekávanou dobu dožití jedntlivých zemí pro rok 2015.
  */
  expectancy_2015 AS (
	SELECT
	country,
	life_expectancy
	FROM life_expectancy
	WHERE `year` = '2015'
),
/*
 * Další WITH generuje ocekávanou dobu dožití jedntlivých zemí pro rok 1965.
 */
	expectancy_1965 AS (
	SELECT
	country,
	life_expectancy
	FROM life_expectancy
	WHERE `year` = '1965'
),
/*
 * Následné WITH generuje prùmernou denní teplotu v jednotlivých mestech. Teplota se generuje od 6:00 do 21:00 hod.
 * Zaokrouhleno na 2 des. místa, teplota pøevedena na datový typ FLOAT. Následne je ve finální cásti syntaxe napojeno pres capital_city s tabulkou countries.
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
 * Toto WITH generuje pocet hodin v daném dni, kdyby byly srážky nenulové.
 * Prvne je spocítaný cas pomocí COUNT a vynásobeno tremi, kvùli tríhodinovým intervalùm v tabulce weather.
 * Následne zaokrouhleno na 2 des. míta, údaj "mm" vymazán a hodnota pøevedena na FLOAT s podmínkou vìtší než nula.
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
 * Poslední napojení pres WITH generuje maximální sílu vetru v nárazech behem dne.
 * Využito funkce MAX, kdy síla vìtru (gust) prevedeno na datový typ FLOAT, zaokrouhleno na 2 des. místa.
 * Casove omezeno opet mezi 6:00 a 21:00 hod.
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
 * Následuje vygenerování jednotlivých požadovaných sloupcù, které jsou soucástí jedné tabulky.
 * Panelová data "date" a "country", po kterých následují požadované a serazené jednotlivé sloupce. 
 * Nekteré z nich(napø. "gini", "mortality_under5" atd.) bráno z již existujících tabulek a pouze pripojeno - nebylo treba pocítat.
 * Jako základní tabulka brána "countries", na které jsou následne pomocí "join" napojeny ostatní pomocné tabulky.
 * Omezující podmínky WHERE doplneny na posledním rádku skriptu.
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