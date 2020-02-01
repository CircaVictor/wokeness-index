

-- Examine FEC filings only from the following committees
WITH target_fec_files AS (

  SELECT fec_file
    FROM fec_files
   WHERE amended = false
     AND invalid = false
     AND cycle_inference = 2020
     AND fec_id IN (
       ---- ENERGY ----
       -- GENERAL ELECTRIC COMPANY POLITICAL ACTION COMMITTEE (GEPAC)
       'C00024869', 
       -- GENERAL ELECTRIC COMPANY POLITICAL ACTION COMMITTEE-FEDERAL (GEPAC FEDERAL)
       'C00492223'
       -- EXXON MOBIL CORPORATION POLITICAL ACTION COMMITTEE (EXXONMOBIL PAC)
       'C00121368',

       ---- FINANCE ----
       -- BLACKROCK CAPITAL MANAGEMENT INC. POLITICAL ACTION COMMITTEE
       'C00479246',
       -- Visa
       'C00365122',
       -- BANK OF AMERICA CORPORATION STATE AND FEDERAL PAC
       'C00043489',
       -- BANK OF AMERICA CORPORATION FEDERAL PAC
       'C00364778',

       ---- CONSUMER ----
       -- MGM RESORTS INTERNATIONAL  PAC
       'C00299321',
       -- PEPSICO, INC. CONCERNED CITIZENS FUND
       'C00039321',
       -- MCDONALDS CORPORATION POLITICAL ACTION COMMITTEE
       'C00063164',
       -- DELTA AIR LINES POLITICAL ACTION COMMITTEE
       'C00104802',
       -- THE WENDYS COMPANY POLITICAL ACTION COMMITTEE
       'C00369090',

       ---- HEALTH ----
       -- CIGNA CORPORATION POLITICAL ACTION COMMITTEE
       'C00085316',
       -- PFIZER INC. PAC
       'C00016683',
       -- JOHNSON & JOHNSON POLITICAL ACTION COMMITTEE
       'C00010983',
       -- UNIVERSAL HEALTH SERVICES EMPLOYEES' GOOD GOVERNMENT FUND
       'C00185520',
       -- UNIVERSAL HEALTH CARE POLITICAL ACTION COMMITTEE
       'C00685925',

       ---- TECH ----
       -- HP INC. POLITICAL ACTION COMMITTEE
       'C00626648'
       -- GOOGLE LLC NETPAC
       'C00428623',
       -- FACEBOOK INC. PAC
       'C00502906',
       -- MICROSOFT CORPORATION POLITICAL ACTION COMMITTEE
       'C00227546',
       -- PAYPAL HOLDINGS, INC PAC (PAYPAL PAC)
       'C00581686',
       -- MOTOROLA SOLUTIONS, INC. POLITICAL ACTION COMMITTEE
       'C00075341'
     )

-- find prinpal committee fec ids
), principal_committee_fec_ids AS (

  SELECT fec_id
    FROM fec_committees_detailed
   WHERE csv_file = 2020
     AND designation in ('P', 'A')
     -- make sure we have a candidate and affiliation
     AND candidate_fec_id IS NOT NULL
     AND affiliation IS NOT NULL
  GROUP
      BY fec_id

-- find actors ids based off of the fec_id
), principal_committee_actors AS (

  SELECT id
    FROM actors a
   WHERE EXISTS (SELECT 1
                   FROM principal_committee_fec_ids p
                  WHERE p.fec_id = a.fec_id)

), woke_expenditures AS (

  SELECT actor_fec_id,
         actor_committee_id,
         purpose_id,
         memo_id,
         form_type_id,
         fec_file,
         transaction_id,
         amount,
         expended
    FROM expenditures_2020_cycle e
         -- search through target fec filings
   WHERE EXISTS (SELECT 1
                   FROM target_fec_files tff
                  WHERE tff.fec_file = e.fec_file)
         -- and limit our search to committees attached to a candidate
     AND EXISTS (SELECT 1
                   FROM principal_committee_actors p
                  WHERE p.id = e.actor_committee_id)

), woke_with_actors AS (

  SELECT c.fec_id AS recipient_fec_id,
         c.name AS recipeint_committee,
         amount,
         expended,
         aff.affiliation,
         a.fec_id AS giving_fec_id,
         a.name AS giving_committee,
         fec_file,
         transaction_id,
         ft.form_type,
         p.purpose,
         m.memo   
    FROM woke_expenditures w
         -- fetch the filing actor fec id and name
         LEFT JOIN LATERAL (SELECT fec_id,
                                   name
                              FROM find_fec_id_name_from_actor_id(w.actor_fec_id)) AS a
                                                                                   ON true
         -- find the committee actor fec id and name
         LEFT JOIN LATERAL (SELECT fec_id,
                                   name
                              FROM find_fec_id_name_from_actor_id(w.actor_committee_id)) AS c
                                                                                         ON true
         LEFT JOIN LATERAL (SELECT memo
                              FROM expenditure_memos m
                             WHERE m.id = w.memo_id) AS m
                                                     ON true
         LEFT JOIN LATERAL (SELECT purpose
                              FROM expenditure_purposes p
                             WHERE p.id = w.purpose_id) AS p
                                                        ON true
         LEFT JOIN LATERAL (SELECT form_type
                              FROM form_types ft
                             WHERE ft.id = w.form_type_id) AS ft
                                                           ON true
         LEFT JOIN LATERAL (SELECT affiliation
                              FROM fec_committees_detailed d
                             WHERE d.csv_file = 2020
                               AND d.designation in ('P', 'A')
                               AND d.candidate_fec_id IS NOT NULL
                               AND d.affiliation IS NOT NULL
                               AND d.fec_id = c.fec_id
                             LIMIT 1) AS aff
                                      ON true
  ORDER
      BY expended,
         amount DESC

), woke_grouped AS (
  
  SELECT giving_fec_id,
         giving_committee,
         count(*) AS transactions,
         sum(amount)::money AS total,
         affiliation
    FROM woke_with_actors
  GROUP
      BY giving_fec_id,
         giving_committee,
         affiliation
  ORDER
      BY giving_committee,
         affiliation

)
SELECT *
  FROM woke_with_actors;

  