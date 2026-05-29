DO $$
DECLARE
    duplicate_country_count INT;
    missing_demographic_count INT;
    missing_health_count INT;
    missing_education_count INT;
    missing_infrastructure_count INT;
    coverage_gap_count INT;
BEGIN
    SELECT COUNT(*) INTO duplicate_country_count
    FROM (
        SELECT country_key
        FROM mart.mart_country_development_profile_latest
        GROUP BY country_key
        HAVING COUNT(*) <> 1
    ) dup;

    IF duplicate_country_count <> 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: development profile latest has duplicate country rows';
    END IF;

    SELECT COUNT(*) INTO missing_demographic_count
    FROM (
        SELECT DISTINCT indicator_code
        FROM mart.mart_country_demographics_series_annual
        WHERE indicator_code IN ('POP_TOTAL', 'FERTILITY_RATE_BIRTHS_PER_WOMAN')
    ) got
    RIGHT JOIN (VALUES ('POP_TOTAL'), ('FERTILITY_RATE_BIRTHS_PER_WOMAN')) expected(indicator_code)
      ON expected.indicator_code = got.indicator_code
    WHERE got.indicator_code IS NULL;

    IF missing_demographic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: demographic mart is missing expected indicators';
    END IF;

    SELECT COUNT(*) INTO missing_health_count
    FROM mart.mart_country_health_series_annual
    WHERE indicator_code = 'LIFE_EXPECTANCY_YEARS';

    IF missing_health_count = 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: health mart has no life expectancy rows';
    END IF;

    SELECT COUNT(*) INTO missing_education_count
    FROM mart.mart_country_education_series_annual
    WHERE indicator_code = 'SCHOOL_ENROLLMENT_PRIMARY_PCT';

    IF missing_education_count = 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: education mart has no school enrollment rows';
    END IF;

    SELECT COUNT(*) INTO missing_infrastructure_count
    FROM mart.mart_country_infrastructure_latest
    WHERE access_to_electricity_pct IS NOT NULL;

    IF missing_infrastructure_count = 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: infrastructure latest mart has no electricity-access rows';
    END IF;

    SELECT COUNT(*) INTO coverage_gap_count
    FROM mart.vw_social_infrastructure_coverage_gaps;

    IF coverage_gap_count <> 0 THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: social/infrastructure coverage gaps remain for countries already present in the development profile';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM mart.mart_country_development_profile_latest
        WHERE iso_alpha_3 = 'USA'
          AND fertility_rate_births_per_woman_year = 2022
          AND fertility_rate_births_per_woman = 1.66
          AND life_expectancy_years_year = 2022
          AND life_expectancy_years = 77.28
          AND school_enrollment_primary_pct_year = 2022
          AND school_enrollment_primary_pct = 93.1
          AND access_to_electricity_pct_year = 2022
          AND access_to_electricity_pct = 100.0
          AND phase3_indicator_coverage_count = 4
    ) THEN
        RAISE EXCEPTION 'Phase 3 starter mart test failed: USA development profile row does not expose the expected first-slice values';
    END IF;
END;
$$;

SELECT
    iso_alpha_3,
    country_name,
    fertility_rate_births_per_woman_year,
    fertility_rate_births_per_woman,
    life_expectancy_years_year,
    life_expectancy_years,
    school_enrollment_primary_pct_year,
    school_enrollment_primary_pct,
    access_to_electricity_pct_year,
    access_to_electricity_pct,
    phase3_indicator_coverage_count,
    latest_phase3_observation_year
FROM mart.mart_country_development_profile_latest
ORDER BY country_name;

SELECT
    COUNT(*) AS coverage_gap_count
FROM mart.vw_social_infrastructure_coverage_gaps;
