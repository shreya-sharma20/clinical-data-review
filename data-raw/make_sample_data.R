# Generate the synthetic sample datasets shipped in inst/extdata/sample-data/.
#
# Everything here is fictional: no real subjects, sites or studies. The random
# seed is fixed, so re-running the script reproduces the same data.
#
# Run from the package root:
#   Rscript data-raw/make_sample_data.R
#
# Each dataset is written twice: as CSV (no variable labels, missing values
# are empty) and as SAS transport v5 XPT (with variable labels and SAS date
# formats). Needs the 'haven' package.

set.seed(20240229)

out_dir <- file.path("inst", "extdata", "sample-data")
if (!dir.exists(dirname(out_dir))) {
  stop("Run this script from the package root (the folder with DESCRIPTION).",
       call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Helpers ----------------------------------------------------------------------

# Write `data` as CSV and XPT. `labels` is a named character vector of
# variable labels (XPT v5 allows at most 40 characters); `xpt_name` is the
# dataset name stored in the XPT (at most 8 characters).
write_sample <- function(data, file_stem, xpt_name, labels) {
  utils::write.csv(
    data, file.path(out_dir, paste0(file_stem, ".csv")),
    row.names = FALSE, na = ""
  )

  stopifnot(setequal(names(labels), names(data)), nchar(labels) <= 40L,
            nchar(xpt_name) <= 8L)
  for (variable in names(data)) {
    attr(data[[variable]], "label") <- labels[[variable]]
    if (inherits(data[[variable]], "Date")) {
      attr(data[[variable]], "format.sas") <- "DATE9"
    }
  }
  haven::write_xpt(
    data, file.path(out_dir, paste0(file_stem, ".xpt")),
    version = 5, name = xpt_name
  )
  invisible(data)
}

# ADSL: one row per subject -----------------------------------------------------

n_subjects <- 60L
arms <- c("Placebo", "Low Dose", "High Dose")

adsl <- data.frame(
  STUDYID = "ADAMDEMO01",
  SITEID = sort(sample(c("101", "102", "103", "104", "105"), n_subjects, replace = TRUE)),
  stringsAsFactors = FALSE
)
adsl$USUBJID <- sprintf("%s-%s-%03d", adsl$STUDYID, adsl$SITEID, seq_len(n_subjects))
adsl$ARM <- sample(rep(arms, length.out = n_subjects))
adsl$SEX <- sample(c("F", "M"), n_subjects, replace = TRUE, prob = c(0.55, 0.45))
adsl$RACE <- sample(
  c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN", "OTHER"),
  n_subjects, replace = TRUE, prob = c(0.6, 0.2, 0.15, 0.05)
)
adsl$AGE <- round(pmin(pmax(rnorm(n_subjects, 56, 12), 18), 85))
adsl$AGEGR1 <- ifelse(adsl$AGE < 45, "<45", ifelse(adsl$AGE < 65, "45-64", ">=65"))

female <- adsl$SEX == "F"
adsl$WEIGHTBL <- round(rnorm(n_subjects, ifelse(female, 68, 82), 11), 1)
adsl$HEIGHTBL <- round(rnorm(n_subjects, ifelse(female, 162, 176), 7), 1)
adsl$WEIGHTBL[sample(n_subjects, 3)] <- NA # weight not recorded
adsl$BMIBL <- round(adsl$WEIGHTBL / (adsl$HEIGHTBL / 100)^2, 1)

adsl$TRTSDT <- as.Date("2023-01-09") + sample(0:120, n_subjects, replace = TRUE)
adsl$TRTEDT <- adsl$TRTSDT + 83L # planned 12 weeks of treatment
early <- sample(n_subjects, 8)
adsl$TRTEDT[early] <- adsl$TRTSDT[early] + sample(14:70, 8) # discontinued early
adsl$TRTEDT[sample(setdiff(seq_len(n_subjects), early), 4)] <- NA # still on treatment

adsl$SAFFL <- ifelse(seq_len(n_subjects) %in% sample(n_subjects, 2), "N", "Y")
adsl$DTHFL <- ifelse(seq_len(n_subjects) %in% sample(n_subjects, 3), "Y", "") # blank = alive

adsl <- adsl[c(
  "STUDYID", "USUBJID", "SITEID", "ARM", "SEX", "RACE", "AGE", "AGEGR1",
  "WEIGHTBL", "HEIGHTBL", "BMIBL", "TRTSDT", "TRTEDT", "SAFFL", "DTHFL"
)]

adsl_labels <- c(
  STUDYID = "Study Identifier",
  USUBJID = "Unique Subject Identifier",
  SITEID = "Study Site Identifier",
  ARM = "Description of Planned Arm",
  SEX = "Sex",
  RACE = "Race",
  AGE = "Age",
  AGEGR1 = "Pooled Age Group 1",
  WEIGHTBL = "Baseline Weight (kg)",
  HEIGHTBL = "Baseline Height (cm)",
  BMIBL = "Baseline BMI (kg/m^2)",
  TRTSDT = "Date of First Exposure to Treatment",
  TRTEDT = "Date of Last Exposure to Treatment",
  SAFFL = "Safety Population Flag",
  DTHFL = "Subject Died Flag"
)
write_sample(adsl, "adsl_sample", "ADSL", adsl_labels)

# ADAE: one row per adverse event, linked to ADSL by USUBJID -------------------

ae_terms <- data.frame(
  AETERM = c("Headache", "Nausea", "Loose stools", "Tiredness", "Dizzy spells",
             "Skin rash", "Cough", "Common cold", "Lower back pain",
             "Trouble sleeping", "High blood pressure"),
  AEDECOD = c("Headache", "Nausea", "Diarrhoea", "Fatigue", "Dizziness",
              "Rash", "Cough", "Nasopharyngitis", "Back pain", "Insomnia",
              "Hypertension"),
  AEBODSYS = c("NERVOUS SYSTEM DISORDERS", "GASTROINTESTINAL DISORDERS",
               "GASTROINTESTINAL DISORDERS",
               "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
               "NERVOUS SYSTEM DISORDERS",
               "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
               "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS",
               "INFECTIONS AND INFESTATIONS",
               "MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS",
               "PSYCHIATRIC DISORDERS", "VASCULAR DISORDERS"),
  stringsAsFactors = FALSE
)
term_weights <- c(6, 5, 3, 4, 3, 2, 3, 4, 2, 2, 1)

# Higher doses have more adverse events.
ae_rate <- c(Placebo = 1.6, `Low Dose` = 2.4, `High Dose` = 3.2)
events_per_subject <- rpois(n_subjects, ae_rate[adsl$ARM])
subject_row <- rep(seq_len(n_subjects), events_per_subject)
n_events <- length(subject_row)

term_row <- sample(nrow(ae_terms), n_events, replace = TRUE, prob = term_weights)
adae <- data.frame(
  STUDYID = adsl$STUDYID[subject_row],
  USUBJID = adsl$USUBJID[subject_row],
  ae_terms[term_row, ],
  stringsAsFactors = FALSE
)
adae$AESEV <- sample(c("MILD", "MODERATE", "SEVERE"), n_events, replace = TRUE,
                     prob = c(0.6, 0.3, 0.1))
adae$AESER <- ifelse(adae$AESEV == "SEVERE" & runif(n_events) < 0.4, "Y", "N")
adae$AEREL <- sample(c("NOT RELATED", "POSSIBLY RELATED", "RELATED"), n_events,
                     replace = TRUE, prob = c(0.5, 0.3, 0.2))
adae$ASTDT <- adsl$TRTSDT[subject_row] + sample(0:70, n_events, replace = TRUE)
adae$AENDT <- adae$ASTDT + rpois(n_events, 4)
adae$AENDT[runif(n_events) < 0.12] <- NA # ongoing
adae$AEDUR <- as.numeric(adae$AENDT - adae$ASTDT) + 1

adae <- adae[order(adae$USUBJID, adae$ASTDT), ]
rownames(adae) <- NULL

adae_labels <- c(
  STUDYID = "Study Identifier",
  USUBJID = "Unique Subject Identifier",
  AETERM = "Reported Term for the Adverse Event",
  AEDECOD = "Dictionary-Derived Term",
  AEBODSYS = "Body System or Organ Class",
  AESEV = "Severity/Intensity",
  AESER = "Serious Event",
  AEREL = "Causality",
  ASTDT = "Analysis Start Date",
  AENDT = "Analysis End Date",
  AEDUR = "Adverse Event Duration (days)"
)
write_sample(adae, "adae_sample", "ADAE", adae_labels)

# ADSL v2: a deliberately modified copy, for trying out Compare ----------------
# Differences from adsl_sample (each one should show up in the comparison):
#   * changed values: AGE (+1) for 5 subjects, ARM for 2, RACE for 1;
#   * dropped column: HEIGHTBL;
#   * added column: RANDFL;
#   * removed rows: the last 3 subjects (rows are matched by position, so
#     removing rows from the end keeps the other differences readable);
#   * changed type: WEIGHTBL becomes text, with "UNK" where it was blank, and
#     3 weights are changed.

adsl_v2 <- adsl
adsl_v2$AGE[c(4, 17, 31, 44, 52)] <- adsl_v2$AGE[c(4, 17, 31, 44, 52)] + 1
swap_arm <- c(9, 26)
adsl_v2$ARM[swap_arm] <- ifelse(adsl_v2$ARM[swap_arm] == "High Dose", "Low Dose", "High Dose")
adsl_v2$RACE[13] <- ifelse(adsl_v2$RACE[13] == "OTHER", "ASIAN", "OTHER")

changed_weight <- c(6, 22, 38)
adsl_v2$WEIGHTBL[changed_weight] <- adsl_v2$WEIGHTBL[changed_weight] + 0.5
adsl_v2$WEIGHTBL <- ifelse(is.na(adsl_v2$WEIGHTBL), "UNK", as.character(adsl_v2$WEIGHTBL))

adsl_v2$HEIGHTBL <- NULL
adsl_v2$RANDFL <- "Y"
adsl_v2 <- adsl_v2[seq_len(n_subjects - 3L), ]
rownames(adsl_v2) <- NULL

adsl_v2_labels <- c(adsl_labels[names(adsl_v2)[names(adsl_v2) != "RANDFL"]],
                    RANDFL = "Randomized Population Flag")
write_sample(adsl_v2, "adsl_sample_v2", "ADSLV2", adsl_v2_labels)

# Edge cases: awkward data for the Explorer ------------------------------------

n_edge <- 40L
words <- c("subject", "reported", "mild", "transient", "symptoms", "after",
           "the", "second", "dose", "resolved", "without", "treatment",
           "investigator", "considered", "unlikely", "related", "to", "study")
long_text <- vapply(seq_len(n_edge), function(i) {
  if (i %% 4 == 0) {
    # Long text: cut at 190 characters, inside the 200-byte XPT v5 limit
    substr(paste(sample(words, 40, replace = TRUE), collapse = " "), 1, 190)
  } else {
    paste(sample(words, 4, replace = TRUE), collapse = " ")
  }
}, character(1))

edge_cases <- data.frame(
  ID = sprintf("ROW-%04d", seq_len(n_edge)), # high cardinality: every value differs
  ALLMISS = NA_real_, # entirely missing
  EMPTYSTR = sample(c("A", "B", ""), n_edge, replace = TRUE, prob = c(0.3, 0.2, 0.5)),
  CONSTANT = "X", # a single value
  NEGVAL = round(rnorm(n_edge, -5, 20), 1), # negatives
  LONGTXT = long_text, # very long text
  EVENTDT = as.Date("2022-06-01") + sample(0:400, n_edge, replace = TRUE),
  stringsAsFactors = FALSE
)
edge_cases$EVENTDT[sample(n_edge, 5)] <- NA

edge_labels <- c(
  ID = "Row identifier (all values distinct)",
  ALLMISS = "Numeric column that is entirely missing",
  EMPTYSTR = "Text column with many empty strings",
  CONSTANT = "Column with a single value",
  NEGVAL = "Numeric column with negative values",
  LONGTXT = "Free text, some of it very long",
  EVENTDT = "Event date (some missing)"
)
write_sample(edge_cases, "edge_cases", "EDGECASE", edge_labels)

# More Compare pairs ------------------------------------------------------------
# Appended after everything above (none of it draws random numbers) so the
# datasets generated earlier stay byte-identical. Each file below is meant to be
# uploaded against its base dataset in the Compare tab.

# adsl_sample_copy: an unchanged copy of adsl_sample. Expect "No differences".
write_sample(adsl, "adsl_sample_copy", "ADSLCOPY", adsl_labels)

# adae_sample_v2: a modified copy of adae_sample. Expect, against adae_sample:
#   * changed values: AESEV on every 23rd event, AEDUR (+1 day) on every 31st,
#     AETERM text on 2 events;
#   * a renamed column: AEREL becomes AERELAT (one column in each dataset only);
#   * 4 extra events at the end (rows only in the compare dataset).
adae_v2 <- adae
n_ae <- nrow(adae_v2)
sev_rows <- seq(5L, n_ae, by = 23L)
adae_v2$AESEV[sev_rows] <- ifelse(adae_v2$AESEV[sev_rows] == "MILD", "MODERATE", "MILD")
dur_rows <- seq(8L, n_ae, by = 31L)
adae_v2$AEDUR[dur_rows] <- adae_v2$AEDUR[dur_rows] + 1
adae_v2$AETERM[c(2L, 9L)] <- paste(adae_v2$AETERM[c(2L, 9L)], "- coded")
names(adae_v2)[names(adae_v2) == "AEREL"] <- "AERELAT"
adae_v2 <- rbind(adae_v2, adae_v2[seq_len(4L), ])
rownames(adae_v2) <- NULL

adae_v2_labels <- adae_labels
names(adae_v2_labels)[names(adae_v2_labels) == "AEREL"] <- "AERELAT"
write_sample(adae_v2, "adae_sample_v2", "ADAEV2", adae_v2_labels)

# adsl_sample_rounded: numeric precision. Expect, against adsl_sample:
#   * WEIGHTBL and BMIBL rounded to the nearest 0.5: reported as value
#     differences (rounded to whole numbers, a CSV would read the column back as
#     integer and Compare would report a type change instead);
#   * HEIGHTBL nudged by 1e-10: NOT reported, it is below diffdf's tolerance.
adsl_rounded <- adsl
adsl_rounded$WEIGHTBL <- round(adsl_rounded$WEIGHTBL * 2) / 2
adsl_rounded$BMIBL <- round(adsl_rounded$BMIBL * 2) / 2
adsl_rounded$HEIGHTBL <- adsl_rounded$HEIGHTBL + 1e-10
write_sample(adsl_rounded, "adsl_sample_rounded", "ADSLRND", adsl_labels)

# adsl_sample_sorted: the same 60 subjects with the columns reversed and the
# rows sorted by AGE. Rows are compared by position, so expect many value
# differences even though the content is equivalent: a reminder to sort both
# datasets the same way before comparing.
adsl_sorted <- adsl[order(adsl$AGE, adsl$USUBJID), rev(names(adsl))]
rownames(adsl_sorted) <- NULL
write_sample(adsl_sorted, "adsl_sample_sorted", "ADSLSORT", adsl_labels[names(adsl_sorted)])

message("Wrote sample data to ", out_dir, ":")
message(paste0("  ", list.files(out_dir), collapse = "\n"))
