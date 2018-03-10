# if the shell is interactive but different than bash (i.e. dash) and the
# current shell is not already bash, then replace current shell with a login
# bash shell.
case "$-" in
  *i*)
    [ "x$SSH_CONNECTION" != "x" ] && [ "x$BASH_VERSION" = "x" ] && exec bash -l
    ;;
esac
