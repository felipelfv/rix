# Smoke test for the `rix` image variants: generate an environment with {rix},
# then check that the resulting expression builds (run from the workflow via
# `rix-shell --run "Rscript /test/smoke.R && nix-build /tmp/smoke"`).
library(rix)

rix(
  date = tail(available_dates(), 1),
  r_pkgs = "dplyr",
  ide = "none",
  project_path = "/tmp/smoke",
  overwrite = TRUE,
  message_type = "quiet"
)

stopifnot(file.exists("/tmp/smoke/default.nix"))
cat("rix", as.character(packageVersion("rix")), "generated /tmp/smoke/default.nix\n")
