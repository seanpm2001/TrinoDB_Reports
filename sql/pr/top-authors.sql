-- Top 10 authors per year
WITH
members AS (
    SELECT
        login
      , joined_at
      , removed_at
      , org AS team
    FROM all_members
    WHERE team_slug = '' AND org != 'trinodb'
    UNION ALL
    SELECT
        login
      , joined_at
      , removed_at
      , team_slug AS team
    FROM all_members
    WHERE team_slug NOT IN ('', 'infrastructure', 'contributors') AND org = 'trinodb'
)
, commits AS (
    SELECT
        c.commit_time AT TIME ZONE 'UTC' AS commit_time
      , ai.name AS author_name
      --, array_agg(DISTINCT coalesce(m.team, 'external') ORDER BY coalesce(m.team, 'external')) AS teams
      , count(*) AS commits_count
    FROM git.default.commits c
    JOIN memory.default.gh_idents ai ON ai.email = c.author_email OR CONTAINS(ai.extra_emails, c.author_email)
    --LEFT JOIN members m ON CONTAINS(ai.logins, m.login) AND c.commit_time AT TIME ZONE 'UTC' BETWEEN m.joined_at AND m.removed_at
    GROUP BY 1, 2
)
, mergers_per_year AS (
    SELECT
        year(commit_time) AS year,
        author_name,
        --teams,
        sum(commits_count) AS commits_count
    FROM commits
    GROUP BY 1, 2
)
, ranked_per_year AS (
    SELECT
        year,
        author_name,
        --teams,
        commits_count,
        row_number() OVER (PARTITION BY year ORDER BY commits_count DESC) AS in_year_rank
    FROM mergers_per_year
)
SELECT
    year,
    author_name,
    --teams,
    commits_count
FROM ranked_per_year
WHERE in_year_rank < 11
ORDER BY year DESC, commits_count DESC, author_name
;
