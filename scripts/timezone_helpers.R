#--------------------------------------------------------------------------------------------
# File name: 		      timezone_helpers.R
# Purpose:
# 	- Helpers for deadline times: read a deadline time entered in any time zone and show it
#     converted to one or more display time zones (e.g. Eastern and Central).
#   - Sourced by 2_create_send_reminders.R. Uses lubridate (>= 1.9.0 for roll_dst).
#--------------------------------------------------------------------------------------------
library(lubridate)
if (packageVersion("lubridate") < "1.9.0") stop("timezone_helpers.R needs lubridate >= 1.9.0")

# (1): Common time zone abbreviations -> IANA zone names. #
# Abbreviations are ambiguous (CST = US Central, China, Cuba), so no package resolves them;
# this table picks the usual academic meaning. They map to the *region*, so "EST" entered for
# a July deadline is read as Eastern time (EDT). Use an offset ("UTC-5") for a fixed offset.
tz_aliases <- c(
  "AOE"  = "Etc/GMT+12",            # Anywhere on Earth (UTC-12). Etc/ signs are inverted.
  "UTC"  = "UTC", "GMT" = "UTC", "Z" = "UTC",
  "ET"   = "America/New_York",    "EST"  = "America/New_York",    "EDT"  = "America/New_York",
  "CT"   = "America/Chicago",     "CST"  = "America/Chicago",     "CDT"  = "America/Chicago",
  "MT"   = "America/Denver",      "MST"  = "America/Denver",      "MDT"  = "America/Denver",
  "PT"   = "America/Los_Angeles", "PST"  = "America/Los_Angeles", "PDT"  = "America/Los_Angeles",
  "AKST" = "America/Anchorage",   "AKDT" = "America/Anchorage",
  "HST"  = "Pacific/Honolulu",
  "BST"  = "Europe/London",       "WET"  = "Europe/Lisbon",       "WEST" = "Europe/Lisbon",
  "CET"  = "Europe/Paris",        "CEST" = "Europe/Paris",
  "EET"  = "Europe/Athens",       "EEST" = "Europe/Athens",
  "IST"  = "Asia/Kolkata",        "JST"  = "Asia/Tokyo",          "KST"  = "Asia/Seoul",
  "HKT"  = "Asia/Hong_Kong",      "SGT"  = "Asia/Singapore",
  "AEST" = "Australia/Sydney",    "AEDT" = "Australia/Sydney",
  "NZST" = "Pacific/Auckland",    "NZDT" = "Pacific/Auckland",
  "BRT"  = "America/Sao_Paulo"
)

is_blank <- function(x) is.null(x) || length(x) != 1 || is.na(x) || trimws(as.character(x)) %in% c("", "NA")

# (2): Resolve a user-entered time zone. #
# Accepts an abbreviation above, an offset ("UTC+2", "GMT-05:00", "+05:30") or any IANA name
# ("Europe/Berlin", case-insensitive). Returns list(zone, offset_min, label), or NULL.
resolve_timezone <- function(tz_string) {
  if (is_blank(tz_string)) return(NULL)
  key <- toupper(trimws(as.character(tz_string)))

  off <- regmatches(key, regexec("^(?:UTC|GMT)?\\s*([+-])\\s*(\\d{1,2})(?::?(\\d{2}))?$", key, perl = TRUE))[[1]]
  if (length(off) > 0) {
    mins <- as.integer(off[3]) * 60L + ifelse(off[4] == "", 0L, as.integer(off[4]))
    if (mins > 14 * 60) return(NULL)
    mins <- ifelse(off[2] == "-", -mins, mins)
    label <- if (mins == 0) "UTC" else sprintf("UTC%s%02d%s", off[2], abs(mins) %/% 60,
                                               ifelse(mins %% 60 == 0, "", sprintf(":%02d", abs(mins) %% 60)))
    return(list(zone = NA_character_, offset_min = mins, label = label))
  }
  if (key %in% names(tz_aliases)) {
    return(list(zone = unname(tz_aliases[key]), offset_min = NA_integer_,
                label = if (key == "AOE") "AoE (UTC-12)" else NA_character_))
  }
  hit <- OlsonNames()[toupper(OlsonNames()) == key]
  if (length(hit) > 0) return(list(zone = hit[1], offset_min = NA_integer_, label = NA_character_))
  NULL
}

