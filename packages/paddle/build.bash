
PADDLE_COMMIT=$(git submodule status | awk '$2=="modules/paddle"{print $1}')

check_deps nodejs git
build_export PADDLE_COMMIT
