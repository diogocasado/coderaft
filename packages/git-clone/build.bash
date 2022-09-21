check_deps git 

GIT_CLONE_DUMMY_COMMIT=$(get_module_commit "dummy")
build_export GIT_CLONE_DUMMY_COMMIT