# (3): Parse a time of day into minutes after midnight (0-1440), or NA. #
# Text ("23:59", "11:59 PM", "5 p.m.", "17h00", "17:00:00", "24:00") is parsed by lubridate.
# Also accepts Excel time cells (readxl reads them as 1899-12-31 date-times) and day fractions.
parse_time_of_day <- function(x) {
  if (is.null(x) || length(x) != 1 || is.na(x)) return(NA_integer_)
  if (inherits(x, "POSIXt")) return(hour(with_tz(x, "UTC")) * 60L + minute(with_tz(x, "UTC")))
  if (is.numeric(x)) return(if (x >= 0 && x < 1) as.integer(round(x * 1440)) else NA_integer_)
  s <- tolower(trimws(as.character(x)))
  if (s %in% c("", "na")) return(NA_integer_)
  if (grepl("^0?\\.\\d+$", s)) return(parse_time_of_day(as.numeric(s)))   # day fraction as text
  if (s == "noon") return(720L)
  if (grepl("^24[:.h]00$", s)) return(1440L)                              # end of day
  s <- sub("([ap])\\.?\\s*m\\.?$", "\\1m", s)                              # "p.m." -> "pm"
  t <- suppressWarnings(parse_date_time(s, orders = c("HM", "HMS", "IMp", "Ip"), exact = FALSE, quiet = TRUE))
  # Require two-digit minutes or am/pm, so "17" or a typo like "7:5" isn't read as a time.
  if (is.na(t) || !grepl("[:.h]\\d{2}|^\\d{1,2}\\s*[ap]m$", s)) return(NA_integer_)
  hour(t) * 60L + minute(t)
}

# Normalize the deadline_time column to "HH:MM" text so it is written back to Excel cleanly.
# Text that can't be parsed is kept as typed (and produces a warning when the email is built).
normalize_time_column <- function(col) {
  vapply(seq_along(col), function(i) {
    mins <- parse_time_of_day(col[i])
    if (!is.na(mins)) return(sprintf("%02d:%02d", mins %/% 60, mins %% 60))
    if (inherits(col, "POSIXt") || is_blank(col[i])) NA_character_ else as.character(col[i])
  }, character(1))
}

# (4): The deadline as an exact instant (POSIXct, UTC). #
# deadline_date is the deadline's date in its own time zone. If the zone is blank, the
# computer's zone is used. Returns NA for missing/invalid input, including clock times that
# don't exist (skipped by a spring-forward change). A time that happens twice (fall-back)
# resolves to the EARLIER occurrence, so a reminder never shows more time than there is.
deadline_instant <- function(deadline_date, time_string, tz_string, default_tz = Sys.timezone()) {
  mins <- parse_time_of_day(time_string)
  tz <- resolve_timezone(tz_string)
  if (is.null(tz)) tz <- resolve_timezone(default_tz)
  if (is.na(mins) || is.na(deadline_date) || is.null(tz)) return(as.POSIXct(NA))
  wall <- as_datetime(as.Date(deadline_date)) + mins * 60   # wall-clock time, labelled UTC
  if (!is.na(tz$offset_min)) return(wall - tz$offset_min * 60)
  with_tz(force_tz(wall, tz$zone, roll_dst = c("NA", "pre")), "UTC")
}

# (5): An instant as seen in a zone: list(t = clock time, label = "EST"/"AoE (UTC-12)"/...). #
# For fixed offsets, t is the shifted clock time labelled UTC, so date()/hour() read correctly.
view_in_zone <- function(instant, tz) {
  if (!is.na(tz$offset_min)) return(list(t = with_tz(instant, "UTC") + tz$offset_min * 60, label = tz$label))
  t <- with_tz(instant, tz$zone)
  label <- if (is.na(tz$label)) format(t, "%Z") else tz$label    # EST/EDT, CST/CDT, ...
  if (grepl("^[+-]", label)) label <- paste0("UTC", label)       # zones with no abbreviation
  list(t = t, label = label)
}

