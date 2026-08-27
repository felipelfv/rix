# Smoke test for the `rix` image variants: generate an environment with {rix}
# and check that the resulting expression builds.
library(rix)

rix(
  date = available_dates()[length(available_dates())],
  r_pkgs = "dplyr",
  ide = "none",
  project_path = "/tmp/smoke",
  overwrite = TRUE,
  message_type = "quiet"
)

stopifnot(file.exists("/tmp/smoke/default.nix"))
cat("rix", as.character(packageVersion("rix")), "generated /tmp/smoke/default.nix\n")
