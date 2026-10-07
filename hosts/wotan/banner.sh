# shellcheck shell=bash
# Header for switch.sh and cleanup.sh: Yggdrasil, then what the script is about
# to do. Sourced, not executed.

banner() {
  # Canopy in green, trunk and roots in yellow.
  printf '\033[32m'
  cat <<'EOF'
          &&& &&  & &&
      && &\/&\|& ()|/ @, &&
      &\/(/&/&||/& /_/)_&/_&
   &() &\/&|()|/&\/ '%" & ()
  &_\_&&_\ |& |&&/&__%_/_& &&
&&   && & &| &| /& & % ()& /&&
 ()&_---()&\&\|&&-&&--%---()~
EOF
  printf '\033[33m'
  cat <<'EOF'
     &&     \|||
             |||
             |||
       , -=-~  .-^- _
EOF
  printf '\033[0m\n  \033[2m» %s\033[0m\n\n' "$1"
}
