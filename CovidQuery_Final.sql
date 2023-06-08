/* Let's look at the Deaths file */
SELECT *
FROM portfolio.dbo.CovidDeaths
ORDER BY location, date
-- Order by columns 3 location, 4 date to match with Excel file


/* Select the columns I am interested in */
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM portfolio.dbo.CovidDeaths
ORDER BY 1, 2
-- ORDER BY the new columns 1 location, 2 date


/* Total Cases vs Total Deaths 
	Shows likelihood of death if contracted covid in my country (USA) */
SELECT location, date, total_cases, total_deaths, ((cast(total_deaths as int))/total_cases)*100 as DeathPercentage
FROM portfolio.dbo.CovidDeaths
WHERE location like '%states%'
ORDER BY 1, 2
-- Create DeathPercentage column that calculates % of covid deaths
-- total_deaths is nvarchar(255). Need to cast as int.
-- Filter USA location using the LIKE operator.


/* Total Cases vs Population 
	Shows what percentage of the population contracted covid */
SELECT location, date, population, total_cases, (total_cases/population)*100 as CovidPercentage
FROM portfolio.dbo.CovidDeaths
ORDER BY 1, 2


/* Countries with Highest Infection Rate compared to Population 
	Using MAX */
-- Tableau Visualization 1
SELECT location, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 as CovidPercentage
FROM portfolio.dbo.CovidDeaths
GROUP BY location, population
ORDER BY CovidPercentage desc


/* Countries with Highest Infection Rate compared to Population by Date */
-- Tableau Visualization 2
Select location, population, date, MAX(total_cases) as HighestInfectionCount,  MAX((total_cases/population))*100 as CovidPercentage
FROM portfolio..CovidDeaths
GROUP BY location, population, date
ORDER BY CovidPercentage DESC


/* Countries with Highest Death Count per Population */
SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM portfolio.dbo.CovidDeaths
GROUP BY location
ORDER BY TotalDeathCount desc
-- Results include incorrect locations like continents/class instead of countries 
/* Rerun SELECT * for the Deaths file to search for errors. 
	I notice some rows were showing continent is null, with the continent name in the location column instead.
	Add WHERE is not null clause and rerun to fix this issue. */
SELECT *
FROM portfolio.dbo.CovidDeaths
WHERE continent is not null
ORDER BY location, date
/* Countries with Highest Death Count per Population (CORRECTED)
	Rerun query with WHERE is not null clause */
SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM portfolio.dbo.CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY TotalDeathCount desc


/* Highest Death Count by Continent */
-- Tableau Visualization 3
/*	I noticed results were calculating incorrect numbers. EX. North America was not adding Canada numbers. 
	I noticed results were displaying misc categories instead of continent. Ex : European Union is part of Europe and incomes are not locations. 
	This is fixed by adding WHERE continent is NULL, WHERE locations are not, and grouping by location instead of continent. 
	CORRECTED query is below. */
SELECT location, SUM(cast(new_deaths as int)) as TotalDeathCount
FROM portfolio..CovidDeaths
WHERE continent is null 
and location not like '%income%'
and location not in ('World', 'European Union', 'International')
GROUP BY location
ORDER BY TotalDeathCount DESC


/* Global Numbers */
-- Tableau Visualization 4
SELECT SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(new_cases)*100 as DeathPercentage 
-- Cast new_deaths as int, because it's showing as nvarchar in old dataset. This was updated in the new dataset, but leaving it as an example.
FROM portfolio.dbo.CovidDeaths
WHERE continent is not null 
ORDER BY 1, 2


/* Let's look at Vaccinations file */
SELECT *
FROM portfolio.dbo.CovidVaccinations


/* JOIN Deaths and Vaccinations tables */
-- joining based on location and date
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccinations.new_vaccinations
FROM portfolio.dbo.CovidDeaths as deaths
JOIN portfolio.dbo.CovidVaccinations as vaccinations
  ON deaths.location = vaccinations.location
  AND deaths.date = vaccinations.date
WHERE deaths.continent is not null
ORDER BY 1, 2, 3


/* Total Population vs Vaccinations */
-- Must cast new_vaccinations as BIGINT because it exceeds max int.
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccinations.new_vaccinations, SUM(cast(vaccinations.new_vaccinations as bigint)) OVER (Partition by deaths.location ORDER BY deaths.location, deaths.date) as RollingPeopleVaccinated
-- , (RollingPeopleVaccinated/population)*100
/* You can't call a column you just made, so you'll need to make a CTE or temp table
	Partition by location : the aggregate count will stop and start over at each location so it doesn't total everything */
FROM portfolio.dbo.CovidDeaths as deaths
JOIN portfolio.dbo.CovidVaccinations as vaccinations
  ON deaths.location = vaccinations.location
  AND deaths.date = vaccinations.date
WHERE deaths.continent is not null
ORDER BY 2, 3


/* Total Population vs Vaccinations USING CTE */
With PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
-- You need the same number of columns called here as in the SELECT columns
as
(
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccinations.new_vaccinations
, SUM(cast(vaccinations.new_vaccinations as bigint)) OVER (Partition by deaths.location ORDER BY deaths.location, deaths.date) as RollingPeopleVaccinated
FROM portfolio.dbo.CovidDeaths as deaths
JOIN portfolio.dbo.CovidVaccinations as vaccinations
  ON deaths.location = vaccinations.location
  AND deaths.date = vaccinations.date
WHERE deaths.continent is not null
)
SELECT *, (RollingPeopleVaccinated/population)*100
FROM PopvsVac

/* Total Population vs Vaccinations USING Temp Table */
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
  continent nvarchar(255),
  location nvarchar(255),
  date datetime,
  population numeric, 
  new_vaccinations numeric,
  RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccinations.new_vaccinations
, SUM(cast(vaccinations.new_vaccinations as bigint)) OVER (Partition by deaths.location ORDER BY deaths.location, deaths.date) as RollingPeopleVaccinated
FROM portfolio.dbo.CovidDeaths as deaths
JOIN portfolio.dbo.CovidVaccinations as vaccinations
  ON deaths.location = vaccinations.location
  AND deaths.date = vaccinations.date

SELECT *, (RollingPeopleVaccinated/population)*100
FROM #PercentPopulationVaccinated


/* Creating View to store data for later visualizations */
CREATE VIEW PercentPopulationVaccinated as
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccinations.new_vaccinations
, SUM(cast(vaccinations.new_vaccinations as bigint)) OVER (Partition by deaths.location ORDER BY deaths.location, deaths.date) as RollingPeopleVaccinated
-- , (RollingPeopleVaccinated/population)*100
FROM portfolio.dbo.CovidDeaths as deaths
JOIN portfolio.dbo.CovidVaccinations as vaccinations
  ON deaths.location = vaccinations.location
  AND deaths.date = vaccinations.date
WHERE deaths.continent is not null


/* Let's see the saved VIEW. */
SELECT *
FROM PercentPopulationVaccinated