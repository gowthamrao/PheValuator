/************************************************************************
@file getPopnPrev.sql
************************************************************************/

{DEFAULT @cdm_database_schema = 'CDM_SIM' }
{DEFAULT @cohort_database_schema = 'CDM_SIM' }
{DEFAULT @cohort_database_table = 'cohort' }
{DEFAULT @lowerAgeLimit = 20}
{DEFAULT @upperAgeLimit = 120}
{DEFAULT @gender = c(8507, 8532)}
{DEFAULT @startDate = '19000101' }
{DEFAULT @endDate = '21000101' }
{DEFAULT @mainPopnCohort = 0 }
{DEFAULT @prevCohort = 0 }
{DEFAULT @removeSubjectsWithFutureDates = TRUE }

with init_popn as (
select p.person_id, p.gender_concept_id, p.year_of_birth, min(year(o.observation_period_start_date)) startYear,
			{@removeSubjectsWithFutureDates == TRUE} ? {
			  case
			  when max(year(o.observation_period_end_date)) > YEAR(getdate()) then 1900 --year in future, person will not be used
			  else max(year(o.observation_period_end_date))
			  end as endYear}
			{@removeSubjectsWithFutureDates == FALSE} ? {
			  max(year(o.observation_period_end_date)) endYear}
        from @cdm_database_schema.person p
        join @cdm_database_schema.observation_period o
          on p.person_id = o.person_id
{@mainPopnCohort != 0} ? {join @cohort_database_schema.@cohort_database_table co
                  on p.person_id = co.subject_id
                    and cohort_definition_id = @mainPopnCohort}
        group by p.person_id, p.gender_concept_id, p.year_of_birth
),
popn as (
  select distinct person_id
  from init_popn
  where endYear = (
					select max(endYear)
					from init_popn)
	and startYear - year_of_birth >=  @lowerAgeLimit
		and startYear - year_of_birth <=  @upperAgeLimit
	and gender_concept_id in (@gender)
	and ((startYear >= year(CAST('@startDate' AS DATE))
			and startYear <= year(CAST('@endDate' AS DATE)))
		or (endYear >= year(CAST('@startDate' AS DATE))
				and endYear <= year(CAST('@endDate' AS DATE)))))
select cohCount*1.0/totCount popPrev
from (
      select  (select count(person_id)
                from popn) totCount,
              (select count(person_id)
                from popn p
                join @cohort_database_schema.@cohort_database_table co
                  on p.person_id = co.subject_id
                    and cohort_definition_id = @prevCohort) cohCount) a
;
