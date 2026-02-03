#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/dro/.lmstudio/bin"
# End of LM Studio CLI section

export HSA_OVERRIDE_GFX_VERSION=11.0.0
export ROCM_PATH=/opt/rocm
export PYTORCH_ROCM_ARCH=gfx1103