# "9:00 AM EST"
format_clock <- function(v) paste(sub("^0", "", format(v$t, "%I:%M %p")), v$label)

# Format an instant in a zone, e.g. "Tuesday, December 1, 2026 at 11:59 PM EST".
format_in_zone <- function(instant, tz) {
  v <- view_in_zone(instant, tz)
  paste0(format(v$t, "%A, %B "), mday(v$t), format(v$t, ", %Y"), " at ", format_clock(v))
}

# (5b): When to send reminders for a deadline with a time. #
# The due time is viewed in cutoff_tz. If it is before cutoff_time there, reminders are
# scheduled one day earlier (so the "final" reminder isn't sent the morning of an early deadline).
# Returns list(reminder_date, due_date, due_label). Without a usable time, both dates are the
# deadline date and due_label is NA, i.e. scheduling works as it always has.
reminder_schedule <- function(deadline_date, time_string, tz_string,
                              cutoff_time = "17:00", cutoff_tz = "America/New_York") {
  deadline_date <- as.Date(deadline_date)
  unchanged <- list(reminder_date = deadline_date, due_date = deadline_date, due_label = NA_character_)
  instant <- deadline_instant(deadline_date, time_string, tz_string)
  cutoff_mins <- parse_time_of_day(cutoff_time)
  ctz <- resolve_timezone(cutoff_tz)
  if (is.na(cutoff_mins) || is.null(ctz)) {
    warning("Invalid reminder cutoff '", cutoff_time, "' / '", cutoff_tz, "'; using 17:00 America/New_York.", call. = FALSE)
    cutoff_mins <- 17L * 60L
    ctz <- resolve_timezone("America/New_York")
  }
  if (is.na(instant)) return(unchanged)
  v <- view_in_zone(instant, ctz)
  due_date <- as.Date(format(v$t, "%Y-%m-%d"))   # the date on the clock in cutoff_tz
  before_cutoff <- hour(v$t) * 60L + minute(v$t) < cutoff_mins
  list(reminder_date = due_date - ifelse(before_cutoff, 1, 0), due_date = due_date, due_label = format_clock(v))
}

# (6): Parse the comma separated display_timezones parameter. #
# Unknown entries are dropped with a warning. Falls back to the computer's time zone.
parse_display_timezones <- function(display_string) {
  entries <- if (is_blank(display_string)) character(0) else trimws(strsplit(as.character(display_string), ",")[[1]])
  zones <- list()
  for (e in entries[entries != ""]) {
    tz <- resolve_timezone(e)
    if (is.null(tz)) warning("Unknown display time zone '", e, "' ignored.", call. = FALSE)
    else zones[[length(zones) + 1]] <- tz
  }
  if (length(zones) == 0) zones <- list(resolve_timezone(Sys.timezone()))
  zones
}

# (7): HTML snippet for the reminder email. Returns "" when no (valid) time was given. #
deadline_time_html <- function(deadline_date, time_string, tz_string, display_zones) {
  instant <- deadline_instant(deadline_date, time_string, tz_string)
  if (is.na(instant)) {
    if (!is_blank(time_string)) {
      warning("Could not use deadline time '", time_string, "' / time zone '", tz_string,
              "'; sending reminder without it.", call. = FALSE)
    }
    return("")
  }
  src_tz <- resolve_timezone(tz_string)
  if (!is_blank(tz_string) && is.null(src_tz)) {
    warning("Unknown time zone '", tz_string, "'; assuming local time.", call. = FALSE)
  }
  src_missing <- is.null(src_tz)
  if (src_missing) src_tz <- resolve_timezone(Sys.timezone())
  src_text <- format_in_zone(instant, src_tz)

  conv <- vapply(display_zones, function(z) format_in_zone(instant, z), character(1))
  conv <- unique(conv[conv != src_text])   # skip zones that read the same as the original

  out <- paste0("The submission is due <b>", src_text, "</b>",
                if (src_missing) " (no valid time zone given; assumed local time)" else "", ".")
  if (length(conv) == 0) return(paste0(out, "<br><br>"))
  paste0(out, " That is:<ul>", paste0("<li>", conv, "</li>", collapse = ""), "</ul>")
}
