check_deps nodejs git

PADDLE_COMMIT=$(get_module_commit "paddle")
build_export PADDLE_COMMIT
